import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_icons.dart';

enum NoticeKind { loading, empty, error, info }

/// Data and callbacks only: this component owns no requests or provider state.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.message,
    this.kind = NoticeKind.info,
    this.onRetry,
    this.onDismiss,
  });
  final String message;
  final NoticeKind kind;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final error = kind == NoticeKind.error;
    final color = error ? AppColors.error : AppColors.primary;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: error ? AppColors.errorBg : AppColors.primaryLight,
          border: Border.all(color: color.withValues(alpha: .25)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kind == NoticeKind.loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                error ? AppIcons.error : AppIcons.classroom,
                color: color,
                size: 24,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: TextStyle(color: color)),
                  if (onRetry != null)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(AppIcons.refresh),
                      label: const Text('Thử lại'),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: 'Ẩn thông báo',
                onPressed: onDismiss,
                icon: const Icon(AppIcons.close),
              ),
          ],
        ),
      ),
    );
  }
}
