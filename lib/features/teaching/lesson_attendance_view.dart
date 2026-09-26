import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/teaching_overview.dart';
import '../qr/qr_display_view.dart';
import 'attendance_date_policy.dart';
import 'session_provider.dart';

class LessonAttendanceView extends StatefulWidget {
  const LessonAttendanceView({
    super.key,
    required this.classModel,
    required this.slot,
    required this.data,
    required this.onBack,
    required this.onRefresh,
    required this.refreshing,
  });
  final ClassModel classModel;
  final SessionSlot slot;
  final TeachingOverview? data;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool refreshing;
  @override
  State<LessonAttendanceView> createState() => _LessonAttendanceViewState();
}

class _LessonAttendanceViewState extends State<LessonAttendanceView> {
  bool _showQr = false;
  bool _starting = false;
  bool _matches(AttendanceSession? session) =>
      session != null &&
      session.classId == widget.classModel.id &&
      session.slot.date == widget.slot.date &&
      session.slot.slotNumber == widget.slot.slotNumber;
  Future<void> _attend() async {
    final provider = context.read<SessionProvider>();
    if (_starting || isPastAttendanceDate(widget.slot.date)) return;
    if (provider.hasActiveSession) {
      if (_matches(provider.activeSession)) setState(() => _showQr = true);
      return;
    }
    setState(() => _starting = true);
    try {
      if (widget.slot.date != attendanceToday()) {
        final agreed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Điểm danh trước ngày học'),
            content: Text(
              '${widget.classModel.name} · ${widget.classModel.courseCode}\nNgày ${widget.slot.date} · Ca ${widget.slot.slotNumber}\nKết quả sẽ được ghi cho đúng buổi này.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Điểm danh buổi này'),
              ),
            ],
          ),
        );
        if (agreed != true || !mounted) return;
      }
      // Resolve once more after the confirmation, without a new catalog request.
      provider.selectLesson(widget.classModel, widget.slot);
      final started = await provider.startSession();
      if (mounted && started && _matches(provider.activeSession)) {
        setState(() => _showQr = true);
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    if (_showQr &&
        provider.hasActiveSession &&
        _matches(provider.activeSession)) {
      return QrDisplayView(
        onBackToSelection: () {
          setState(() => _showQr = false);
          widget.onRefresh();
        },
      );
    }
    final data = widget.data;
    final otherActive =
        provider.hasActiveSession && !_matches(provider.activeSession);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Về lịch tuần'),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.classModel.name} · ${widget.classModel.courseCode}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          'Ngày ${widget.slot.date} · Ca ${widget.slot.slotNumber} · ${widget.slot.timeRange}${widget.classModel.room.isEmpty ? '' : ' · Phòng ${widget.classModel.room}'}',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed:
                  isPastAttendanceDate(widget.slot.date) ||
                      _starting ||
                      provider.isStartingSession ||
                      otherActive ||
                      !provider.canStartSession ||
                      ((!provider.hasActiveSession ||
                              !_matches(provider.activeSession)) &&
                          (data == null || data.roster.isEmpty))
                  ? null
                  : _attend,
              icon: const Icon(Icons.qr_code_2),
              label: Text(
                _starting || provider.isStartingSession
                    ? 'Đang mở điểm danh…'
                    : provider.hasActiveSession &&
                          _matches(provider.activeSession)
                    ? 'Xem mã QR'
                    : 'Điểm danh',
              ),
            ),
            Text(
              '${data?.present(widget.slot) ?? 0}/${data?.roster.length ?? 0} sinh viên đã điểm danh',
            ),
            TextButton.icon(
              onPressed: widget.refreshing ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Cập nhật danh sách'),
            ),
          ],
        ),
        if (isPastAttendanceDate(widget.slot.date))
          const Text(
            'Buổi học đã qua: chỉ xem kết quả, không mở điểm danh mới.',
          ),
        if (provider.hasActiveSession)
          TextButton(
            onPressed: provider.isClosingSession
                ? null
                : () async {
                    final active = provider.activeSession!;
                    final agreed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Đóng phiên đang mở?'),
                        content: Text(
                          '${active.classId} · Ngày ${active.slot.date} · Ca ${active.slot.slotNumber}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Quay lại'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Đóng phiên'),
                          ),
                        ],
                      ),
                    );
                    if (agreed == true) await provider.closeSession();
                  },
            child: Text(
              'Đóng phiên đang mở · ${provider.activeSession!.classId} · ${provider.activeSession!.slot.date} · Ca ${provider.activeSession!.slot.slotNumber}',
            ),
          ),
        if (otherActive)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Một buổi khác đang điểm danh. Quay lại lịch để mở đúng buổi đang hoạt động.',
            ),
          ),
        if (provider.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              provider.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (widget.refreshing) const LinearProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Danh sách sinh viên',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'P: có mặt · A: vắng sau khi đóng phiên · …: chưa chốt · —: chưa mở điểm danh. Kết quả có thể cập nhật khi Form xử lý trễ.',
        ),
        if (data == null)
          const Text('Chưa tải được danh sách lớp. Hãy thử cập nhật lại.'),
        if (data != null && data.roster.isEmpty)
          const Text('Lớp chưa có roster. Nhập danh sách trước khi điểm danh.'),
        if (data != null && data.roster.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('MSSV')),
                DataColumn(label: Text('Họ tên')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Điểm danh')),
              ],
              rows: data.roster
                  .map(
                    (student) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            student.rollNumber.isEmpty
                                ? '—'
                                : student.rollNumber,
                          ),
                        ),
                        DataCell(Text(student.displayName)),
                        DataCell(Text(student.email)),
                        DataCell(Text(data.status(student, widget.slot))),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
