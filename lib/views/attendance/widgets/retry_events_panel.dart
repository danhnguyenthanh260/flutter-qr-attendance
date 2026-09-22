import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/attendance_labels.dart';
import '../../../data/models/attendance_summary.dart';
import 'attendance_chips.dart';

class RetryEventsPanel extends StatelessWidget {
  final AttendanceSummary summary;

  const RetryEventsPanel({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final events = summary.retryEvents;
    final unlisted = summary.unlistedSubmissions;

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
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Nhật ký lượt nộp lại',
                          style: AppTypography.heading3),
                    ),
                    AttendanceChip(
                      label: '${events.length}',
                      color: AppColors.warning,
                      background: AppColors.warningBg,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Các lượt nộp không tạo thêm bản ghi điểm danh. Đây là thông tin đối chiếu, không phải kết luận gian lận.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: events.isEmpty && unlisted.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Chưa ghi nhận lượt nộp lại nào trong phạm vi này.',
                        style: AppTypography.bodySecondary,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      ...events.map((event) => _RetryEventTile(event: event)),
                      if (unlisted.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
                          child: Text(
                            'Lượt điểm danh ngoài roster',
                            style: AppTypography.heading3,
                          ),
                        ),
                        ...unlisted.map(
                          (item) => _UnlistedSubmissionTile(submission: item),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RetryEventTile extends StatelessWidget {
  final RetryEvent event;

  const _RetryEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final isRetry = event.attempt.isRetryOfAcceptedSubmission;
    final accent = isRetry ? AppColors.info : AppColors.warning;
    final background = isRetry ? const Color(0xFFF0F9FF) : AppColors.warningBg;
    final reason = AttendanceLabels.attemptReason(event.attempt.reason);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.displayName,
                  style: AppTypography.bodyRegular.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                event.occurredAt == null
                    ? '—'
                    : timeFormat.format(event.occurredAt!),
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            event.attempt.email,
            style: AppTypography.caption,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          AttendanceChip(
            label: AttendanceLabels.attemptType(event.attempt.attemptType),
            color: accent,
            background: AppColors.surface,
            icon: isRetry ? Icons.replay_rounded : Icons.block_rounded,
          ),
          if (reason != null) ...[
            const SizedBox(height: 8),
            _buildDetailLine(Icons.info_outline_rounded, reason),
          ],
          const SizedBox(height: 6),
          _buildDetailLine(
            Icons.confirmation_number_outlined,
            'Phiên ${event.sessionId}',
          ),
          if (event.hasOriginalSubmission) ...[
            const SizedBox(height: 6),
            _buildDetailLine(
              Icons.link_rounded,
              event.originalAcceptedAt == null
                  ? 'Lượt gốc: ${event.originalAttendanceId}'
                  : 'Lượt gốc lúc ${timeFormat.format(event.originalAcceptedAt!)}'
                      ' · ${event.originalAttendanceId}',
            ),
          ] else ...[
            const SizedBox(height: 6),
            _buildDetailLine(
              Icons.link_off_rounded,
              'Chưa có lượt điểm danh hợp lệ nào cho email này',
            ),
          ],
          if (!event.isOnRoster) ...[
            const SizedBox(height: 6),
            _buildDetailLine(
              Icons.person_search_outlined,
              'Email không thuộc roster lớp',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: AppTypography.caption),
        ),
      ],
    );
  }
}

class _UnlistedSubmissionTile extends StatelessWidget {
  final UnlistedSubmission submission;

  const _UnlistedSubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  submission.record.displayName,
                  style: AppTypography.bodyRegular.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                submission.acceptedAt == null
                    ? '—'
                    : timeFormat.format(submission.acceptedAt!),
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(submission.email, style: AppTypography.caption),
          const SizedBox(height: 8),
          const Text(
            'Có bản ghi điểm danh nhưng không nằm trong roster đang hoạt động, nên không tính vào tỷ lệ của lớp.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
