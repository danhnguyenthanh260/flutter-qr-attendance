import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/utils/performance_log.dart';
import 'data/services/attendance_service.dart';
import 'data/services/google_apps_script_attendance_service.dart';
import 'providers/attendance_history_provider.dart';
import 'providers/attendance_results_provider.dart';
import 'providers/session_provider.dart';
import 'views/shell/app_shell.dart';

void main() async {
  PerformanceLog.mark('startup');
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => PerformanceLog.mark('first_frame'),
  );
  await initializeDateFormatting('vi_VN', null);

  final AttendanceService attendanceService =
      createConfiguredTeacherAttendanceService();
  final sessionProvider = SessionProvider(service: attendanceService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sessionProvider),
        ChangeNotifierProvider(
          create: (_) => AttendanceResultsProvider(
            service: attendanceService,
            preferredSession: () => sessionProvider.activeSession,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceHistoryProvider(service: attendanceService),
        ),
      ],
      child: const QrAttendanceApp(),
    ),
  );
}

class QrAttendanceApp extends StatelessWidget {
  const QrAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Attendance - Điểm Danh Thông Minh',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
