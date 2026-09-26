import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/attendance_results_provider.dart';
import 'package:flutter_qr_attendance/features/attendance/history_attendance_view.dart';
import 'package:flutter_qr_attendance/features/attendance/today_attendance_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers/attendance_fixtures.dart';

const List<Size> _windowSizes = [
  Size(1920, 1080),
  Size(1600, 900),
  Size(1366, 768),
  Size(1280, 800),
  Size(1024, 768),
  Size(960, 600),
  Size(800, 600),
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi_VN', null);
  });

  final roster = [
    buildRosterEntry('an@fpt.edu.vn', name: 'Nguyễn Văn An'),
    buildRosterEntry('binh@fpt.edu.vn', name: 'Trần Thị Bình'),
    buildRosterEntry('cuong@fpt.edu.vn', name: 'Lê Hữu Cường'),
  ];

  FakeAttendanceService buildService(AttendanceSession session) {
    return FakeAttendanceService(sessions: [session])..setResults(
      buildResults(
        session: session,
        roster: roster,
        attendance: [
          buildAttendance(
            'an@fpt.edu.vn',
            id: 'ATT_1',
            sessionId: session.id,
            name: 'Nguyễn Văn An',
          ),
        ],
        attempts: [
          buildAttempt('an@fpt.edu.vn', id: 'ATM_1', sessionId: session.id),
          buildAttempt(
            'khachlaruatdai@gmail.com',
            id: 'ATM_2',
            sessionId: session.id,
            attemptType: 'roster_mismatch',
            reason: 'email_not_in_roster',
          ),
        ],
      ),
    );
  }

  void applySize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  AttendanceResultsProvider todayProvider(AttendanceSession session) {
    return AttendanceResultsProvider(
      service: buildService(session),
      clock: () => kBaseTime,
      autoRefresh: false,
    );
  }

  group('Bảng điểm danh hôm nay không tràn ở mọi cỡ cửa sổ', () {
    for (final size in _windowSizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('phiên đã chốt tại $label', (tester) async {
        applySize(tester, size);
        final provider = todayProvider(
          buildSession(
            status: SessionStatus.closed,
            closedAt: kBaseTime.add(const Duration(minutes: 50)),
          ),
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AttendanceResultsProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: Scaffold(body: TodayAttendanceView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(provider.status, AttendanceDataStatus.ok);
        expect(tester.takeException(), isNull);
      });

      testWidgets('phiên đang mở tại $label', (tester) async {
        applySize(tester, size);
        final provider = todayProvider(
          buildSession(status: SessionStatus.active),
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AttendanceResultsProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: Scaffold(body: TodayAttendanceView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(provider.status, AttendanceDataStatus.ok);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Lịch sử buổi học không tràn ở mọi cỡ cửa sổ', () {
    for (final size in _windowSizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('tại $label', (tester) async {
        applySize(tester, size);
        final session = buildSession(
          status: SessionStatus.closed,
          closedAt: kBaseTime.add(const Duration(minutes: 50)),
        );
        final provider = AttendanceHistoryProvider(
          service: buildService(session),
          clock: () => kBaseTime,
        );
        addTearDown(provider.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AttendanceHistoryProvider>.value(
            value: provider,
            child: const MaterialApp(
              home: Scaffold(body: HistoryAttendanceView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(provider.detailStatus, HistoryDetailStatus.ok);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
