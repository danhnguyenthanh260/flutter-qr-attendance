import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/qr_ticket_model.dart';
import '../../data/models/session_model.dart';
import '../teaching/session_provider.dart';
import 'qr_controller.dart';

class QrDisplayView extends StatefulWidget {
  final VoidCallback onBackToSelection;

  const QrDisplayView({super.key, required this.onBackToSelection});

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
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isClosing = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  SizedBox(width: 10),
                  Text('Kết thúc phiên điểm danh?'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khi kết thúc, hệ thống sẽ dừng phát mã QR ngay lập tức và gửi yêu cầu chốt danh sách điểm danh lên máy chủ.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Lưu ý: Hệ thống sẽ đợi máy chủ xác nhận xử lý các form đang nộp dở, không chốt vắng sớm.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isClosing) ...[
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        SizedBox(width: 12),
                        Text('Đang chốt phiên trên máy chủ...'),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isClosing ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy bỏ'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isClosing
                      ? null
                      : () async {
                          setDialogState(() => isClosing = true);
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(this.context);
                          final sessionSnapshot = provider.activeSession;
                          final success = await provider.closeSession();
                          if (!mounted) return;
                          nav.pop();

                          if (success) {
                            widget.onBackToSelection();
                            if (sessionSnapshot != null) {
                              _showSessionSummaryDialog(sessionSnapshot);
                            }
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.error,
                                content: Text(
                                  provider.errorMessage ??
                                      'Không thể đóng phiên. Vui lòng thử lại.',
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(isClosing ? 'Đang xử lý...' : 'Đóng phiên ngay'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSessionSummaryDialog(AttendanceSession session) {
    final timeFormat = DateFormat('HH:mm:ss');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 10),
            Text('Đã chốt phiên thành công!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phiên điểm danh cho lớp ${session.className} đã hoàn tất và lưu trữ an toàn.',
              style: AppTypography.bodyRegular,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mã phiên: ${session.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('Thời gian mở: ${timeFormat.format(session.openedAt)}'),
                  const SizedBox(height: 4),
                  Text('Thời gian đóng: ${timeFormat.format(DateTime.now())}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '👉 Bạn có thể chuyển sang tab "Bảng điểm danh" (Người 2) để xem danh sách sinh viên có mặt và vắng đã chốt.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final session = provider.activeSession;
    if (session == null) {
      return const Center(child: Text('Chưa có phiên điểm danh nào đang mở.'));
    }
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onBackToSelection,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại quản lý phiên'),
                ),
                OutlinedButton.icon(
                  onPressed: provider.isClosingSession
                      ? null
                      : provider.refreshQrTicketNow,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Đổi mã mới ngay'),
                ),
                IconButton.filledTonal(
                  tooltip: _isFullscreen ? 'Thu nhỏ mã QR' : 'Phóng to mã QR',
                  onPressed: () =>
                      setState(() => _isFullscreen = !_isFullscreen),
                  icon: Icon(_isFullscreen ? Icons.zoom_out : Icons.zoom_in),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: provider.isClosingSession
                      ? null
                      : () => _showEndSessionDialog(provider),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Kết thúc điểm danh'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              session.className,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ca ${session.slot.slotNumber} · ${session.slot.timeRange} · Mở lúc ${DateFormat('HH:mm').format(session.openedAt)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ChangeNotifierProvider.value(
              value: provider.qr,
              child: Column(
                children: [
                  Selector<QrController, (String?, int, int?)>(
                    selector: (_, qr) => (
                      qr.errorMessage,
                      qr.countdownSeconds,
                      qr.currentTicket?.generation,
                    ),
                    builder: (context, state, _) => Column(
                      children: [
                        if (state.$1 != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              state.$1!,
                              style: const TextStyle(color: AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Text(
                          state.$3 == null
                              ? 'Chưa có mã QR hợp lệ'
                              : 'Mã đợt #${state.$3} · Còn ${state.$2}s',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Selector<QrController, (QrTicketModel?, bool)>(
                    selector: (_, qr) => (qr.currentTicket, qr.isRotating),
                    builder: (context, state, _) => LayoutBuilder(
                      builder: (context, constraints) {
                        final size = (_isFullscreen ? 440.0 : 300.0).clamp(
                          120.0,
                          (constraints.maxWidth - 32).clamp(120.0, 480.0),
                        );
                        final ticket = state.$1;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: ticket == null
                              ? SizedBox(
                                  width: size,
                                  height: size,
                                  child: Center(
                                    child: state.$2
                                        ? const CircularProgressIndicator()
                                        : const Text(
                                            'Đã dừng phát QR. Kiểm tra lại trạng thái phiên.',
                                            textAlign: TextAlign.center,
                                          ),
                                  ),
                                )
                              : RepaintBoundary(
                                  child: QrImageView(
                                    key: ValueKey(ticket.ticketCode),
                                    data: ticket.formUrl,
                                    size: size,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sinh viên quét mã QR và hoàn tất biểu mẫu điểm danh.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Mã hết hạn sẽ tự ẩn. Lượt quét chỉ được ghi nhận sau khi máy chủ xác nhận.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
