import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/ui/notice_card.dart';
import '../../data/models/class_model.dart';
import '../qr/qr_display_view.dart';
import 'session_provider.dart';

class SessionSelectionView extends StatefulWidget {
  const SessionSelectionView({super.key});
  @override
  State<SessionSelectionView> createState() => _SessionSelectionViewState();
}

class _SessionSelectionViewState extends State<SessionSelectionView> {
  bool _showQrScreen = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<SessionProvider>();
      if (provider.classes.isEmpty) unawaited(provider.loadInitialData());
    });
  }

  Future<void> _start(SessionProvider provider) async {
    final success = await provider.startSession();
    if (mounted && success) setState(() => _showQrScreen = true);
  }

  @override
  Widget build(BuildContext context) => Consumer<SessionProvider>(
    builder: (context, provider, _) {
      if (provider.hasActiveSession && _showQrScreen) {
        return QrDisplayView(
          onBackToSelection: () => setState(() => _showQrScreen = false),
        );
      }
      final selected = provider.selectedClass;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Khởi tạo phiên điểm danh',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  TextButton.icon(
                    onPressed: provider.isLoading || provider.isRestoringSession
                        ? null
                        : provider.loadInitialData,
                    icon: const Icon(AppIcons.refresh),
                    label: const Text('Kiểm tra lại phiên'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Chọn lớp và ca học. Mã QR sẽ xuất hiện sau khi máy chủ xác nhận mở phiên.',
              ),
              const SizedBox(height: 24),
              if (provider.isLoading || provider.isRestoringSession) ...[
                NoticeCard(
                  kind: NoticeKind.loading,
                  message: provider.isLoading
                      ? 'Đang tải danh sách lớp. Bạn vẫn có thể mở các mục khác.'
                      : 'Đã có danh sách lớp. Đang xác minh phiên trên máy chủ…',
                ),
                const SizedBox(height: 16),
              ],
              if (provider.errorMessage != null) ...[
                NoticeCard(
                  kind: NoticeKind.error,
                  message: provider.errorMessage!,
                  onDismiss: provider.clearError,
                ),
                const SizedBox(height: 16),
              ],
              if (provider.hasActiveSession) ...[
                Card.filled(
                  color: AppColors.primaryLight,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Phiên đang mở · ${provider.activeSession!.className} · Ca ${provider.activeSession!.slot.slotNumber}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        FilledButton.icon(
                          onPressed: () => setState(() => _showQrScreen = true),
                          icon: const Icon(AppIcons.session),
                          label: const Text('Xem mã QR'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Card.outlined(
                margin: EdgeInsets.zero,
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Lớp học / Môn giảng dạy',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ClassModel>(
                        key: ValueKey(selected?.id),
                        initialValue: selected,
                        isExpanded: true,
                        hint: const Text('Chọn một lớp học'),
                        items: provider.classes
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  '${item.courseCode} · ${item.name} (${item.id})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: provider.hasActiveSession
                            ? null
                            : provider.selectClass,
                      ),
                      if (selected != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            Text(
                              '${selected.totalStudents} sinh viên trong danh sách',
                            ),
                            if (selected.room.isNotEmpty)
                              Text('Phòng ${selected.room}'),
                          ],
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        '2. Ca học',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (provider.isLoadingSlots)
                        const LinearProgressIndicator()
                      else if (provider.slots.isEmpty)
                        const NoticeCard(
                          kind: NoticeKind.empty,
                          message: 'Chưa có ca học. Chọn lớp hoặc kiểm tra lại dữ liệu.',
                        )
                      else
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final slot in provider.slots)
                              ChoiceChip(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                label: Text(
                                  'Ca ${slot.slotNumber} · ${slot.timeRange}',
                                ),
                                selected: provider.selectedSlot == slot,
                                onSelected: provider.hasActiveSession
                                    ? null
                                    : (_) => provider.selectSlot(slot),
                              ),
                          ],
                        ),
                      const SizedBox(height: 28),
                      const Divider(),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                provider.isStartingSession ||
                                    provider.hasActiveSession ||
                                    !provider.canStartSession
                                ? null
                                : () => _start(provider),
                            icon: const Icon(AppIcons.session),
                            label: Text(
                              provider.isStartingSession
                                  ? 'Đang mở phiên…'
                                  : 'Bắt đầu phiên điểm danh',
                            ),
                          ),
                          const Text('Mỗi lần chỉ mở một phiên điểm danh.'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
