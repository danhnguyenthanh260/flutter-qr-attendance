import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/ai_usage_record.dart';
import '../../../data/services/gemini_key_rotator.dart';
import '../ai_assistant_provider.dart';
import 'ai_settings_dialog.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'chat', 'report'
  String _statusFilter = 'all'; // 'all', 'success', 'failure'
  String _sortBy = 'newest'; // 'newest', 'oldest', 'tokens_desc', 'latency_desc', 'cost_desc'
  int _displayLimit = 20;
  final Set<String> _expandedRecordIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        setState(() {
          _expandedRecordIds.clear();
        });
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

  void _handleCopySummary(AiUsageSummary summary) {
    final buffer = StringBuffer();
    buffer.writeln('=== BÁO CÁO GIÁM SÁT MỨC SỬ DỤNG AI & CHI PHÍ ===');
    buffer.writeln('Mô hình: Google Gemini 2.5 Flash');
    buffer.writeln('Tổng số yêu cầu: ${summary.totalRequests} lượt (${summary.successRatePercent.toStringAsFixed(1)}% thành công)');
    buffer.writeln('- Thành công: ${summary.successfulRequests}');
    buffer.writeln('- Lỗi/Thất bại: ${summary.failedRequests}');
    buffer.writeln('Tổng lượng Tokens: ${NumberFormat('#,###').format(summary.totalTokens)}');
    buffer.writeln('- Prompt (Input): ${NumberFormat('#,###').format(summary.totalPromptTokens)}');
    buffer.writeln('- Candidate (Output): ${NumberFormat('#,###').format(summary.totalCandidatesTokens)}');
    buffer.writeln('Chi phí ước tính: ${summary.formattedCostUsd} (~${summary.formattedCostVnd})');
    buffer.writeln('Độ trễ trung bình: ${(summary.averageLatencyMs / 1000.0).toStringAsFixed(2)}s (${summary.averageLatencyMs.round()} ms/lượt)');
    buffer.writeln('Thời gian xuất: ${DateFormat('HH:mm:ss dd/MM/yyyy').format(DateTime.now())}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép tóm tắt thống kê AI vào bộ nhớ tạm!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
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
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 780),
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

                        // C. Recent Invocations Log Table with Search, Filter & Sort
                        _buildRecentInvocationsSection(summary),
                      ],
                    ),
                  ),
                ),

                // 3. Footer Actions
                _buildFooter(context, provider, summary),
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
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AiUsageSummary summary) {
    final hasData = summary.totalRequests > 0;
    final tokenFormatted = NumberFormat('#,###').format(summary.totalTokens);
    final latencySec = (summary.averageLatencyMs / 1000.0).toStringAsFixed(2);
    final successRate = summary.successRatePercent;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - (3 * 14)) / 4;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            // Card 1: Total Requests
            _buildMetricCard(
              width: cardWidth,
              title: 'Tổng số yêu cầu',
              value: hasData ? '${summary.totalRequests}' : '0',
              subtitle: hasData
                  ? '${successRate.toStringAsFixed(1)}% thành công (${summary.successfulRequests}/${summary.totalRequests})'
                  : 'Chưa có yêu cầu nào',
              icon: Icons.sync_alt_rounded,
              iconColor: AppColors.primary,
              iconBg: const Color(0xFFEFF6FF),
              progressValue: hasData ? (summary.successfulRequests / summary.totalRequests) : null,
            ),

            // Card 2: Token Usage
            _buildMetricCard(
              width: cardWidth,
              title: 'Lượng Token',
              value: hasData ? tokenFormatted : '0',
              subtitle: hasData
                  ? '${summary.totalPromptTokens} in • ${summary.totalCandidatesTokens} out'
                  : '0 prompt • 0 candidates',
              icon: Icons.toll_outlined,
              iconColor: const Color(0xFFD97706),
              iconBg: const Color(0xFFFEF3C7),
            ),

            // Card 3: Estimated Cost
            _buildMetricCard(
              width: cardWidth,
              title: 'Chi phí ước tính',
              value: hasData ? summary.formattedCostUsd : '\$0.0000',
              subtitle: hasData
                  ? '~${summary.formattedCostVnd} (quy đổi)'
                  : '~0 ₫ (Gemini 2.5)',
              icon: Icons.attach_money_rounded,
              iconColor: AppColors.success,
              iconBg: const Color(0xFFDCFCE7),
            ),

            // Card 4: Average Latency
            _buildMetricCard(
              width: cardWidth,
              title: 'Độ trễ trung bình',
              value: hasData ? '${latencySec}s' : '0.00s',
              subtitle: hasData
                  ? '${summary.averageLatencyMs.round()} ms / lượt'
                  : '0 ms / lượt',
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFF7C3AED),
              iconBg: const Color(0xFFF3E8FF),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    double? progressValue,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(18),
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
              // Shortcut to open API settings directly
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => AiSettingsDialog.show(context),
                icon: const Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
                label: const Text(
                  'Cấu hình Keys',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ),
              if (totalCount > 0) ...[
                const SizedBox(width: 6),
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
    final allItems = summary.allRecords.isNotEmpty ? summary.allRecords : summary.recentRecords;

    // Filter pipeline
    final filtered = allItems.where((r) {
      // 1. Operation filter
      if (_selectedFilter == 'chat' && r.operation != 'chat') return false;
      if (_selectedFilter == 'report' && r.operation != 'report') return false;

      // 2. Status filter
      if (_statusFilter == 'success' && !r.isSuccess) return false;
      if (_statusFilter == 'failure' && r.isSuccess) return false;

      // 3. Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchModel = r.model.toLowerCase().contains(q);
        final matchKey = r.keyMasked.toLowerCase().contains(q);
        final matchErr = (r.errorMessage ?? '').toLowerCase().contains(q);
        final matchOp = (r.operation == 'chat' ? 'trò chuyện chat' : 'tạo báo cáo report').contains(q);
        final matchTokens = '${r.totalTokens}'.contains(q);
        final matchLatency = '${r.latencyMs}'.contains(q);
        if (!matchModel && !matchKey && !matchErr && !matchOp && !matchTokens && !matchLatency) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort pipeline
    switch (_sortBy) {
      case 'newest':
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'tokens_desc':
        filtered.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
        break;
      case 'latency_desc':
        filtered.sort((a, b) => b.latencyMs.compareTo(a.latencyMs));
        break;
      case 'cost_desc':
        filtered.sort((a, b) => b.estimatedCostUsd.compareTo(a.estimatedCostUsd));
        break;
    }

    final totalFiltered = filtered.length;
    final displayedRecords = filtered.take(_displayLimit).toList();
    final hasMore = totalFiltered > _displayLimit;

    final chatCount = allItems.where((r) => r.operation == 'chat').length;
    final reportCount = allItems.where((r) => r.operation == 'report').length;
    final successCount = allItems.where((r) => r.isSuccess).length;
    final failCount = allItems.where((r) => !r.isSuccess).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lịch sử 20 lượt gọi gần nhất',
                  style: AppTypography.heading3,
                ),
              ],
            ),
            if (filtered.isNotEmpty)
              Text(
                'Hiển thị ${displayedRecords.length} / $totalFiltered kết quả',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Search Bar
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm theo Model, API Key, mã lỗi (429, quota, invalid)...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 10),

        // Filter and Sort Toolbar
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Left: Operation & Status Filters
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Operation Filters
                _buildFilterChip('all', 'Tất cả (${allItems.length})'),
                _buildFilterChip('chat', 'Chat ($chatCount)'),
                _buildFilterChip('report', 'Báo cáo ($reportCount)'),

                Container(
                  width: 1,
                  height: 18,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),

                // Status Filters
                _buildStatusFilterChip('all', 'Tất cả'),
                _buildStatusFilterChip('success', '✓ Thành công ($successCount)'),
                _buildStatusFilterChip('failure', '✕ Lỗi ($failCount)'),
              ],
            ),

            // Right: Sort Dropdown
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  icon: const Icon(Icons.sort_rounded, size: 16, color: AppColors.primary),
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('⏱️ Mới nhất')),
                    DropdownMenuItem(value: 'oldest', child: Text('⏳ Cũ nhất')),
                    DropdownMenuItem(value: 'tokens_desc', child: Text('🪙 Token nhiều nhất')),
                    DropdownMenuItem(value: 'latency_desc', child: Text('⚡ Độ trễ cao nhất')),
                    DropdownMenuItem(value: 'cost_desc', child: Text('💵 Chi phí cao nhất')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _sortBy = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Record List / Empty States
        if (allItems.isEmpty)
          _buildEmptyHistoryState()
        else if (displayedRecords.isEmpty)
          _buildNoMatchingFilterState()
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
              itemCount: displayedRecords.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final r = displayedRecords[index];
                return _buildRecordRow(r);
              },
            ),
          ),

        // Load More button
        if (hasMore) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _displayLimit += 20;
                });
              },
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                'Xem thêm 20 lượt (còn ${totalFiltered - displayedRecords.length} lượt)',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyHistoryState() {
    return Container(
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
    );
  }

  Widget _buildNoMatchingFilterState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.filter_list_off_rounded,
            size: 36,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 8),
          const Text(
            'Không tìm thấy bản ghi nào phù hợp',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thử thay đổi từ khóa tìm kiếm hoặc điều chỉnh lại các bộ lọc ở trên.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'all';
                _statusFilter = 'all';
              });
            },
            child: const Text('Đặt lại bộ lọc', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
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

  Widget _buildStatusFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    Color activeBg = AppColors.primary;
    if (key == 'success') activeBg = const Color(0xFF166534);
    if (key == 'failure') activeBg = AppColors.error;

    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : const Color(0xFFF1F5F9),
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
    final isExpanded = _expandedRecordIds.contains(record.id);

    return InkWell(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedRecordIds.remove(record.id);
          } else {
            _expandedRecordIds.add(record.id);
          }
        });
      },
      child: Container(
        color: isExpanded ? const Color(0xFFF8FAFC) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
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
                        maxLines: isExpanded ? null : 1,
                        overflow: isExpanded ? null : TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Latency & Cost & Expand indicator
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Expanded Detail View
            if (isExpanded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết bản ghi tương tác:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• Thời gian chính xác: ${DateFormat('HH:mm:ss.SSS - dd/MM/yyyy').format(record.timestamp)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '• Mã ID: ${record.id}',
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '• Prompt Token: ${record.promptTokens}  |  Candidate Token: ${record.candidatesTokens}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '• Chi phí quy đổi VND: ~${(record.estimatedCostUsd * 25400).toStringAsFixed(2)} ₫',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    if (record.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SelectableText(
                                record.errorMessage!,
                                style: const TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: AppColors.error),
                              tooltip: 'Sao chép thông báo lỗi',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: record.errorMessage!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép nội dung lỗi.'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(
    BuildContext context,
    AiAssistantProvider provider,
    AiUsageSummary summary,
  ) {
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
          const SizedBox(width: 10),
          if (summary.totalRequests > 0)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => _handleCopySummary(summary),
              icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
              label: const Text(
                'Sao chép tóm tắt',
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
