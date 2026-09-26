import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_qr_attendance/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('App shell smoke test renders navigation and session view', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final provider = SessionProvider(
      service: MockAttendanceService(simulateDelay: false),
      storage: MemorySessionStorage(),
    );
    addTearDown(() => provider.dispose());

    await tester.runAsync(() async {
      await provider.loadInitialData();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const QrAttendanceApp(),
      ),
    );
    await tester.pump();

    expect(find.text('QR Attendance'), findsOneWidget);
    expect(find.text('Lịch giảng dạy'), findsWidgets);
    expect(find.text('Lịch giảng dạy'), findsWidgets);
    expect(find.text('Hôm nay'), findsOneWidget);
  });
}
