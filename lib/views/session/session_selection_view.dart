import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/debouncer.dart';
import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../providers/session_provider.dart';

class SessionSelectionView extends StatefulWidget {
  const SessionSelectionView({super.key});

  @override
  State<SessionSelectionView> createState() => _SessionSelectionViewState();
}

class _SessionSelectionViewState extends State<SessionSelectionView> {
  final Debouncer _debouncer = Debouncer(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SessionProvider>();
      if (provider.classes.isEmpty) {
        provider.loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _handleStartSession(SessionProvider provider) {
    _debouncer.run(() async {
      final success = await provider.startSession();
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã mở phiên điểm danh thành công!'),
              ],
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text(
                  'Đang tải thông tin lớp học...',
                  style: AppTypography.bodySecondary,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error banner if any
              if (provider.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.error),
                        onPressed: provider.clearError,
                      ),
                    ],
                  ),
                ),
              ],

              // Active Session Banner (if session is running)
              if (provider.hasActiveSession) ...[
                _buildActiveSessionBanner(provider.activeSession!),
                const SizedBox(height: 28),
              ],

              // Main Session Setup Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Form Column
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Khởi tạo phiên điểm danh',
                            style: AppTypography.heading2,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Chọn lớp học và ca học hôm nay để bắt đầu tiến trình điểm danh.',
                            style: AppTypography.bodySecondary,
                          ),
                          const SizedBox(height: 24),

                          // Step 1: Chọn lớp học
                          const Text(
                            '1. Chọn lớp học / Môn giảng dạy',
                            style: AppTypography.heading3,
                          ),
                          const SizedBox(height: 10),
                          _buildClassDropdown(provider),

                          const SizedBox(height: 24),

                          // Step 2: Chọn Ca học
                          const Text(
                            '2. Chọn ca học (Slot)',
                            style: AppTypography.heading3,
                          ),
                          const SizedBox(height: 10),
                          _buildSlotSelector(provider),

                          const SizedBox(height: 32),

                          // Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: (provider.isStartingSession || provider.hasActiveSession)
                                  ? null
                                  : () => _handleStartSession(provider),
                              icon: provider.isStartingSession
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.play_arrow_rounded, size: 22),
                              label: Text(
                                provider.isStartingSession
                                    ? 'Đang khởi tạo phiên...'
                                    : (provider.hasActiveSession
                                        ? 'Phiên đang diễn ra'
                                        : 'Bắt đầu phiên điểm danh'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Info & Summary Card
                  Expanded(
                    flex: 2,
                    child: _buildSummaryCard(provider),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassDropdown(SessionProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClassModel>(
          isExpanded: true,
          value: provider.selectedClass,
          hint: const Text('Chọn một lớp học'),
          items: provider.classes.map((c) {
            return DropdownMenuItem<ClassModel>(
              value: c,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c.courseCode,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${c.name} (${c.id.split('_').last})',
                      style: AppTypography.bodyRegular,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${c.totalStudents} SV',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: provider.hasActiveSession
              ? null
              : (newClass) => provider.selectClass(newClass),
        ),
      ),
    );
  }

  Widget _buildSlotSelector(SessionProvider provider) {
    if (provider.slots.isEmpty) {
      return const Text(
        'Vui lòng chọn lớp học để xem ca học',
        style: AppTypography.caption,
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: provider.slots.map((slot) {
        final isSelected = provider.selectedSlot == slot;
        return InkWell(
          onTap: provider.hasActiveSession
              ? null
              : () => provider.selectSlot(slot),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ca ${slot.slotNumber}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  slot.timeRange,
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard(SessionProvider provider) {
    final selectedClass = provider.selectedClass;
    final selectedSlot = provider.selectedSlot;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin ca giảng dạy',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          if (selectedClass != null) ...[
            _buildInfoRow(
              icon: Icons.menu_book_outlined,
              label: 'Môn học:',
              value: '${selectedClass.courseCode} - ${selectedClass.name}',
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.groups_outlined,
              label: 'Sĩ số danh sách lớp:',
              value: '${selectedClass.totalStudents} sinh viên (Roster)',
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Phòng học:',
              value: selectedClass.room,
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.event_note_outlined,
              label: 'Lịch học phân công:',
              value: selectedClass.scheduleDescription,
            ),
          ] else ...[
            const Center(
              child: Text(
                'Chưa chọn lớp học',
                style: AppTypography.bodySecondary,
              ),
            ),
          ],

          if (selectedSlot != null) ...[
            const SizedBox(height: 14),
            _buildInfoRow(
              icon: Icons.access_time_rounded,
              label: 'Khung giờ ca:',
              value: 'Ca ${selectedSlot.slotNumber} (${selectedSlot.timeRange})',
            ),
          ],

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Khi bấm "Bắt đầu phiên", mã QR sẽ tự động được sinh và xoay vòng mỗi 30 giây (chuẩn bị cho Issue #10).',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionBanner(AttendanceSession session) {
    final timeFormat = DateFormat('HH:mm:ss');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'PHIÊN ĐIỂM DANH ĐANG HOẠT ĐỘNG',
                      style: TextStyle(
                        color: Color(0xFF065F46), // Emerald 800
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.id,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.className} • Ca ${session.slot.slotNumber} (${session.slot.timeRange}) • Mở lúc: ${timeFormat.format(session.openedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF047857), // Emerald 700
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chuyển tới trình chiếu QR (Sẽ hoàn thiện ở Issue #10)'),
                ),
              );
            },
            icon: const Icon(Icons.qr_code, size: 18),
            label: const Text('Xem mã QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.bodySecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodyRegular.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
