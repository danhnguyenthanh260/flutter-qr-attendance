import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../providers/ai_assistant_provider.dart';

class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const AiSettingsDialog(),
    );
  }

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  late TextEditingController _controller;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AiAssistantProvider>();
    _controller = TextEditingController(text: provider.apiKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Cấu hình Trợ lý AI (Gemini)', style: AppTypography.heading2),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống hỗ trợ gọi trực tiếp mô hình **Google Gemini 1.5 Flash** để phân tích điểm danh thông minh.',
              style: AppTypography.bodyRegular,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: provider.hasApiKey
                    ? AppColors.successBg
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: provider.hasApiKey
                      ? AppColors.success
                      : const Color(0xFFF59E0B),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    provider.hasApiKey ? Icons.check_circle : Icons.info_outline,
                    color: provider.hasApiKey
                        ? AppColors.success
                        : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.hasApiKey
                          ? 'Đã cấu hình Gemini API Key. Đang hoạt động ở chế độ Online AI.'
                          : 'Chưa có Gemini API Key. Đang hoạt động ở chế độ Phân tích Nội suy Cục bộ (Local Engine).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: provider.hasApiKey
                            ? const Color(0xFF166534)
                            : const Color(0xFF92400E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gemini API Key:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              decoration: InputDecoration(
                hintText: 'Nhập khóa API (AIzaSy...)',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💡 Mẹo: Bạn có thể lấy khóa API miễn phí từ Google AI Studio (aistudio.google.com). Nếu để trống, hệ thống vẫn tự động phân tích chính xác số liệu điểm danh bằng bộ máy tính toán nội suy.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        if (provider.hasApiKey)
          TextButton(
            onPressed: () {
              provider.setApiKey('');
              _controller.clear();
            },
            child: const Text('Xóa Key (Về Offline)', style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            provider.setApiKey(_controller.text);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã lưu cấu hình AI thành công!'),
                backgroundColor: AppColors.success,
              ),
            );
          },
          child: const Text('Lưu cấu hình'),
        ),
      ],
    );
  }
}
