import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/core/theme/app_theme.dart';
import 'package:flutter_qr_attendance/data/models/attendance_result_model.dart';
import 'package:flutter_qr_attendance/data/models/class_model.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/models/teaching_overview.dart';
import 'package:flutter_qr_attendance/data/repositories/teaching_repository.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/qr/qr_display_view.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_qr_attendance/features/teaching/session_selection_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/visual_capture.dart';

class CalendarFixture extends MockAttendanceService
    implements TeachingRepository {
  CalendarFixture() : super(simulateDelay: false) {
    configureClasses(const [
      ClassModel(
        id: 'c1',
        name: 'SE1913',
        courseCode: 'PRM393',
        room: 'A',
        totalStudents: 1,
        scheduleDescription: '',
      ),
      ClassModel(
        id: 'c2',
        name: 'SE1919',
        courseCode: 'PRN232',
        room: 'B',
        totalStudents: 1,
        scheduleDescription: '',
      ),
    ]);
  }
  int starts = 0;
  int weeklyReads = 0;
  bool failWeekly = false;
  String get date => DateTime.now().toIso8601String().substring(0, 10);
  @override
  Future<TeachingOverview> getTeachingOverview(String classId) async =>
      TeachingOverview(
        slots: [
          SessionSlot(
            id: 'slot-$classId',
            slotNumber: 1,
            timeRange: '07:00 - 08:30',
            date: date,
          ),
        ],
        roster: [
          RosterEntry(
            id: 'r-$classId',
            classId: classId,
            email: '$classId@example.edu',
            emailKey: '$classId@example.edu',
            studentName: 'Student $classId',
            rollNumber: 'ID-$classId',
          ),
        ],
        sessions: const [],
        attendance: const [],
      );
  @override
  Future<Map<String, TeachingOverview>> getWeeklyOverview() async {
    weeklyReads++;
    if (failWeekly) {
      throw const AttendanceApiException(
        code: 'redirect_to_execution',
        message: 'API chuyển ngược',
      );
    }
    return {
      for (final c in await getClasses()) c.id: await getTeachingOverview(c.id),
    };
  }

  @override
  Future<int> importRoster(Map<String, dynamic> payload) async =>
      throw UnimplementedError();
  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) {
    starts++;
    return super.startSession(classId: classId, slot: slot);
  }
}

class WorkspaceFixture extends CalendarFixture
    implements TeachingWorkspaceRepository {
  bool hideFirstClass = false;
  @override
  Future<TeachingWorkspace> refreshWorkspace() async {
    final classes = (await getClasses())
        .where((c) => !hideFirstClass || c.id != 'c1')
        .toList();
    return TeachingWorkspace(
      classes: classes,
      overview: {
        for (final c in classes) c.id: await getTeachingOverview(c.id),
      },
      activeSession: null,
    );
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets(
    'workspace refresh removes hidden classes from visible calendar',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = WorkspaceFixture();
      final provider = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: Scaffold(body: SessionSelectionView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SE1913'), findsOneWidget);
      service.hideFirstClass = true;
      await tester.tap(find.byTooltip('Làm mới lịch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SE1913'), findsNothing);
      expect(find.textContaining('SE1919'), findsOneWidget);
      expect(provider.classes.map((c) => c.id), ['c2']);
    },
  );
  testWidgets('failed refresh retains last successful calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = CalendarFixture();
    final provider = SessionProvider(
      service: service,
      storage: MemorySessionStorage(),
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(home: Scaffold(body: SessionSelectionView())),
      ),
    );
    await tester.pumpAndSettle();
    final before = find.textContaining('SE1913').evaluate().length;
    expect(before, greaterThan(0));
    service.failWeekly = true;
    await tester.tap(find.byTooltip('Làm mới lịch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SE1913').evaluate().length, before);
    expect(find.textContaining('Lịch lưu tạm từ'), findsOneWidget);
    expect(find.textContaining('Chưa có lịch trong tuần này'), findsNothing);
  });
  testWidgets(
    'failed first load exposes code and does not claim empty schedule',
    (tester) async {
      final service = CalendarFixture()..failWeekly = true;
      final provider = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: Scaffold(body: SessionSelectionView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('[redirect_to_execution]'), findsOneWidget);
      expect(find.textContaining('Chưa có lịch trong tuần này'), findsNothing);
      expect(find.textContaining('Log chẩn đoán:'), findsOneWidget);
    },
  );
  testWidgets(
    'all classes -> clicked lesson roster -> QR without any class selector',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CalendarFixture();
      final captureKey = GlobalKey();
      final provider = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light,
            home: RepaintBoundary(
              key: captureKey,
              child: const Scaffold(body: SessionSelectionView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, captureKey, 'fap-all-classes');
      expect(find.text('SE1913 · PRM393'), findsOneWidget);
      expect(find.text('SE1919 · PRN232'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<ClassModel>), findsNothing);
      expect(service.starts, 0);
      await tester.tap(find.byKey(ValueKey('lesson:c2:${service.date}:1')));
      await tester.pumpAndSettle();
      await capture(tester, captureKey, 'fap-lesson-roster');
      expect(find.text('Student c2'), findsOneWidget);
      expect(find.text('Student c1'), findsNothing);
      expect(find.text('Khởi tạo phiên điểm danh'), findsNothing);
      expect(find.byType(DropdownButtonFormField<ClassModel>), findsNothing);
      expect(service.starts, 0);
      await tester.tap(find.text('Về lịch tuần'));
      await tester.pumpAndSettle();
      expect(service.weeklyReads, 1);
      await tester.tap(find.byKey(ValueKey('lesson:c2:${service.date}:1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Điểm danh'));
      await tester.pumpAndSettle();
      expect(service.starts, 1);
      expect(provider.activeSession?.classId, 'c2');
      expect(provider.activeSession?.slot.date, service.date);
      expect(find.byType(QrDisplayView), findsOneWidget);
      expect(tester.takeException(), isNull);
      provider.stopQrRotation();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
