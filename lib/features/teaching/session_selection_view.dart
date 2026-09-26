import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/teaching_overview.dart';
import 'lesson_session_view.dart';
import 'session_provider.dart';

class SessionSelectionView extends StatefulWidget {
  const SessionSelectionView({super.key});
  @override
  State<SessionSelectionView> createState() => _SessionSelectionViewState();
}

class _SessionSelectionViewState extends State<SessionSelectionView> {
  DateTime _week = _monday(DateTime.now());
  TeachingOverview? _data;
  ClassModel? _class;
  SessionSlot? _lesson;
  bool _loading = false;
  String? _error;
  int _request = 0;
  static DateTime _monday(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    final p = context.read<SessionProvider>();
    if (p.classes.isEmpty) await p.loadInitialData();
    if (mounted && _class == null && p.classes.isNotEmpty) {
      await _load(p.selectedClass ?? p.classes.first);
    }
  }

  Future<void> _load(ClassModel c) async {
    final request = ++_request;
    final p = context.read<SessionProvider>();
    setState(() {
      if (_class != c) _data = null;
      _class = c;
      _loading = true;
      _error = null;
    });
    try {
      final data = await p.loadOverview(c.id);
      if (mounted && request == _request) setState(() => _data = data);
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () =>
              _error = 'Không tải được lịch và danh sách lớp. Hãy thử làm mới.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(SessionSlot slot) async {
    final p = context.read<SessionProvider>();
    await p.selectClass(_class);
    if (!mounted) return;
    p.selectSlot(slot);
    setState(() => _lesson = slot);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SessionProvider>();
    if (_class == null && !_loading && p.classes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _class == null && !_loading) {
          unawaited(_load(p.classes.first));
        }
      });
    }
    final data = _data;
    if (_lesson != null) {
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _lesson = null);
                if (_class != null) unawaited(_load(_class!));
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Về lịch tuần'),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const LessonSessionView(),
                if (data != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: _matrix(data, [_lesson!]),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    final days = List.generate(7, (i) => _week.add(Duration(days: i)));
    final slots =
        data?.slots
            .where((s) => days.any((d) => _date(d) == s.date))
            .toList() ??
        <SessionSlot>[];
    final numbers = {
      ...List.generate(6, (i) => i + 1),
      ...slots.map((s) => s.slotNumber),
    }.toList()..sort();
    return ListView(
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
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<ClassModel>(
                key: ValueKey(_class?.id),
                initialValue: _class,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lớp / môn học'),
                items: p.classes
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          '${c.name} · ${c.courseCode}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (c) {
                  if (c != null) unawaited(_load(c));
                },
              ),
            ),
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: () => setState(
                () => _week = _week.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${DateFormat('dd/MM/yyyy').format(days.first)} – ${DateFormat('dd/MM/yyyy').format(days.last)}',
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: () =>
                  setState(() => _week = _week.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: () => setState(() => _week = _monday(DateTime.now())),
              child: const Text('Hôm nay'),
            ),
            IconButton(
              tooltip: 'Làm mới lịch',
              onPressed: _loading
                  ? null
                  : () => unawaited(
                      _class == null ? _initialize() : _load(_class!),
                    ),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (p.hasActiveSession)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FilledButton.tonal(
              onPressed: () {
                final session = p.activeSession!;
                final c = p.classes
                    .where((c) => c.id == session.classId)
                    .firstOrNull;
                if (c != null) {
                  unawaited(_load(c));
                  unawaited(_open(session.slot));
                }
              },
              child: Text(
                'Phiên đang mở · ${p.activeSession!.slot.date} · Ca ${p.activeSession!.slot.slotNumber}',
              ),
            ),
          ),
        if (_loading || p.isLoading) const LinearProgressIndicator(),
        if (_error != null || p.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error ?? p.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!_loading && slots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Chưa có lịch trong tuần này. Danh sách sinh viên không chứa lịch học.',
            ),
          ),
        if (data != null && data.slots.isNotEmpty && slots.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final ordered = [...data.slots]
                  ..sort((a, b) => a.date.compareTo(b.date));
                final d = DateTime.tryParse(ordered.last.date);
                if (d != null) setState(() => _week = _monday(d));
              },
              child: const Text('Xem tuần có lịch gần nhất'),
            ),
          ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width > 1164
                ? MediaQuery.sizeOf(context).width - 264
                : 900,
            child: Table(
              border: TableBorder.all(color: Theme.of(context).dividerColor),
              columnWidths: const {0: FixedColumnWidth(64)},
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Ca'),
                    ),
                    for (var i = 0; i < 7; i++)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i]}\n${DateFormat('dd/MM').format(days[i])}',
                        ),
                      ),
                  ],
                ),
                for (final number in numbers)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('$number'),
                      ),
                      for (final day in days)
                        _cell(
                          slots
                              .where(
                                (s) =>
                                    s.slotNumber == number &&
                                    s.date == _date(day),
                              )
                              .toList(),
                          data,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (data != null) ...[const SizedBox(height: 24), _matrix(data, slots)],
      ],
    );
  }

  Widget _cell(
    List<SessionSlot> slots,
    TeachingOverview? data,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 60),
    child: Column(
      children: [
        for (final slot in slots)
          InkWell(
            onTap: () => unawaited(_open(slot)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_class!.name} · ${_class!.courseCode}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(slot.timeRange),
                  if (_class!.room.isNotEmpty) Text(_class!.room),
                  Text(
                    '${data!.present(slot)}/${data.roster.length} đã điểm danh',
                  ),
                  Text(
                    data.sessionsFor(slot).isEmpty
                        ? 'Chưa mở phiên'
                        : data
                              .sessionsFor(slot)
                              .any((s) => s.status == SessionStatus.active)
                        ? 'Đang mở'
                        : data
                              .sessionsFor(slot)
                              .any((s) => s.status == SessionStatus.closing)
                        ? 'Đang đóng'
                        : 'Đã đóng',
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  Widget _matrix(TeachingOverview data, List<SessionSlot> slots) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Danh sách & chuyên cần · ${data.roster.length} sinh viên',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'P: có mặt · A: vắng sau khi đóng phiên · …: chưa chốt · —: chưa có phiên. Kết quả có thể cập nhật khi Form xử lý trễ.',
      ),
      if (data.roster.isEmpty)
        const Text('Chưa có danh sách lớp được xác minh.'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('MSSV')),
            const DataColumn(label: Text('Sinh viên')),
            const DataColumn(label: Text('Email')),
            for (final slot in slots)
              DataColumn(label: Text('${slot.date}\nCa ${slot.slotNumber}')),
          ],
          rows: [
            for (final r in data.roster)
              DataRow(
                cells: [
                  DataCell(Text(r.rollNumber.isEmpty ? '—' : r.rollNumber)),
                  DataCell(Text(r.displayName)),
                  DataCell(Text(r.email)),
                  for (final slot in slots)
                    DataCell(Text(data.status(r, slot))),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}
