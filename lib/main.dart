import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_colors.dart';
import 'views/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  runApp(const QrAttendanceApp());
}

class QrAttendanceApp extends StatelessWidget {
  const QrAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Attendance - Điểm Danh Thông Minh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
      ),
      home: const AppShell(),
    );
  }
}
