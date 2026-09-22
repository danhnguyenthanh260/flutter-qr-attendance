import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/attendance_labels.dart';
import '../../../data/models/attendance_summary.dart';
import '../../../data/models/session_model.dart';

class AttendanceChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const AttendanceChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentStatusChip extends StatelessWidget {
  final StudentAttendanceStatus status;

  const StudentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StudentAttendanceStatus.present:
        return AttendanceChip(
          label: AttendanceLabels.studentStatus(status),
          color: AppColors.success,
          background: AppColors.successBg,
          icon: Icons.check_circle_outline,
        );
      case StudentAttendanceStatus.notYet:
        return AttendanceChip(
          label: AttendanceLabels.studentStatus(status),
          color: AppColors.warning,
          background: AppColors.warningBg,
          icon: Icons.hourglass_empty_rounded,
        );
      case StudentAttendanceStatus.absent:
        return AttendanceChip(
          label: AttendanceLabels.studentStatus(status),
          color: AppColors.error,
          background: AppColors.errorBg,
          icon: Icons.cancel_outlined,
        );
    }
  }
}

class SessionStatusChip extends StatelessWidget {
  final SessionStatus status;

  const SessionStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SessionStatus.active:
        return AttendanceChip(
          label: AttendanceLabels.sessionStatus(status),
          color: AppColors.success,
          background: AppColors.successBg,
          icon: Icons.radio_button_checked,
        );
      case SessionStatus.closing:
        return AttendanceChip(
          label: AttendanceLabels.sessionStatus(status),
          color: AppColors.warning,
          background: AppColors.warningBg,
          icon: Icons.sync_rounded,
        );
      case SessionStatus.closed:
        return AttendanceChip(
          label: AttendanceLabels.sessionStatus(status),
          color: AppColors.textSecondary,
          background: AppColors.surfaceVariant,
          icon: Icons.lock_outline_rounded,
        );
      case SessionStatus.idle:
        return AttendanceChip(
          label: AttendanceLabels.sessionStatus(status),
          color: AppColors.textMuted,
          background: AppColors.surfaceVariant,
          icon: Icons.schedule_rounded,
        );
    }
  }
}
