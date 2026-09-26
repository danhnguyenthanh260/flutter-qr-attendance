import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/app/app_shell.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_results_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_view.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_qr_attendance/features/teaching/session_selection_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  Widget buildTestApp({
    required SessionProvider sessionProvider,
    required AttendanceResultsProvider resultsProvider,
    required AttendanceHistoryProvider historyProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>.value(value: sessionProvider),
        ChangeNotifierProvider<AttendanceResultsProvider>.value(
          value: resultsProvider,
        ),
        ChangeNotifierProvider<AttendanceHistoryProvider>.value(
          value: historyProvider,
        ),
      ],
      child: const MaterialApp(home: AppShell()),
    );
  }

  group('Issue #48 - Navigation State Preservation & Startup Latency Tests', () {
    testWidgets(
      'Lazy IndexedStack mounts Tab 0 initially and mounts other tabs on demand',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final service = MockAttendanceService(simulateDelay: false);
        final storage = MemorySessionStorage();
        final sessionProvider = SessionProvider(
          service: service,
          storage: storage,
        );
        final resultsProvider = AttendanceResultsProvider(service: service);
        final historyProvider = AttendanceHistoryProvider(service: service);

        addTearDown(() {
          sessionProvider.dispose();
          resultsProvider.dispose();
          historyProvider.dispose();
        });

        await tester.pumpWidget(
          buildTestApp(
            sessionProvider: sessionProvider,
            resultsProvider: resultsProvider,
            historyProvider: historyProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Tab 0 (SessionSelectionView) is mounted initially
        expect(find.byType(SessionSelectionView), findsOneWidget);
        // Tab 1 (AttendanceView) must NOT be mounted yet (lazy loading to prevent request storm)
        expect(find.byType(AttendanceView), findsNothing);

        // Tap tab 1 (Bảng điểm danh)
        await tester.tap(find.widgetWithText(InkWell, 'Bảng điểm danh'));
        await tester.pumpAndSettle();

        // Now Tab 1 is mounted
        expect(find.byType(AttendanceView), findsOneWidget);
      },
    );

    testWidgets(
      'Switching between tabs 10 rounds preserves view state with 0 reload',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final service = MockAttendanceService(simulateDelay: false);
        final storage = MemorySessionStorage();
        final sessionProvider = SessionProvider(
          service: service,
          storage: storage,
        );
        final resultsProvider = AttendanceResultsProvider(service: service);
        final historyProvider = AttendanceHistoryProvider(service: service);

        addTearDown(() {
          sessionProvider.dispose();
          resultsProvider.dispose();
          historyProvider.dispose();
        });

        await sessionProvider.loadInitialData();

        await tester.pumpWidget(
          buildTestApp(
            sessionProvider: sessionProvider,
            resultsProvider: resultsProvider,
            historyProvider: historyProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Initial state: classes loaded, slot selected
        expect(sessionProvider.selectedClass, isNotNull);
        final initialSelectedClassId = sessionProvider.selectedClass!.id;

        // Select Ca 2 if available
        if (sessionProvider.slots.length > 1) {
          sessionProvider.selectSlot(sessionProvider.slots[1]);
          await tester.pumpAndSettle();
        }
        final initialSlot = sessionProvider.selectedSlot;

        // Switch between Tab 0 and Tab 1 for 10 rounds
        for (int i = 0; i < 10; i++) {
          await tester.tap(find.widgetWithText(InkWell, 'Bảng điểm danh'));
          await tester.pumpAndSettle();
          expect(find.byType(AttendanceView), findsOneWidget);

          await tester.tap(find.widgetWithText(InkWell, 'Lịch giảng dạy'));
          await tester.pumpAndSettle();
          expect(find.byType(SessionSelectionView), findsOneWidget);
        }

        // Verify that after 10 rounds, form state in SessionSelectionView was completely preserved
        expect(
          sessionProvider.selectedClass?.id,
          equals(initialSelectedClassId),
        );
        expect(sessionProvider.selectedSlot, equals(initialSlot));
      },
    );

    test(
      'SessionProvider.loadInitialData deduplicates concurrent in-flight calls',
      () async {
        final service = MockAttendanceService(simulateDelay: false);
        final storage = MemorySessionStorage();
        final sessionProvider = SessionProvider(
          service: service,
          storage: storage,
        );
        addTearDown(() => sessionProvider.dispose());

        expect(sessionProvider.isInitialized, isFalse);

        // Trigger loadInitialData concurrently
        final future1 = sessionProvider.loadInitialData();
        final future2 = sessionProvider.loadInitialData();

        // Both should return the same in-flight Future
        expect(identical(future1, future2), isTrue);

        await future1;

        expect(sessionProvider.isInitialized, isTrue);
        expect(sessionProvider.classes.isNotEmpty, isTrue);
      },
    );

    testWidgets(
      'SessionSelectionView renders immediately without blocking full screen when loading',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final service = MockAttendanceService(simulateDelay: false);
        final storage = MemorySessionStorage();
        final sessionProvider = SessionProvider(
          service: service,
          storage: storage,
        );
        addTearDown(() => sessionProvider.dispose());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<SessionProvider>.value(
                value: sessionProvider,
                child: const SessionSelectionView(),
              ),
            ),
          ),
        );

        // Verify first frame renders immediately: Card headers and form structure exist
        expect(find.text('Lịch giảng dạy'), findsWidgets);
        expect(find.text('Hôm nay'), findsOneWidget);
        expect(find.byType(Table), findsOneWidget);
      },
    );
  });
}
