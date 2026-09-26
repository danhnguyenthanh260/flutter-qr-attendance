import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/core/theme/app_theme.dart';
import 'package:flutter_qr_attendance/data/models/attendance_result_model.dart';
import 'package:flutter_qr_attendance/data/models/class_roster.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/models/teaching_overview.dart';
import 'package:flutter_qr_attendance/data/repositories/roster_repository.dart';
import 'package:flutter_qr_attendance/data/repositories/teaching_repository.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_matrix_view.dart';
import 'package:flutter_qr_attendance/features/roster_import/class_data_view.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/visual_capture.dart';

class RosterFixture extends MockAttendanceService
    implements RosterRepository, TeachingWorkspaceRepository {
  RosterFixture() : super(simulateDelay: false);
  var writes = 0;
  var roster = const ClassRoster(
    [
      RosterEntry(
        id: 'stable',
        classId: 'CLASS_001',
        rollNumber: 'SE000001',
        email: 'one@example.edu',
        emailKey: 'one@example.edu',
        studentName: 'Student One',
      ),
    ],
    'rev',
    1,
  );
  @override
  Future<ClassRoster> getClassRoster(String classId) async => roster;
  @override
  Future<ClassRoster> updateRoster(Map<String, dynamic> payload) async {
    writes++;
    expect(payload['accept_legacy_snapshot'], true);
    roster = ClassRoster(
      (payload['students'] as List)
          .map((s) => RosterEntry.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      'next',
      0,
    );
    return roster;
  }

  @override
  Future<TeachingWorkspace> refreshWorkspace() async {
    final classes = await getClasses();
    return TeachingWorkspace(
      classes: classes,
      overview: {
        for (final c in classes)
          c.id: TeachingOverview(
            slots: const [],
            roster: roster.students,
            sessions: const [],
            attendance: const [],
          ),
      },
      activeSession: null,
    );
  }
}

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets('matrix supports 14 lessons at narrow desktop width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = RosterFixture();
    final session = SessionProvider(
      service: service,
      storage: MemorySessionStorage(),
    );
    addTearDown(session.dispose);
    await session.refreshTeachingWorkspace();
    session.workspaceOverview = {
      session.classes.first.id: TeachingOverview(
        slots: [
          for (var day = 1; day <= 14; day++)
            SessionSlot(
              slotNumber: 2,
              timeRange: '09:39–11:09',
              date: '2026-10-${day.toString().padLeft(2, '0')}',
            ),
        ],
        roster: service.roster.students,
        sessions: const [],
        attendance: const [],
      ),
    };
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: captureKey,
            child: const Scaffold(body: AttendanceMatrixView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Student One'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(14));
    expect(tester.takeException(), isNull);
    await capture(tester, captureKey, 'attendance-matrix-1.5.0');
  });
  testWidgets(
    'deactivate previews exact change, cancel writes nothing, confirm retains inactive student',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = RosterFixture();
      final session = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: Scaffold(body: ClassDataView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Student One'), findsOneWidget);
      await tester.tap(find.text('Ngừng học'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('phiên cũ chưa có roster gốc'),
        findsOneWidget,
      );
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(service.writes, 0);
      await tester.tap(find.text('Ngừng học'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(service.writes, 1);
      expect(find.text('Student One'), findsNothing);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Student One'), findsOneWidget);
      expect(find.text('Khôi phục'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
