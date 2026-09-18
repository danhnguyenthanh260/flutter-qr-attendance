import 'package:flutter/material.dart';
import '../../core/constants/app_typography.dart';

class SessionSelectionView extends StatelessWidget {
  const SessionSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Chọn lớp và buổi học',
        style: AppTypography.heading2,
      ),
    );
  }
}
