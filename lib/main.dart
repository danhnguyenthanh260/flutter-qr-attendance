import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/performance_log.dart';
import 'data/services/attendance_service.dart';
import 'data/services/google_apps_script_attendance_service.dart';
import 'features/attendance/attendance_history_provider.dart';
import 'features/attendance/attendance_results_provider.dart';
import 'features/teaching/session_provider.dart';

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
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
