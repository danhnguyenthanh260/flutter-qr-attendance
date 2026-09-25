import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_icons.dart';

class WorkspaceNavigation extends StatelessWidget {
  const WorkspaceNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.compact = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool compact;
  static const destinations = [
    (label: 'Phiên điểm danh', icon: AppIcons.session),
    (label: 'Bảng điểm danh', icon: AppIcons.attendance),
    (label: 'Dữ liệu lớp', icon: AppIcons.roster),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? 80 : 224,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Row(
              children: [
                const Icon(
                  AppIcons.session,
                  color: AppColors.primary,
                  size: 32,
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'QR Attendance',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Tooltip(
                message: compact ? destinations[index].label : '',
                child: Semantics(
                  selected: selectedIndex == index,
                  child: Material(
                    color: Colors.transparent,
                    child: compact
                        ? IconButton.filledTonal(
                            isSelected: selectedIndex == index,
                            style: IconButton.styleFrom(
                              backgroundColor: selectedIndex == index
                                  ? AppColors.primaryLight
                                  : Colors.transparent,
                            ),
                            tooltip: destinations[index].label,
                            onPressed: () => onSelected(index),
                            icon: Icon(destinations[index].icon),
                          )
                        : ListTile(
                            selected: selectedIndex == index,
                            selectedTileColor: AppColors.primaryLight,
                            selectedColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minTileHeight: 56,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: compact ? 20 : 16,
                            ),
                            leading: Icon(destinations[index].icon, size: 24),
                            title: compact
                                ? null
                                : Text(destinations[index].label),
                            onTap: () => onSelected(index),
                          ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (!compact)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Không gian giảng viên',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    ),
  );
}
