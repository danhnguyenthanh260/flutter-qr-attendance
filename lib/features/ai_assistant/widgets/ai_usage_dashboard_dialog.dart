import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/ai_usage_record.dart';
import '../../../data/services/gemini_key_rotator.dart';
import '../ai_assistant_provider.dart';

/// Modal dialog providing comprehensive metrics on AI usage, token consumption,
/// estimated costs (USD/VND), and Gemini API Key pool health diagnostics.
class AiUsageDashboardDialog extends StatefulWidget {
  const AiUsageDashboardDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const AiUsageDashboardDialog(),
    );
  }

  @override
  State<AiUsageDashboardDialog> createState() => _AiUsageDashboardDialogState();
}

class _AiUsageDashboardDialogState extends State<AiUsageDashboardDialog> {
  String _selectedFilter = 'all'; // 'all', 'chat', 'report'

  Future<void> _handleConfirmClear(AiAssistantProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 10),
            Text('Xác nhận đặt lại thống kê'),
          ],
        ),
        content: const Text(
          'Thao tác này sẽ xóa toàn bộ lịch sử ghi nhận lượt gọi, '
          'lượng token tiêu thụ và chi phí ước tính được lưu trữ cục bộ. '
          'Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Xóa lịch sử'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await provider.usageTracker.clearHistory();
      if (mounted) {
        setState(() {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã làm mới và xóa toàn bộ lịch sử thống kê AI.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final tracker = provider.usageTracker;

    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final rotator = provider.rotator;
        final summary = tracker.getSummary();
        final keyStatuses = rotator.getKeyStatuses();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920, maxHeight: 740),
            child: Column(
              children: [
                // 1. Header Toolbar
                _buildHeader(context, provider),

                // 2. Main Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A. 4 Key Summary Metric Cards
                        _buildSummaryCards(summary),
                        const SizedBox(height: 20),

                        // B. Key Pool Diagnostics Section
                        _buildKeyPoolSection(rotator, keyStatuses),
                        const SizedBox(height: 20),

                        // C. Recent Invocations Log Table
                        _buildRecentInvocationsSection(summary),
                      ],
                    ),
                  ),
                ),

                // 3. Footer Actions
                _buildFooter(context, provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AiAssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giám sát AI & Kiểm soát Chi phí',
                  style: AppTypography.heading2,
                ),
                SizedBox(height: 2),
                Text(
                  'Google Gemini 2.5 Flash • Định mức: \$0.075 / 1M prompt • \$0.30 / 1M output',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AiUsageSummary summary) {
    final numberFormat = NumberFormat('#,###');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 780;
        final cardWidth = isCompact
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Card 1: Total Requests
            _buildMetricCard(
              width: cardWidth,
              title: 'Tổng số yêu cầu',
              primaryValue: '${summary.totalRequests}',
              secondaryText: summary.totalRequests > 0
                  ? '${summary.successRatePercent.toStringAsFixed(1)}% thành công (${summary.successfulRequests}/${summary.totalRequests})'
                  : 'Chưa có yêu cầu nào',
              icon: Icons.sync_alt_rounded,
              accentColor: const Color(0xFF2563EB),
              tintBg: const Color(0xFFEFF6FF),
            ),

            // Card 2: Total Tokens
            _buildMetricCard(
              width: cardWidth,
              title: 'Lượng Token',
              primaryValue: numberFormat.format(summary.totalTokens),
              secondaryText:
                  '${numberFormat.format(summary.totalPromptTokens)} in • ${numberFormat.format(summary.totalCandidatesTokens)} out',
              icon: Icons.generating_tokens_outlined,
              accentColor: const Color(0xFFD97706),
              tintBg: const Color(0xFFFFFBEB),
            ),

            // Card 3: Estimated Cost
            _buildMetricCard(
              width: cardWidth,
              title: 'Chi phí ước tính',
              primaryValue: summary.formattedCostUsd,
              secondaryText: '~${summary.formattedCostVnd} (quy đổi)',
              icon: Icons.monetization_on_outlined,
              accentColor: const Color(0xFF059669),
              tintBg: const Color(0xFFECFDF5),
            ),

            // Card 4: Average Latency
            _buildMetricCard(
              width: cardWidth,
              title: 'Độ trễ trung bình',
              primaryValue: summary.totalRequests > 0
                  ? '${(summary.averageLatencyMs / 1000).toStringAsFixed(2)}s'
                  : '0.00s',
              secondaryText: summary.totalRequests > 0
                  ? '${summary.averageLatencyMs.round()} ms / lượt'
                  : 'N/A',
              icon: Icons.timer_outlined,
              accentColor: const Color(0xFF7C3AED),
              tintBg: const Color(0xFFF5F3FF),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String primaryValue,
    required String secondaryText,
    required IconData icon,
    required Color accentColor,
    required Color tintBg,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tintBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            primaryValue,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondaryText,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPoolSection(
    GeminiKeyRotator rotator,
    List<KeyStatusInfo> keyStatuses,
  ) {
    final activeCount = rotator.activeKeyCount;
    final totalCount = rotator.keyCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tình trạng Pool API Keys ($activeCount/$totalCount khả dụng)',
                  style: AppTypography.heading3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (totalCount > 0) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    rotator.resetKeyHealth();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã khôi phục trạng thái sức khỏe cho tất cả API keys.',
                        ),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text(
                    'Khôi phục sức khỏe Keys',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (keyStatuses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chưa có API key nào trong danh sách. Hệ thống đang sử dụng '
                      'Chế độ Phân tích Nội suy Cục bộ (Local Analytical Engine - hoàn toàn miễn phí).',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: keyStatuses.map((info) => _buildKeyCard(info)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyCard(KeyStatusInfo info) {
    Color badgeBg;
    Color badgeTextColor;
    IconData statusIcon;

    switch (info.status) {
      case KeyHealthStatus.active:
        badgeBg = const Color(0xFFECFDF5);
        badgeTextColor = const Color(0xFF166534);
        statusIcon = Icons.check_circle_outline;
        break;
      case KeyHealthStatus.rateLimited:
        badgeBg = const Color(0xFFFFFBEB);
        badgeTextColor = const Color(0xFF92400E);
        statusIcon = Icons.warning_amber_rounded;
        break;
      case KeyHealthStatus.invalid:
        badgeBg = const Color(0xFFFEF2F2);
        badgeTextColor = const Color(0xFF991B1B);
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    final timeStr = info.lastUsedAt != null
        ? DateFormat('HH:mm:ss').format(info.lastUsedAt!)
        : 'Chưa dùng';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: info.status == KeyHealthStatus.active
              ? AppColors.border
              : badgeTextColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Key #${info.index + 1}: ${info.maskedKey}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: badgeTextColor),
                    const SizedBox(width: 4),
                    Text(
                      info.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '✓ ${info.successCount} thành công  •  ✕ ${info.failureCount} lỗi  •  $timeStr',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (info.lastError != null &&
              info.status != KeyHealthStatus.active) ...[
            const SizedBox(height: 4),
            Text(
              'Lỗi: ${info.lastError}',
              style: TextStyle(
                fontSize: 10.5,
                color: badgeTextColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentInvocationsSection(AiUsageSummary summary) {
    final filtered = summary.recentRecords.where((r) {
      if (_selectedFilter == 'chat') return r.operation == 'chat';
      if (_selectedFilter == 'report') return r.operation == 'report';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Lịch sử 20 lượt gọi gần nhất',
                  style: AppTypography.heading3,
                ),
              ],
            ),
            // Filter segmented buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterChip(
                  'all',
                  'Tất cả (${summary.recentRecords.length})',
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'chat',
                  'Chat (${summary.recentRecords.where((r) => r.operation == 'chat').length})',
                ),
                const SizedBox(width: 6),
                _buildFilterChip(
                  'report',
                  'Báo cáo (${summary.recentRecords.where((r) => r.operation == 'report').length})',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Chưa có dữ liệu gọi AI nào',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Mỗi khi Thầy/Cô trò chuyện hoặc tạo báo cáo chuyên cần, '
                  'lượng token, độ trễ và chi phí tương ứng sẽ tự động hiển thị ở đây.',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final r = filtered[index];
                return _buildRecordRow(r);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordRow(AiUsageRecord record) {
    final isReport = record.operation == 'report';
    final timeStr = DateFormat('HH:mm:ss dd/MM').format(record.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Operation icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isReport
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isReport ? Icons.description_outlined : Icons.chat_bubble_outline,
              size: 16,
              color: isReport
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF16A34A),
            ),
          ),
          const SizedBox(width: 12),

          // Operation and model description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      isReport ? 'Tạo Báo cáo' : 'Trò chuyện AI',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        record.model,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '•  Key: ${record.keyMasked}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  record.isSuccess
                      ? 'Tokens: ${record.promptTokens} in + ${record.candidatesTokens} out = ${record.totalTokens} tổng'
                      : 'Lỗi: ${record.errorMessage ?? "Yêu cầu thất bại"}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: record.isSuccess
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),

          // Latency & Cost
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${record.estimatedCostUsd.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: record.isSuccess
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      record.isSuccess
                          ? '✓ ${record.latencyMs}ms'
                          : '✕ Thất bại',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: record.isSuccess
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AiAssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: Color(0xFFFECACA)),
              backgroundColor: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => _handleConfirmClear(provider),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text(
              'Xóa lịch sử thống kê',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
