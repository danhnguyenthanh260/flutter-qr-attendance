import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/providers/attendance_history_provider.dart';
import 'package:flutter_qr_attendance/providers/attendance_results_provider.dart';

import 'helpers/attendance_fixtures.dart';

void main() {
  final roster = [
    buildRosterEntry('an@fpt.edu.vn', name: 'Nguyễn Văn An'),
    buildRosterEntry('binh@fpt.edu.vn', name: 'Trần Thị Bình'),
    buildRosterEntry('cuong@fpt.edu.vn', name: 'Lê Hữu Cường'),
  ];

  AttendanceSession closedSession({
    required String id,
    required String date,
    int slotNumber = 2,
    Duration openOffset = Duration.zero,
  }) {
    final openedAt = DateTime.parse('${date}T09:15:00').add(openOffset);
    return buildSession(
      id: id,
      date: date,
      slotNumber: slotNumber,
      openedAt: openedAt,
      closedAt: openedAt.add(const Duration(minutes: 40)),
      status: SessionStatus.closed,
    );
  }

  AttendanceHistoryProvider createProvider(FakeAttendanceService service) {
    final provider = AttendanceHistoryProvider(
      service: service,
      clock: () => kBaseTime,
    );
    addTearDown(provider.dispose);
    return provider;
  }

  test('gom phiên thành buổi học và sắp xếp mới nhất trước', () async {
    final recent = closedSession(id: 'SES_NEW', date: '2026-09-22');
    final older = closedSession(id: 'SES_OLD', date: '2026-09-15');

    final service = FakeAttendanceService(sessions: [older, recent])
      ..setResults(buildResults(session: recent, roster: roster))
      ..setResults(buildResults(session: older, roster: roster));

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, HistoryDataStatus.ok);
    expect(provider.groups.map((group) => group.date).toList(),
        ['2026-09-22', '2026-09-15']);
    expect(provider.selectedGroup!.date, '2026-09-22');
  });

  test('chỉ lấy buổi nằm trong khoảng ngày đã chọn', () async {
    final inRange = closedSession(id: 'SES_IN', date: '2026-09-20');
    final outOfRange = closedSession(id: 'SES_OUT', date: '2026-08-20');

    final service = FakeAttendanceService(sessions: [inRange, outOfRange])
      ..setResults(buildResults(session: inRange, roster: roster))
      ..setResults(buildResults(session: outOfRange, roster: roster));

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.groups.length, 1);
    expect(provider.groups.single.sessionIds, ['SES_IN']);
  });

  test('khoảng ngày trống báo rõ, không suy ra buổi vắng', () async {
    final service = FakeAttendanceService(sessions: const []);

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, HistoryDataStatus.empty);
    expect(provider.detail, isNull);
  });

  test('buổi nhiều phiên hợp nhất sinh viên theo email', () async {
    final first = closedSession(id: 'SES_A', date: '2026-09-22');
    final second = closedSession(
      id: 'SES_B',
      date: '2026-09-22',
      openOffset: const Duration(minutes: 50),
    );

    final service = FakeAttendanceService(sessions: [first, second])
      ..setResults(
        buildResults(
          session: first,
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_A', sessionId: 'SES_A'),
          ],
        ),
      )
      ..setResults(
        buildResults(
          session: second,
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_B', sessionId: 'SES_B'),
            buildAttendance('binh@fpt.edu.vn', id: 'ATT_C', sessionId: 'SES_B'),
          ],
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.groups.single.sessionCount, 2);
    expect(provider.detailStatus, HistoryDetailStatus.ok);
    expect(provider.detail!.totalStudents, 3);
    expect(provider.detail!.presentCount, 2);
    expect(provider.detail!.absentCount, 1);
  });

  test('một phiên đọc lỗi thì không dựng tổng kết thiếu', () async {
    final first = closedSession(id: 'SES_A', date: '2026-09-22');
    final second = closedSession(
      id: 'SES_B',
      date: '2026-09-22',
      openOffset: const Duration(minutes: 50),
    );

    final service = FakeAttendanceService(sessions: [first, second])
      ..setResults(
        buildResults(
          session: first,
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_A', sessionId: 'SES_A'),
          ],
        ),
      )
      ..failSession('SES_B', Exception('Không đọc được phiên'));

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.detailStatus, HistoryDetailStatus.unavailable);
    expect(provider.detail, isNull);
    expect(provider.detailErrorMessage, contains('Không đọc được phiên'));
  });

  test('thiếu roster của buổi được báo riêng', () async {
    final session = closedSession(id: 'SES_A', date: '2026-09-22');

    final service = FakeAttendanceService(sessions: [session])
      ..failSession(
        'SES_A',
        const AttendanceApiException(
          code: 'roster_missing',
          message: 'Lớp học chưa có danh sách sinh viên đang hoạt động.',
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.detailStatus, HistoryDetailStatus.rosterMissing);
    expect(provider.detail, isNull);
  });

  test('cùng dữ liệu thì lịch sử và bảng hôm nay ra cùng số liệu', () async {
    final session = closedSession(id: 'SES_A', date: '2026-09-22');
    final results = buildResults(
      session: session,
      roster: roster,
      attendance: [
        buildAttendance('an@fpt.edu.vn', id: 'ATT_A', sessionId: 'SES_A'),
        buildAttendance('binh@fpt.edu.vn', id: 'ATT_B', sessionId: 'SES_A'),
      ],
      attempts: [
        buildAttempt('an@fpt.edu.vn', id: 'ATM_A', sessionId: 'SES_A'),
      ],
    );

    final historyService = FakeAttendanceService(sessions: [session])
      ..setResults(results);
    final todayService = FakeAttendanceService(sessions: [session])
      ..setResults(results);

    final history = createProvider(historyService);
    await history.initialize();

    final today = AttendanceResultsProvider(
      service: todayService,
      clock: () => kBaseTime,
    );
    addTearDown(today.dispose);
    await today.initialize();

    expect(history.detail!.presentCount, today.summary!.presentCount);
    expect(history.detail!.absentCount, today.summary!.absentCount);
    expect(history.detail!.retryEventCount, today.summary!.retryEventCount);
    expect(history.detail!.totalStudents, today.summary!.totalStudents);
  });
}
