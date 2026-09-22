import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class AttendanceStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final Widget? action;

  const AttendanceStateMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = AppColors.textSecondary,
    this.action,
  });

  const AttendanceStateMessage.error({
    super.key,
    required this.title,
    required this.message,
    this.action,
  })  : icon = Icons.wifi_off_rounded,
        accent = AppColors.error;

  const AttendanceStateMessage.warning({
    super.key,
    required this.title,
    required this.message,
    this.action,
  })  : icon = Icons.report_problem_outlined,
        accent = AppColors.warning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: accent),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppTypography.heading3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodySecondary,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AttendanceInlineBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color accent;
  final Color background;
  final Widget? trailing;

  const AttendanceInlineBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.accent,
    required this.background,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
