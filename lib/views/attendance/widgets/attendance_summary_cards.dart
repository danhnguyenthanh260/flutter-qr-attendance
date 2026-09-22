import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/attendance_summary.dart';

class AttendanceSummaryCards extends StatelessWidget {
  final AttendanceSummary summary;

  const AttendanceSummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final rate = summary.attendanceRate;

    final cards = <_StatCardData>[
      _StatCardData(
        icon: Icons.groups_2_outlined,
        label: 'Sĩ số roster',
        value: '${summary.totalStudents}',
        caption: 'Mẫu số của mọi tỷ lệ',
        color: AppColors.primary,
        background: AppColors.primaryLight,
      ),
      _StatCardData(
        icon: Icons.how_to_reg_outlined,
        label: 'Đã điểm danh',
        value: '${summary.presentCount}',
        caption: rate == null
            ? 'Chưa có roster để tính tỷ lệ'
            : 'Tỷ lệ ${(rate * 100).toStringAsFixed(1)}%',
        color: AppColors.success,
        background: AppColors.successBg,
      ),
      if (summary.isFinalized)
        _StatCardData(
          icon: Icons.person_off_outlined,
          label: 'Vắng',
          value: '${summary.absentCount}',
          caption: 'Đã chốt sổ, số liệu cuối cùng',
          color: AppColors.error,
          background: AppColors.errorBg,
        )
      else
        _StatCardData(
          icon: Icons.hourglass_bottom_rounded,
          label: 'Chưa điểm danh',
          value: '${summary.notYetCount}',
          caption: 'Chỉ tính vắng sau khi chốt phiên',
          color: AppColors.warning,
          background: AppColors.warningBg,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final columns = constraints.maxWidth >= 860 ? 3 : 1;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (data) => SizedBox(
                  width: cardWidth,
                  child: _StatCard(data: data),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;
  final Color background;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.background,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 18, color: data.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.label,
                  style: AppTypography.bodySecondary,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            style: AppTypography.heading1.copyWith(color: data.color),
          ),
          const SizedBox(height: 4),
          Text(
            data.caption,
            style: AppTypography.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
