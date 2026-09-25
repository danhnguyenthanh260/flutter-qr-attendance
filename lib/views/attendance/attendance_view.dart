import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/attendance_results_provider.dart';

import '../../core/constants/app_colors.dart';
import 'history_attendance_view.dart';
import 'today_attendance_view.dart';

class AttendanceView extends StatefulWidget {
  final bool active;
  const AttendanceView({super.key, this.active = true});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  final Set<int> _visitedTabs = {0};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant AttendanceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncVisibility();
  }

  void _syncVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AttendanceResultsProvider>().setVisible(
          widget.active && _selectedIndex == 0,
        );
      }
    });
  }

  void _select(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
    _syncVisibility();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          color: AppColors.background,
          child: Row(
            children: [
              _TabButton(
                icon: Icons.today_rounded,
                label: 'Điểm danh hôm nay',
                isSelected: _selectedIndex == 0,
                onTap: () => _select(0),
              ),
              const SizedBox(width: 8),
              _TabButton(
                icon: Icons.history_rounded,
                label: 'Lịch sử buổi học',
                isSelected: _selectedIndex == 1,
                onTap: () => _select(1),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              const TodayAttendanceView(),
              _visitedTabs.contains(1)
                  ? const HistoryAttendanceView()
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
