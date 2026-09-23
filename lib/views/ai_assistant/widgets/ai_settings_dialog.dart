import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/services/gemini_key_rotator.dart';
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
  final TextEditingController _inputController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _handleAddKeys(AiAssistantProvider provider) {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final count = provider.addApiKeysFromText(text);
    _inputController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Đã thêm $count API Key vào hệ thống xoay vòng!'
                : 'Key đã tồn tại hoặc không hợp lệ.',
          ),
          backgroundColor: count > 0 ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final keys = provider.apiKeys;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Cấu hình Gemini Key Rotation', style: AppTypography.heading2),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hệ thống hỗ trợ gọi mô hình **Google Gemini 1.5 Flash** với cơ chế **Xoay vòng đa khóa (Key Rotation)** và **Tự động Failover** khi gặp lỗi Rate Limit (429).',
                style: AppTypography.bodyRegular,
              ),
              const SizedBox(height: 16),

              // Status Banner
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
                            ? (keys.length > 1
                                ? 'Đang xoay vòng ${keys.length} API Keys (Round-Robin & Auto-Failover 429).'
                                : 'Đã cấu hình 1 Gemini API Key. Đang hoạt động ở chế độ Online AI.')
                            : 'Chưa có API Key. Đang hoạt động ở chế độ Phân tích Nội suy Cục bộ (Local Engine).',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: provider.hasApiKey
                              ? const Color(0xFF166534)
                              : const Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Danh sách Keys đã nạp
              if (keys.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách Keys đang xoay vòng (${keys.length}):',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => provider.clearApiKeys(),
                      child: const Text(
                        'Xóa tất cả',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: keys.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final key = keys[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _obscure ? GeminiKeyRotator.maskKey(key) : key,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                              tooltip: 'Xóa key này',
                              onPressed: () => provider.removeApiKeyAt(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Thêm Key mới
              const Text(
                'Thêm Gemini API Key mới:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      obscureText: _obscure,
                      maxLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Nhập hoặc dán 1 hoặc nhiều keys (phân tách bởi dấu phẩy)...',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onSubmitted: (_) => _handleAddKeys(provider),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: () => _handleAddKeys(provider),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Mẹo: Bạn có thể thêm 2-3 keys miễn phí từ Google AI Studio (aistudio.google.com). Hệ thống sẽ tự động xoay vòng qua từng key và tự động chuyển key khác nếu chạm giới hạn Rate Limit (15 RPM).',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
