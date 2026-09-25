import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

class AiAssistantPlaceholderView extends StatelessWidget {
  const AiAssistantPlaceholderView({super.key});

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
                color: const Color(0xFFF3E8FF), // Purple 100
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: Color(0xFF9333EA), // Purple 600
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Trợ lý AI & Báo cáo Chuyên cần',
              style: AppTypography.heading2,
            ),
            const SizedBox(height: 8),
            const Text(
              'Phân hệ phụ trách: Người 5 (Issue #19 & Issue #24)',
              style: TextStyle(
                color: Color(0xFF9333EA),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không gian này dành sẵn để tích hợp:\n'
              '• Khung chat tương tác hỏi nhanh số liệu điểm danh (Issue #19)\n'
              '• Nút tạo báo cáo tổng quan tự động bằng mô hình AI (Issue #24)\n'
              '• Đối chiếu số liệu chính xác theo dữ liệu trích xuất từ Người 4',
              textAlign: TextAlign.left,
              style: AppTypography.bodyRegular,
            ),
          ],
        ),
      ),
    );
  }
}
