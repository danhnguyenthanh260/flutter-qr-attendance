import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/providers/attendance_results_provider.dart';
import 'package:flutter_qr_attendance/views/attendance/today_attendance_view.dart';

import 'helpers/attendance_fixtures.dart';

void main() {
  final roster = [
    buildRosterEntry('an@fpt.edu.vn', name: 'Nguyễn Văn An'),
    buildRosterEntry('binh@fpt.edu.vn', name: 'Trần Thị Bình'),
  ];

  Future<void> pumpView(
    WidgetTester tester,
    FakeAttendanceService service,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = AttendanceResultsProvider(
      service: service,
      clock: () => kBaseTime,
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: TodayAttendanceView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phiên đang mở hiển thị chưa điểm danh và cảnh báo tạm tính',
      (tester) async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
          attempts: [buildAttempt('an@fpt.edu.vn', id: 'ATM_1')],
        ),
      );

    await pumpView(tester, service);

    expect(find.text('Chưa điểm danh'), findsWidgets);
    expect(find.text('Vắng'), findsNothing);
    expect(find.textContaining('tạm tính'), findsWidgets);
    expect(find.text('Nguyễn Văn An'), findsWidgets);
  });

  testWidgets('phiên đã chốt hiển thị vắng và trạng thái đã chốt',
      (tester) async {
    final closed = buildSession(
      status: SessionStatus.closed,
      closedAt: kBaseTime.add(const Duration(minutes: 50)),
    );
    final service = FakeAttendanceService(sessions: [closed])
      ..setResults(
        buildResults(
          session: closed,
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
        ),
      );

    await pumpView(tester, service);

    expect(find.text('Vắng'), findsWidgets);
    expect(find.textContaining('Đã chốt'), findsWidgets);
    expect(find.text('Chưa điểm danh'), findsNothing);
  });

  testWidgets('thiếu roster hiển thị cảnh báo thay vì bảng số 0',
      (tester) async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..failSession(
        'SES_1',
        const AttendanceApiException(
          code: 'roster_missing',
          message: 'Lớp học chưa có danh sách sinh viên đang hoạt động.',
        ),
      );

    await pumpView(tester, service);

    expect(find.text('Lớp chưa có danh sách sinh viên'), findsOneWidget);
    expect(find.text('Sĩ số roster'), findsNothing);
  });

  testWidgets('không có phiên nào thì không dựng bảng kết quả', (tester) async {
    final service = FakeAttendanceService(sessions: const []);

    await pumpView(tester, service);

    expect(find.text('Chưa có phiên điểm danh'), findsOneWidget);
    expect(find.text('Danh sách đối chiếu roster'), findsNothing);
  });
}
