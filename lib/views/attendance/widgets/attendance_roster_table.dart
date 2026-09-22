import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/attendance_labels.dart';
import '../../../data/models/attendance_summary.dart';
import 'attendance_chips.dart';

class AttendanceRosterTable extends StatefulWidget {
  final AttendanceSummary summary;

  const AttendanceRosterTable({super.key, required this.summary});

  @override
  State<AttendanceRosterTable> createState() => _AttendanceRosterTableState();
}

class _AttendanceRosterTableState extends State<AttendanceRosterTable> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  String _query = '';
  StudentAttendanceStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentAttendanceRow> get _visibleRows {
    final normalizedQuery = _query.trim().toLowerCase();
    return widget.summary.rows.where((row) {
      final matchesStatus = _statusFilter == null || row.status == _statusFilter;
      if (!matchesStatus) return false;
      if (normalizedQuery.isEmpty) return true;
      return row.student.displayName.toLowerCase().contains(normalizedQuery) ||
          row.student.email.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(rows.length),
          const Divider(height: 1, color: AppColors.border),
          _buildColumnTitles(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Không có sinh viên nào khớp bộ lọc hiện tại.',
                        style: AppTypography.bodySecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.borderSubtle),
                    itemBuilder: (context, index) =>
                        _buildRow(rows[index], index + 1),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int visibleCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text('Danh sách đối chiếu roster',
                  style: AppTypography.heading3),
              const SizedBox(width: 10),
              Text(
                '$visibleCount / ${widget.summary.totalStudents}',
                style: AppTypography.caption,
              ),
              const Spacer(),
              SizedBox(
                width: 240,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên hoặc email',
                    hintStyle: AppTypography.caption,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(null, 'Tất cả', widget.summary.totalStudents),
              _buildFilterChip(
                StudentAttendanceStatus.present,
                AttendanceLabels.studentStatus(StudentAttendanceStatus.present),
                widget.summary.presentCount,
              ),
              if (widget.summary.isFinalized)
                _buildFilterChip(
                  StudentAttendanceStatus.absent,
                  AttendanceLabels.studentStatus(StudentAttendanceStatus.absent),
                  widget.summary.absentCount,
                )
              else
                _buildFilterChip(
                  StudentAttendanceStatus.notYet,
                  AttendanceLabels.studentStatus(StudentAttendanceStatus.notYet),
                  widget.summary.notYetCount,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    StudentAttendanceStatus? status,
    String label,
    int count,
  ) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }

  Widget _buildColumnTitles() {
    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: const [
          SizedBox(width: 36, child: Text('#', style: AppTypography.caption)),
          Expanded(child: Text('Sinh viên', style: AppTypography.caption)),
          SizedBox(
            width: 160,
            child: Text('Trạng thái', style: AppTypography.caption),
          ),
          SizedBox(
            width: 120,
            child: Text('Ghi nhận lúc', style: AppTypography.caption),
          ),
          SizedBox(
            width: 92,
            child: Text('Nộp lại', style: AppTypography.caption),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(StudentAttendanceRow row, int ordinal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('$ordinal', style: AppTypography.caption),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.student.displayName,
                  style: AppTypography.bodyRegular.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  row.student.email,
                  style: AppTypography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 160,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StudentStatusChip(status: row.status),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              row.acceptedAt == null ? '—' : _timeFormat.format(row.acceptedAt!),
              style: AppTypography.bodySecondary,
            ),
          ),
          SizedBox(
            width: 92,
            child: row.attemptCount == 0
                ? const Text('—', style: AppTypography.caption)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AttendanceChip(
                      label: '${row.attemptCount}',
                      color: AppColors.info,
                      background: const Color(0xFFF0F9FF),
                      icon: Icons.replay_rounded,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
