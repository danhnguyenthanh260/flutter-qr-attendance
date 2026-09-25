import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/performance_log.dart';
import '../features/attendance/attendance_view.dart';
import '../features/roster_import/roster_preview_view.dart';
import '../features/teaching/session_selection_view.dart';
import 'widgets/workspace_navigation.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final Set<int> _visited = {0};
  static const _titles = [
    'Quản lý buổi học',
    'Theo dõi điểm danh',
    'Danh sách lớp từ file',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 1200;
      return Scaffold(
        body: Row(
          children: [
            WorkspaceNavigation(
              compact: compact,
              selectedIndex: _selectedIndex,
              onSelected: (index) {
                if (index == _selectedIndex) return;
                setState(() {
                  _selectedIndex = index;
                  _visited.add(index);
                });
                PerformanceLog.mark('navigate', {'tab': index});
              },
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _titles[_selectedIndex],
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (constraints.maxWidth >= 1000) ...[
                          const SizedBox(width: 16),
                          Text(
                            DateFormat(
                              'dd/MM/yyyy',
                              'vi_VN',
                            ).format(DateTime.now()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        const SessionSelectionView(),
                        _visited.contains(1)
                            ? AttendanceView(active: _selectedIndex == 1)
                            : const SizedBox.shrink(),
                        _visited.contains(2)
                            ? const RosterPreviewView()
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
