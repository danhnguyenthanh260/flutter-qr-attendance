import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/date_key.dart';
import '../../data/models/attendance_summary.dart';
import '../../data/models/class_model.dart';
import '../../data/models/session_day_group.dart';
import 'attendance_history_provider.dart';
import 'widgets/attendance_chips.dart';
import 'widgets/attendance_roster_table.dart';
import 'widgets/attendance_state_message.dart';
import 'widgets/attendance_summary_cards.dart';
import 'widgets/retry_events_panel.dart';

class HistoryAttendanceView extends StatefulWidget {
  const HistoryAttendanceView({super.key});

  @override
  State<HistoryAttendanceView> createState() => _HistoryAttendanceViewState();
}

class _HistoryAttendanceViewState extends State<HistoryAttendanceView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceHistoryProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceHistoryProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryFilterBar(provider: provider),
              const SizedBox(height: 16),
              Expanded(child: _buildBody(provider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(AttendanceHistoryProvider provider) {
    switch (provider.status) {
      case HistoryDataStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );

      case HistoryDataStatus.noClasses:
        return const AttendanceStateMessage(
          icon: Icons.school_outlined,
          title: 'Chưa có lớp học nào',
          message: 'Không có lớp nào để tra cứu lịch sử điểm danh.',
        );

      case HistoryDataStatus.empty:
        return AttendanceStateMessage(
          icon: Icons.history_toggle_off_rounded,
          title: 'Không có buổi học nào trong khoảng đã chọn',
          message:
              'Hãy mở rộng khoảng ngày hoặc chọn lớp khác. Khoảng trống lịch sử '
              'không được hiểu là buổi học có sinh viên vắng.',
          action: FilledButton.icon(
            onPressed: provider.loadGroups,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Tải lại'),
          ),
        );

      case HistoryDataStatus.unavailable:
        return AttendanceStateMessage.error(
          title: 'Không đọc được lịch sử buổi học',
          message:
              provider.errorMessage ??
              'Không thể tải danh sách phiên từ máy chủ.',
          action: FilledButton.icon(
            onPressed: provider.loadGroups,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        );

      case HistoryDataStatus.ok:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 340, child: _SessionGroupList(provider: provider)),
            const SizedBox(width: 16),
            Expanded(child: _HistoryDetailPane(provider: provider)),
          ],
        );
    }
  }
}

class _HistoryFilterBar extends StatelessWidget {
  final AttendanceHistoryProvider provider;

  const _HistoryFilterBar({required this.provider});

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
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<ClassModel>(
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
            ),
          ),
          SizedBox(
            width: 180,
            child: _buildDateField(
              context,
              label: 'Từ ngày',
              value: provider.fromDate,
              onPicked: (picked) => provider.setRange(picked, provider.toDate),
            ),
          ),
          SizedBox(
            width: 180,
            child: _buildDateField(
              context,
              label: 'Đến ngày',
              value: provider.toDate,
              onPicked: (picked) =>
                  provider.setRange(provider.fromDate, picked),
            ),
          ),
          FilledButton.icon(
            onPressed: provider.loadGroups,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Tra cứu'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    required DateTime value,
    required Future<void> Function(DateTime) onPicked,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(value.year - 2),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          locale: const Locale('vi', 'VN'),
        );
        if (picked != null) {
          await onPicked(picked);
        }
      },
      child: InputDecorator(
        decoration: _decoration(label, Icons.calendar_today_outlined),
        child: Text(
          DateFormat('dd/MM/yyyy').format(value),
          style: AppTypography.bodyRegular,
        ),
      ),
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

class _SessionGroupList extends StatelessWidget {
  final AttendanceHistoryProvider provider;

