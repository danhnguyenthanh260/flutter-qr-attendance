import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/attendance_history_provider.dart';
import '../../providers/attendance_results_provider.dart';
import 'widgets/ai_settings_dialog.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/report_preview_dialog.dart';

class AiAssistantView extends StatefulWidget {
  const AiAssistantView({super.key});

  @override
  State<AiAssistantView> createState() => _AiAssistantViewState();
}

class _AiAssistantViewState extends State<AiAssistantView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _suggestedPrompts = const [
    'Sinh viên vắng gần 20% & nguy cơ cấm thi',
    'Danh sách sinh viên bị cấm thi (>20% slot)',
    'Sinh viên vắng hoặc chưa quét mã hôm nay',
    'Tỷ lệ chuyên cần lớp học',
    'Kiểm tra lượt quét trùng lặp',
    'Tóm tắt tình hình buổi học',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    _inputController.clear();

    final aiProvider = context.read<AiAssistantProvider>();
    final resultsProvider = context.read<AttendanceResultsProvider>();
    final historyProvider = context.read<AttendanceHistoryProvider>();

    final selectedClass = resultsProvider.selectedClass ?? historyProvider.selectedClass;

    _scrollToBottom();
    await aiProvider.sendMessage(
      query: query,
      currentSummary: resultsProvider.summary,
      history: historyProvider.groups,
      currentClass: selectedClass,
    );
    _scrollToBottom();
  }

  Future<void> _handleGenerateReport() async {
    final aiProvider = context.read<AiAssistantProvider>();
    final resultsProvider = context.read<AttendanceResultsProvider>();
    final historyProvider = context.read<AttendanceHistoryProvider>();

    final summary = resultsProvider.summary;
    if (summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc mở một phiên điểm danh ở tab "Bảng điểm danh" trước khi tạo báo cáo.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selectedClass = resultsProvider.selectedClass ?? historyProvider.selectedClass;

    _scrollToBottom();
    final report = await aiProvider.generateReport(
      summary: summary,
      history: historyProvider.groups,
      classModel: selectedClass,
    );
    _scrollToBottom();

    if (mounted && report != null) {
      ReportPreviewDialog.show(context, report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();
    final resultsProvider = context.watch<AttendanceResultsProvider>();
    final summary = resultsProvider.summary;

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // 1. Header Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(bottom: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insights_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Trợ lý Chuyên cần',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: aiProvider.hasApiKey
                                  ? AppColors.successBg
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              aiProvider.activeKeyStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: aiProvider.hasApiKey
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary != null
                            ? 'Dữ liệu đối chiếu: ${summary.scope.className} · Slot ${summary.scope.slotNumber} (${summary.presentCount}/${summary.totalStudents} có mặt)'
                            : 'Chưa chọn phiên cụ thể (đang đối chiếu dữ liệu chung)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: aiProvider.isGenerating ? null : _handleGenerateReport,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Tạo báo cáo chuyên cần'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onPressed: () => AiSettingsDialog.show(context),
                  icon: const Icon(Icons.tune_outlined, size: 16),
                  label: const Text('Cấu hình API'),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Xóa lịch sử chat',
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.textMuted),
                  onPressed: aiProvider.clearMessages,
                ),
              ],
            ),
          ),

          // 2. Chat Messages Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              itemCount: aiProvider.messages.length,
              itemBuilder: (context, index) {
                final message = aiProvider.messages[index];
                return ChatMessageBubble(
                  message: message,
                  onOpenReportModal: message.isReport
                      ? () => ReportPreviewDialog.show(context, message.content)
                      : null,
                );
              },
            ),
          ),

          // 3. Suggested Prompt Chips Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suggestedPrompts.map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      backgroundColor: const Color(0xFFF8FAFC),
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      label: Text(
                        prompt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onPressed: aiProvider.isGenerating
                          ? null
                          : () => _handleSend(prompt),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 4. Input Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Nhập câu hỏi tra cứu chuyên cần, sinh viên vắng, nguy cơ cấm thi...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (value) => _handleSend(value),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: aiProvider.isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    onPressed: aiProvider.isGenerating
                        ? null
                        : () => _handleSend(_inputController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
