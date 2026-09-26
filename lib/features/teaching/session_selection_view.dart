import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/performance_log.dart';
import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/teaching_overview.dart';
import '../../data/services/attendance_api_exception.dart';
import 'lesson_attendance_view.dart';
import 'session_provider.dart';
import 'weekly_schedule_grid.dart';

class SessionSelectionView extends StatefulWidget {
  const SessionSelectionView({super.key});
  @override
  State<SessionSelectionView> createState() => _SessionSelectionViewState();
}

class _SessionSelectionViewState extends State<SessionSelectionView> {
  DateTime _week = _monday(DateTime.now());
  Map<String, TeachingOverview> _data = {};
  CalendarLesson? _selected;
  final _calendarScroll = ScrollController();
  bool _loading = false;
  String? _error;
  DateTime? _lastUpdated;
  bool _loaded = false;
  bool _snapshotOnly = false;
  int _request = 0;
  static DateTime _monday(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - 1));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  @override
  void dispose() {
    _request++;
    _calendarScroll.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final provider = context.read<SessionProvider>();
    if (!_loaded) {
      final snapshot = await provider.readScheduleSnapshot();
      if (mounted && snapshot != null && !_loaded) {
        setState(() {
          _data = snapshot.data;
          _lastUpdated = snapshot.saved;
          _snapshotOnly = true;
        });
      }
    }
    if (mounted) await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final request = ++_request;
    final provider = context.read<SessionProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await provider.refreshTeachingWorkspace();
      if (mounted && request == _request) {
        setState(() {
          _data = data;
          if (_selected != null &&
              !data.containsKey(_selected!.classModel.id)) {
            _selected = null;
          }
          _loaded = true;
          _snapshotOnly = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is AttendanceApiException
              ? 'Không tải được lịch tuần: ${error.message} [${error.code}]'
              : 'Không tải được lịch tuần: lỗi kết nối hoặc dữ liệu. Hãy thử lại.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _open(CalendarLesson lesson) {
    if (_snapshotOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đây là lịch lưu tạm. Cần tải thành công dữ liệu máy chủ trước khi mở điểm danh.',
          ),
        ),
      );
      return;
    }
    context.read<SessionProvider>().selectLesson(
      lesson.classModel,
      lesson.slot,
    );
    setState(() => _selected = lesson);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    if (provider.workspaceOverview != null) _data = provider.workspaceOverview!;
    if (_selected != null &&
        !provider.classes.any((c) => c.id == _selected!.classModel.id)) {
      _selected = null;
    }
    final selected = _selected;
    if (selected != null) {
      return Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: LessonAttendanceView(
              key: ValueKey(
                '${selected.classModel.id}:${selected.slot.date}:${selected.slot.slotNumber}',
              ),
              classModel: selected.classModel,
              slot: selected.slot,
              data: _data[selected.classModel.id],
              refreshing: _loading,
              onRefresh: () => unawaited(_refresh()),
              onBack: () => setState(() => _selected = null),
            ),
          ),
        ],
      );
    }
    final all = <CalendarLesson>[
      for (final c in provider.classes)
        for (final slot in _data[c.id]?.slots ?? <SessionSlot>[])
          CalendarLesson(c, slot, _snapshotOnly ? null : _data[c.id]),
    ];
    final end = _week.add(const Duration(days: 7));
    final visible = all.where((lesson) {
      final date = DateTime.tryParse(lesson.slot.date);
      return date != null && !date.isBefore(_week) && date.isBefore(end);
    }).toList();
    final active = provider.activeSession;
    ClassModel? activeClass;
    if (active != null) {
      activeClass = provider.classes
          .where((c) => c.id == active.classId)
          .firstOrNull;
    }
    return ListView(
      controller: _calendarScroll,
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Lịch giảng dạy',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text('Tất cả lớp · Bấm vào lớp để điểm danh'),
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: () => setState(
                () => _week = _week.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${DateFormat('dd/MM/yyyy').format(_week)} – ${DateFormat('dd/MM/yyyy').format(end.subtract(const Duration(days: 1)))}',
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: () => setState(() => _week = end),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => setState(() => _week = _monday(DateTime.now())),
              child: const Text('Hôm nay'),
            ),
            IconButton(
              tooltip: 'Làm mới lịch',
              onPressed: _loading ? null : () => unawaited(_initialize()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_lastUpdated != null)
          Text(
            '${_error == null && !_snapshotOnly ? 'Cập nhật' : 'Lịch lưu tạm từ'}: ${DateFormat('dd/MM HH:mm:ss').format(_lastUpdated!)}',
          ),
        if (_error != null)
          SelectableText('Log chẩn đoán: ${PerformanceLog.path}'),
        if (_loading || provider.isLoading) const LinearProgressIndicator(),
        if (_error != null || provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error ?? provider.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (provider.hasActiveSession && active != null && activeClass != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FilledButton.tonal(
              onPressed: () => _open(
                CalendarLesson(
                  activeClass!,
                  active.slot,
                  _data[active.classId],
                ),
              ),
              child: Text(
                'Phiên đang mở · ${active.className} · ${active.slot.date} · Ca ${active.slot.slotNumber}',
              ),
            ),
          ),
        if (!_loading && _loaded && _error == null && visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Chưa có lịch trong tuần này. Không tự tạo lịch từ danh sách sinh viên.',
            ),
          ),
        if (!_loading && visible.isEmpty && all.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final dates =
                    all
                        .map((l) => DateTime.tryParse(l.slot.date))
                        .whereType<DateTime>()
                        .toList()
                      ..sort(
                        (a, b) => a
                            .difference(_week)
                            .abs()
                            .compareTo(b.difference(_week).abs()),
                      );
                if (dates.isNotEmpty) {
                  setState(() => _week = _monday(dates.first));
                }
              },
              child: const Text('Xem tuần có lịch gần nhất'),
            ),
          ),
        const SizedBox(height: 12),
        WeeklyScheduleGrid(week: _week, lessons: visible, onOpen: _open),
      ],
    );
  }
}
