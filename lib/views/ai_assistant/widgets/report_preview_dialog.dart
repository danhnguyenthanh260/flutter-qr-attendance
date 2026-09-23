import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class ReportPreviewDialog extends StatelessWidget {
  final String reportContent;

  const ReportPreviewDialog({
    super.key,
    required this.reportContent,
  });

  static Future<void> show(BuildContext context, String report) {
    return showDialog(
      context: context,
      builder: (ctx) => ReportPreviewDialog(reportContent: report),
    );
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: reportContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép toàn bộ báo cáo vào bộ nhớ tạm!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Báo cáo Chuyên cần Buổi học',
              style: AppTypography.heading2,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 520,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              reportContent,
              style: const TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 13.5,
                height: 1.6,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_all_rounded, size: 18),
          label: const Text('Sao chép báo cáo'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
