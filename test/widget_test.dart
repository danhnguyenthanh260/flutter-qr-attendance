import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flutter_qr_attendance/main.dart';
import 'package:flutter_qr_attendance/providers/session_provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('App shell smoke test renders navigation and session view', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SessionProvider(),
        child: const QrAttendanceApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QR Attendance'), findsOneWidget);
    expect(find.text('Phiên điểm danh'), findsOneWidget);
    expect(find.text('Khởi tạo phiên điểm danh'), findsOneWidget);
    expect(find.text('Bắt đầu phiên điểm danh'), findsOneWidget);
  });
}