  const _SessionGroupList({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Buổi học', style: AppTypography.heading3),
                ),
                Text('${provider.groups.length}', style: AppTypography.caption),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: provider.groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final group = provider.groups[index];
                return _SessionGroupTile(
                  group: group,
                  isSelected: provider.selectedGroup?.key == group.key,
                  onTap: () => provider.selectGroup(group),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionGroupTile extends StatelessWidget {
  final SessionDayGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  const _SessionGroupTile({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final date = parseDateKey(group.date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date == null
                    ? group.date
                    : DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(date),
                style: AppTypography.bodyRegular.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Slot ${group.slotNumber} · ${group.timeRange}',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AttendanceChip(
                    label: '${group.sessionCount} phiên',
                    color: AppColors.textSecondary,
                    background: AppColors.surfaceVariant,
                    icon: Icons.layers_outlined,
                  ),
                  if (group.isFinalized)
                    const AttendanceChip(
                      label: 'Đã chốt',
                      color: AppColors.success,
                      background: AppColors.successBg,
                      icon: Icons.verified_outlined,
                    )
                  else if (group.isSettling)
                    const AttendanceChip(
                      label: 'Đang chốt sổ',
                      color: AppColors.warning,
                      background: AppColors.warningBg,
                      icon: Icons.sync_rounded,
                    )
                  else
                    const AttendanceChip(
                      label: 'Còn phiên mở',
                      color: AppColors.info,
                      background: Color(0xFFF0F9FF),
                      icon: Icons.radio_button_checked,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDetailPane extends StatelessWidget {
  final AttendanceHistoryProvider provider;

  const _HistoryDetailPane({required this.provider});

  @override
  Widget build(BuildContext context) {
    switch (provider.detailStatus) {
      case HistoryDetailStatus.none:
        return const AttendanceStateMessage(
          icon: Icons.touch_app_outlined,
          title: 'Chọn một buổi học',
          message:
              'Chọn buổi ở danh sách bên trái để xem bảng tổng kết chi tiết.',
        );

      case HistoryDetailStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );

      case HistoryDetailStatus.rosterMissing:
        return AttendanceStateMessage.warning(
          title: 'Buổi học thiếu roster',
          message:
              provider.detailErrorMessage ??
              'Không đọc được danh sách lớp nên không thể đối chiếu kết quả.',
          action: FilledButton.icon(
            onPressed: provider.refreshDetail,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Đọc lại'),
          ),
        );

      case HistoryDetailStatus.unavailable:
        return AttendanceStateMessage.error(
          title: 'Không đọc được kết quả buổi học',
          message:
              provider.detailErrorMessage ??
              'Một hoặc nhiều phiên của buổi này không đọc được. Hệ thống không '
                  'suy ra danh sách vắng từ dữ liệu thiếu.',
          action: FilledButton.icon(
            onPressed: provider.refreshDetail,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        );

      case HistoryDetailStatus.ok:
        final detail = provider.detail;
        if (detail == null) return const SizedBox.shrink();
        return _buildDetail(detail);
    }
  }

  Widget _buildDetail(AttendanceSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(summary.scope.label, style: AppTypography.heading3),
            Text(
              'Đọc lúc ${DateFormat('dd/MM HH:mm:ss').format(summary.asOf)}',
              style: AppTypography.caption,
            ),
            Text(
              'Nguồn: ${summary.scope.sessionIds.join(', ')}',
              style: AppTypography.caption,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.sessions.length > 1) ...[
          const AttendanceInlineBanner(
            icon: Icons.merge_type_rounded,
            accent: AppColors.info,
            background: Color(0xFFF0F9FF),
            message:
                'Buổi này có nhiều phiên. Sinh viên được hợp nhất theo email nên '
                'không bị cộng trùng giữa các phiên.',
          ),
          const SizedBox(height: 12),
        ],
        if (summary.rosterChangedBetweenSessions) ...[
          const AttendanceInlineBanner(
            icon: Icons.published_with_changes_rounded,
            accent: AppColors.warning,
            background: AppColors.warningBg,
            message: 'Roster có thay đổi giữa các phiên của buổi này. Số liệu dùng roster hợp nhất mới nhất.',
          ),
          const SizedBox(height: 12),
        ],
        if (!summary.isFinalized) ...[
          const AttendanceInlineBanner(
            icon: Icons.hourglass_top_rounded,
            accent: AppColors.warning,
            background: AppColors.warningBg,
            message: 'Buổi này còn phiên chưa chốt nên số liệu là tạm tính, chưa kết luận vắng.',
          ),
          const SizedBox(height: 12),
        ],
        AttendanceSummaryCards(summary: summary),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 960) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AttendanceRosterTable(summary: summary),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 340,
                      child: RetryEventsPanel(summary: summary),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 380,
                      child: AttendanceRosterTable(summary: summary),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: RetryEventsPanel(summary: summary),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
