import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/ai_chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onOpenReportModal;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onOpenReportModal,
  });

  void _copyContent(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép nội dung vào Clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.sender == MessageSender.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.content,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }

    final isUser = message.sender == MessageSender.user;
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: message.isReport
                    ? const Color(0xFFFEF3C7)
                    : AppColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: message.isReport
                      ? const Color(0xFFFDE68A)
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                message.isReport ? Icons.description_outlined : Icons.support_agent_rounded,
                color: message.isReport ? const Color(0xFFD97706) : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (message.isReport ? const Color(0xFFFFFBEB) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.primary
                      : (message.isReport
                          ? const Color(0xFFFDE68A)
                          : AppColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isReport) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.article_outlined,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Báo cáo tổng hợp chuyên cần',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const Spacer(),
                        if (onOpenReportModal != null)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: onOpenReportModal,
                            icon: const Icon(Icons.open_in_full, size: 14),
                            label: const Text('Xem to', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    const Divider(height: 16),
                  ],
                  if (message.isLoading) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isUser ? Colors.white : AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textMuted,
                        ),
                      ),
                      if (!isUser && !message.isLoading) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyContent(context),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
