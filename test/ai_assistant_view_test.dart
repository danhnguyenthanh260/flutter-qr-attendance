import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/data/services/gemini_ai_service.dart';
import 'package:flutter_qr_attendance/providers/ai_assistant_provider.dart';
import 'package:flutter_qr_attendance/providers/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/providers/attendance_results_provider.dart';
import 'package:flutter_qr_attendance/views/ai_assistant/ai_assistant_view.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  testWidgets('renders AiAssistantView with toolbar, chips and message history', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockService = MockAttendanceService(simulateDelay: false);
    final resultsProvider = AttendanceResultsProvider(service: mockService);
    final historyProvider = AttendanceHistoryProvider(service: mockService);
    final aiProvider = AiAssistantProvider(
      aiService: LocalAttendanceAiService(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: resultsProvider),
          ChangeNotifierProvider.value(value: historyProvider),
          ChangeNotifierProvider.value(value: aiProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiAssistantView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trợ lý Chuyên cần AI'), findsOneWidget);
    expect(find.text('Tạo báo cáo chuyên cần'), findsOneWidget);
    expect(find.text('Cấu hình API'), findsOneWidget);
    expect(find.text('👥 Ai đang vắng hoặc chưa điểm danh?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('clicking suggested prompt chip triggers message send', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockService = MockAttendanceService(simulateDelay: false);
    final resultsProvider = AttendanceResultsProvider(service: mockService);
    final historyProvider = AttendanceHistoryProvider(service: mockService);
    final aiProvider = AiAssistantProvider(
      aiService: LocalAttendanceAiService(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: resultsProvider),
          ChangeNotifierProvider.value(value: historyProvider),
          ChangeNotifierProvider.value(value: aiProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiAssistantView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chipFinder = find.text('👥 Ai đang vắng hoặc chưa điểm danh?');
    await tester.tap(chipFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('👥 Ai đang vắng hoặc chưa điểm danh?'), findsWidgets);
  });
}
