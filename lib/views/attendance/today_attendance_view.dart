import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_key.dart';
import '../../data/models/attendance_summary.dart';
import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../providers/attendance_results_provider.dart';
import 'widgets/attendance_chips.dart';
import 'widgets/attendance_roster_table.dart';
import 'widgets/attendance_state_message.dart';
import 'widgets/attendance_summary_cards.dart';

class TodayAttendanceView extends StatefulWidget {
  const TodayAttendanceView({super.key});

  @override
  State<TodayAttendanceView> createState() => _TodayAttendanceViewState();
}

class _TodayAttendanceViewState extends State<TodayAttendanceView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceResultsProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceResultsProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilterBar(provider: provider),
              const SizedBox(height: 16),
              Expanded(child: _buildBody(context, provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AttendanceResultsProvider provider) {
    switch (provider.status) {
      case AttendanceDataStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Đang đọc dữ liệu điểm danh...',
                  style: AppTypography.bodySecondary),
            ],
          ),
        );

      case AttendanceDataStatus.noClasses:
        return const AttendanceStateMessage(
          icon: Icons.school_outlined,
          title: 'Chưa có lớp học nào',
          message:
              'Tài khoản giáo viên chưa được gán lớp nào trong bảng Classes. '
              'Không thể suy ra số liệu điểm danh khi thiếu dữ liệu lớp.',
        );

      case AttendanceDataStatus.noSession:
        return AttendanceStateMessage(
          icon: Icons.event_busy_outlined,
          title: 'Chưa có phiên điểm danh',
          message:
              'Lớp này chưa mở phiên nào trong ngày đã chọn. Đây không phải là '
              'dữ liệu vắng: hệ thống không suy ra kết quả khi chưa có phiên.',
          action: FilledButton.icon(
            onPressed: provider.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Kiểm tra lại'),
          ),
        );

      case AttendanceDataStatus.rosterMissing:
        return AttendanceStateMessage.warning(
          title: 'Lớp chưa có danh sách sinh viên',
          message: provider.errorMessage ??
              'Không đọc được roster của lớp. Hệ thống không hiển thị số 0 và '
                  'không kết luận cả lớp vắng khi thiếu danh sách.',
          action: FilledButton.icon(
            onPressed: provider.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Đọc lại'),
          ),
        );

      case AttendanceDataStatus.unavailable:
        return AttendanceStateMessage.error(
          title: 'Không đọc được dữ liệu điểm danh',
          message: provider.errorMessage ??
              'Kết nối tới máy chủ đang gặp sự cố. Số liệu cũ không được hiển '
                  'thị như số liệu đã xác nhận.',
          action: FilledButton.icon(
            onPressed: provider.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        );

      case AttendanceDataStatus.ok:
        final summary = provider.summary;
        if (summary == null) {
          return const SizedBox.shrink();
        }
        return _buildContent(provider, summary);
    }
  }

  Widget _buildContent(
    AttendanceResultsProvider provider,
    AttendanceSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScopeStatusBar(provider: provider, summary: summary),
        const SizedBox(height: 12),
        _StatusNoticeBanner(summary: summary),
        AttendanceSummaryCards(summary: summary),
        const SizedBox(height: 16),
        Expanded(child: AttendanceRosterTable(summary: summary)),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final AttendanceResultsProvider provider;

  const _FilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 300, child: _buildClassSelector(context)),
          SizedBox(width: 190, child: _buildDateSelector(context)),
          SizedBox(width: 280, child: _buildSessionSelector(context)),
          FilledButton.icon(
            onPressed: provider.isRefreshing ? null : provider.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Làm mới'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector(BuildContext context) {
    return DropdownButtonFormField<ClassModel>(
      initialValue: provider.selectedClass,
      isExpanded: true,
      decoration: _decoration('Lớp học', Icons.class_outlined),
      items: provider.classes
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                '${item.courseCode} · ${item.name}',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyRegular,
              ),
            ),
          )
          .toList(),
      onChanged: provider.selectClass,
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final selected = parseDateKey(provider.selectedDate) ?? DateTime.now();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selected,
          firstDate: DateTime(selected.year - 2),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          locale: const Locale('vi', 'VN'),
        );
        if (picked != null) {
          await provider.selectDate(picked);
        }
      },
      child: InputDecorator(
        decoration: _decoration('Ngày học', Icons.calendar_today_outlined),
        child: Text(
          DateFormat('dd/MM/yyyy').format(selected),
          style: AppTypography.bodyRegular,
        ),
      ),
    );
  }

  Widget _buildSessionSelector(BuildContext context) {
    final sessions = provider.sessions;

    if (sessions.isEmpty) {
      return InputDecorator(
        decoration: _decoration('Phiên điểm danh', Icons.timelapse_rounded),
        child: const Text('Không có phiên', style: AppTypography.bodySecondary),
      );
    }

    return DropdownButtonFormField<AttendanceSession>(
      initialValue: provider.selectedSession,
      isExpanded: true,
      decoration: _decoration('Phiên điểm danh', Icons.timelapse_rounded),
      items: sessions
          .map(
            (session) => DropdownMenuItem(
              value: session,
              child: Text(
                'Slot ${session.slot.slotNumber} · '
                '${DateFormat('HH:mm').format(session.openedAt)} · '
                '${session.status.name}',
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyRegular,
              ),
            ),
          )
          .toList(),
      onChanged: provider.selectSession,
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.caption,
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _ScopeStatusBar extends StatelessWidget {
  final AttendanceResultsProvider provider;
  final AttendanceSummary summary;

  const _ScopeStatusBar({required this.provider, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(summary.scope.label, style: AppTypography.heading3),
        SessionStatusChip(status: summary.session.status),
        if (provider.isRefreshing)
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Text('Đang đọc...', style: AppTypography.caption),
            ],
          )
        else
          Text(
            'Số liệu đọc lúc ${DateFormat('HH:mm:ss').format(summary.asOf)}',
            style: AppTypography.caption,
          ),
        Text(
          'Nguồn: ${summary.scope.sessionId}',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _StatusNoticeBanner extends StatelessWidget {
  final AttendanceSummary summary;

  const _StatusNoticeBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.isFinalized) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AttendanceInlineBanner(
          icon: Icons.verified_outlined,
          accent: AppColors.success,
          background: AppColors.successBg,
          message:
              'Phiên đã chốt sổ. Sinh viên không có bản ghi điểm danh được tính là vắng.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AttendanceInlineBanner(
        icon: summary.isSettling
            ? Icons.sync_rounded
            : Icons.hourglass_top_rounded,
        accent: AppColors.warning,
        background: AppColors.warningBg,
        message: summary.isSettling
            ? 'Phiên đang chốt sổ và còn xử lý lượt nộp. Số liệu là tạm tính, chưa kết luận vắng.'
            : 'Phiên đang mở. Số liệu là tạm tính: sinh viên chưa quét được ghi nhận là chưa điểm danh, không phải vắng.',
      ),
    );
  }
}
