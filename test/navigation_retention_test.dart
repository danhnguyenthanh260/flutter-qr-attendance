import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/app/app_shell.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_results_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/history_attendance_view.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/attendance_fixtures.dart';

void main() {
  testWidgets(
    'ten sidebar round trips retain history and do not reload its scope',
    (tester) async {
      await initializeDateFormatting('vi_VN');
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeAttendanceService();
      final session = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      final today = AttendanceResultsProvider(
        service: service,
        autoRefresh: false,
      );
      final history = AttendanceHistoryProvider(service: service);
      addTearDown(session.dispose);
      addTearDown(today.dispose);
      addTearDown(history.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: session),
            ChangeNotifierProvider.value(value: today),
            ChangeNotifierProvider.value(value: history),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bảng điểm danh', skipOffstage: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch sử buổi học'));
      await tester.pumpAndSettle();
      final requests = service.listSessionsCalls;
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Phiên điểm danh'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bảng điểm danh', skipOffstage: true));
        await tester.pumpAndSettle();
        expect(find.byType(HistoryAttendanceView), findsOneWidget);
      }
      expect(service.listSessionsCalls, requests);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hidden attendance tab stops background polling', (tester) async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(buildResults());
    final provider = AttendanceResultsProvider(
      service: service,
      clock: () => kBaseTime,
      refreshInterval: const Duration(seconds: 1),
    );
    addTearDown(provider.dispose);
    await provider.initialize();
    final calls = service.getSessionResultsCalls;
    provider.setVisible(false);
    await tester.pump(const Duration(seconds: 10));
    expect(service.getSessionResultsCalls, calls);
    provider.setVisible(true);
    await tester.pump(const Duration(seconds: 1));
    expect(service.getSessionResultsCalls, greaterThan(calls));
    provider.setVisible(false);
  });
}
