import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_qr_attendance/app/app_shell.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/core/theme/app_theme.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_results_provider.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/visual_capture.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    await loadCaptureFonts();
  });
  for (final size in [
    const Size(1024, 768),
    const Size(1280, 720),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'workspace ${size.width} at text scale $scale retains usable controls',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final service = MockAttendanceService(simulateDelay: false);
          final session = SessionProvider(
            service: service,
            storage: MemorySessionStorage(),
          );
          final results = AttendanceResultsProvider(
            service: service,
            autoRefresh: false,
          );
          final history = AttendanceHistoryProvider(service: service);
          addTearDown(session.dispose);
          addTearDown(results.dispose);
          addTearDown(history.dispose);
          await session.loadInitialData();
          final key = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: session),
                ChangeNotifierProvider.value(value: results),
                ChangeNotifierProvider.value(value: history),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(key: key, child: const AppShell()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'workspace-${size.width.toInt()}-$scale');
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, isNotNull);
          // Open a synthetic session to exercise the QR presentation and narrow action wrap.
          await session.startSession();
          await tester.pump();
          await tester.tap(find.textContaining('Phiên đang mở ·'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Xem mã QR'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await capture(tester, key, 'qr-${size.width.toInt()}-$scale');
          session.stopQrRotation();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
