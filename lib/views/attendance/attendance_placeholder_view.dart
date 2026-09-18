import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class AttendancePlaceholderView extends StatelessWidget {
  const AttendancePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bảng điểm danh & Lịch sử buổi học',
              style: AppTypography.heading2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Phân hệ phụ trách: Người 2 (Issue #12 & Issue #23)',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không gian này dành sẵn để tích hợp:\n'
              '• Bảng đối chiếu Roster sinh viên hôm nay (có mặt / chưa điểm danh / vắng)\n'
              '• Cảnh báo nộp trùng lặp realtime (Issue #22)\n'
              '• Tra cứu lịch sử các buổi học và tổng hợp tỷ lệ chuyên cần (Issue #23)',
              textAlign: TextAlign.left,
              style: AppTypography.bodyRegular,
            ),
          ],
        ),
      ),
    );
  }
}
