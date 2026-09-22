import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/providers/attendance_results_provider.dart';

import 'helpers/attendance_fixtures.dart';

void main() {
  final roster = [
    buildRosterEntry('an@fpt.edu.vn', name: 'Nguyễn Văn An'),
    buildRosterEntry('binh@fpt.edu.vn', name: 'Trần Thị Bình'),
  ];

  AttendanceResultsProvider createProvider(FakeAttendanceService service) {
    final provider = AttendanceResultsProvider(
      service: service,
      clock: () => kBaseTime,
    );
    addTearDown(provider.dispose);
    return provider;
  }

  test('nạp xong hiển thị bảng đúng phạm vi lớp và ngày', () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, AttendanceDataStatus.ok);
    expect(provider.selectedDate, '2026-09-22');
    expect(provider.summary!.presentCount, 1);
    expect(provider.summary!.notYetCount, 1);
    expect(provider.lastUpdatedAt, isNotNull);
  });

  test('ưu tiên chọn phiên đang mở khi buổi có nhiều phiên', () async {
    final closed = buildSession(
      id: 'SES_CLOSED',
      status: SessionStatus.closed,
      openedAt: kBaseTime.add(const Duration(hours: 1)),
      closedAt: kBaseTime.add(const Duration(hours: 2)),
    );
    final open = buildSession(id: 'SES_OPEN', status: SessionStatus.active);

    final service = FakeAttendanceService(sessions: [closed, open])
      ..setResults(buildResults(session: closed, roster: roster))
      ..setResults(buildResults(session: open, roster: roster));

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.selectedSession!.id, 'SES_OPEN');
    expect(provider.canAutoRefresh, isTrue);
  });

  test('không có phiên nào thì báo rõ, không hiển thị số 0', () async {
    final service = FakeAttendanceService(sessions: const []);

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, AttendanceDataStatus.noSession);
    expect(provider.summary, isNull);
  });

  test('thiếu roster báo trạng thái riêng và không dựng bảng rỗng', () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..failSession(
        'SES_1',
        const AttendanceApiException(
          code: 'roster_missing',
          message: 'Lớp học chưa có danh sách sinh viên đang hoạt động.',
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, AttendanceDataStatus.rosterMissing);
    expect(provider.summary, isNull);
    expect(provider.errorMessage, contains('danh sách sinh viên'));
  });

  test('lỗi mạng ngay lần đọc đầu không tạo số liệu giả', () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..failSession('SES_1', Exception('Không kết nối được máy chủ'));

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, AttendanceDataStatus.unavailable);
    expect(provider.summary, isNull);
  });

  test('lỗi khi làm mới vẫn giữ dữ liệu cũ và nêu rõ trạng thái', () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();
    expect(provider.summary!.presentCount, 1);

    service.failSession('SES_1', Exception('Mất kết nối'));
    await provider.refresh();

    expect(provider.status, AttendanceDataStatus.ok);
    expect(provider.summary!.presentCount, 1);
    expect(provider.refreshErrorMessage, contains('Mất kết nối'));
  });

  test('đọc lại sau mất mạng không mất sự kiện và không nhân đôi cảnh báo',
      () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
          attempts: [buildAttempt('an@fpt.edu.vn', id: 'ATM_1')],
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();
    expect(provider.summary!.retryEventCount, 1);

    service.failSession('SES_1', Exception('Mất kết nối'));
    await provider.refresh();
    expect(provider.summary!.retryEventCount, 1);

    service
      ..clearFailure('SES_1')
      ..setResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
          attempts: [buildAttempt('binh@fpt.edu.vn', id: 'ATM_2')],
        ),
      );
    await provider.refresh();

    expect(provider.summary!.retryEventCount, 2);
    expect(provider.refreshErrorMessage, isNull);
  });

  test('đọc lặp cùng một phản hồi không làm tăng số liệu', () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
          attempts: [buildAttempt('an@fpt.edu.vn', id: 'ATM_1')],
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();
    await provider.refresh();
    await provider.refresh();

    expect(provider.summary!.presentCount, 1);
    expect(provider.summary!.retryEventCount, 1);
  });

  test('đổi phiên không trộn dữ liệu của phiên trước', () async {
    final first = buildSession(id: 'SES_A');
    final second = buildSession(
      id: 'SES_B',
      openedAt: kBaseTime.add(const Duration(minutes: 90)),
    );

    final service = FakeAttendanceService(sessions: [first, second])
      ..setResults(
        buildResults(
          session: first,
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_A', sessionId: 'SES_A'),
            buildAttendance('binh@fpt.edu.vn', id: 'ATT_B', sessionId: 'SES_A'),
          ],
        ),
      )
      ..setResults(
        buildResults(
          session: second,
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_C', sessionId: 'SES_B'),
          ],
        ),
      );

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.selectedSession!.id, 'SES_B');
    expect(provider.summary!.presentCount, 1);

    await provider.selectSession(first);

    expect(provider.selectedSession!.id, 'SES_A');
    expect(provider.summary!.presentCount, 2);
    expect(provider.summary!.scope.sessionId, "SES_A");
  });

  test('phiên đã chốt thì dừng tự động cập nhật', () async {
    final closed = buildSession(
      status: SessionStatus.closed,
      closedAt: kBaseTime.add(const Duration(minutes: 50)),
    );
    final service = FakeAttendanceService(sessions: [closed])
      ..setResults(buildResults(session: closed, roster: roster));

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.summary!.isFinalized, isTrue);
    expect(provider.canAutoRefresh, isFalse);
  });

  test('tắt tự động cập nhật vẫn cho phép làm mới thủ công', () async {
    final service = FakeAttendanceService(sessions: [buildSession()])
      ..setResults(buildResults(roster: roster));

    final provider = createProvider(service);
    await provider.initialize();
    final callsAfterInit = service.getSessionResultsCalls;

    provider.setAutoRefresh(false);
    await provider.refresh();

    expect(provider.autoRefreshEnabled, isFalse);
    expect(service.getSessionResultsCalls, callsAfterInit + 1);
  });

  test('không đọc được danh sách lớp thì báo lỗi thay vì bảng rỗng', () async {
    final service = FakeAttendanceService()
      ..classesFailure = Exception('Máy chủ không phản hồi');

    final provider = createProvider(service);
    await provider.initialize();

    expect(provider.status, AttendanceDataStatus.unavailable);
    expect(provider.summary, isNull);
    expect(provider.errorMessage, contains('Máy chủ không phản hồi'));
  });
}
