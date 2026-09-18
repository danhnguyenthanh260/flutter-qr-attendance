import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../providers/session_provider.dart';

class QrDisplayView extends StatefulWidget {
  final VoidCallback onBackToSelection;

  const QrDisplayView({
    super.key,
    required this.onBackToSelection,
  });

  @override
  State<QrDisplayView> createState() => _QrDisplayViewState();
}

class _QrDisplayViewState extends State<QrDisplayView>
    with WidgetsBindingObserver {
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SessionProvider>();
      if (provider.hasActiveSession && provider.currentTicket == null) {
        provider.startQrRotation();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Khi app được mở lại từ sleep hoặc minimize, kiểm tra hạn mã vé ngay lập tức
      context.read<SessionProvider>().checkTicketOnResume();
    }
  }

  void _showEndSessionDialog(SessionProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Kết thúc phiên điểm danh?'),
          ],
        ),
        content: const Text(
          'Khi kết thúc, hệ thống sẽ dừng phát mã QR và tiến hành chốt danh sách điểm danh cho buổi học này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy bỏ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await provider.closeSession();
              if (!mounted) return;
              if (success) {
                widget.onBackToSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text('Đã đóng phiên điểm danh thành công!'),
                  ),
                );
              }
            },
            child: const Text('Đóng phiên'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final session = provider.activeSession;
    final ticket = provider.currentTicket;
    final countdown = provider.countdownSeconds;

    if (session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chưa có phiên điểm danh nào đang mở.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onBackToSelection,
              child: const Text('Quay lại chọn lớp'),
            ),
          ],
        ),
      );
    }

    final timeFormat = DateFormat('HH:mm:ss');
    final progress = (countdown / 30.0).clamp(0.0, 1.0);
    final timerColor = countdown > 10
        ? AppColors.success
        : (countdown > 5 ? AppColors.warning : AppColors.error);

    return Container(
      color: _isFullscreen ? Colors.white : AppColors.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(_isFullscreen ? 32 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Action Bar
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: widget.onBackToSelection,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Quay lại quản lý phiên'),
                    ),
                    const Spacer(),
                    // Manual Refresh Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: provider.refreshQrTicketNow,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Đổi mã mới ngay'),
                    ),
                    const SizedBox(width: 12),
                    // Fullscreen Toggle Button
                    IconButton.filledTonal(
                      tooltip: _isFullscreen ? 'Thu nhỏ' : 'Toàn màn hình máy chiếu',
                      onPressed: () => setState(() => _isFullscreen = !_isFullscreen),
                      icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                    ),
                    const SizedBox(width: 12),
                    // Close Session Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => _showEndSessionDialog(provider),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Kết thúc điểm danh'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Offline Alert Warning (if network lost)
                if (provider.isOffline) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: AppColors.error),
                        SizedBox(width: 12),
                        Text(
                          'Mất kết nối mạng! Mã QR tạm ẩn để tránh sinh viên quét mã quá hạn.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Main Presentation Card
                Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Class & Slot Header
                      Text(
                        session.className,
                        style: AppTypography.heading1.copyWith(
                          fontSize: _isFullscreen ? 32 : 26,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ca ${session.slot.slotNumber} (${session.slot.timeRange}) • Mở lúc: ${timeFormat.format(session.openedAt)}',
                        style: AppTypography.bodySecondary.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 24),

                      // Countdown Timer & Generation Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  ticket != null ? 'Mã đợt #${ticket.generation}' : 'Đang tải...',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: timerColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: timerColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 2.5,
                                    color: timerColor,
                                    backgroundColor: timerColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Đổi mã sau: ${countdown}s',
                                  style: TextStyle(
                                    color: timerColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // QR Code Container
                      if (provider.isOffline)
                        Container(
                          width: _isFullscreen ? 360 : 300,
                          height: _isFullscreen ? 360 : 300,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                                SizedBox(height: 12),
                                Text(
                                  'Đang thử kết nối lại...',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (ticket != null)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: ticket.formUrl,
                            version: QrVersions.auto,
                            size: _isFullscreen ? 340 : 280,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            backgroundColor: Colors.white,
                          ),
                        )
                      else
                        const SizedBox(
                          width: 280,
                          height: 280,
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      const SizedBox(height: 24),

                      // Instructions for Students
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.primary),
                            SizedBox(width: 10),
                            Text(
                              'Sinh viên mở camera điện thoại quét mã QR để vào Google Form điểm danh',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Mã tự động làm mới mỗi 30 giây • Các form đã mở trước đó vẫn nộp hợp lệ trong hạn cho phép (Grace Period)',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
