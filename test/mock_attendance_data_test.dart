import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_qr_attendance/data/models/attendance_summary.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';

void main() {
  late DateTime now;
  late MockAttendanceService service;

  setUp(() {
    now = DateTime(2026, 9, 22, 9, 15);
    service = MockAttendanceService(simulateDelay: false, clock: () => now);
  });

  test('lịch sử được seed đủ các buổi đã chốt', () async {
    final classes = await service.getClasses();
    final sessions = await service.listSessions(classId: classes.first.id);

    expect(sessions, isNotEmpty);
    expect(sessions.every((item) => item.status == SessionStatus.closed), isTrue);
  });

  test('roster mock khớp sĩ số lớp và email là duy nhất', () async {
    final classes = await service.getClasses();
    final roster = service.dataset.rosterFor(classes.first.id);

    expect(roster.length, classes.first.totalStudents);
    expect(roster.map((entry) => entry.emailKey).toSet().length, roster.length);
  });

  test('kết quả phiên đã chốt ổn định giữa các lần đọc', () async {
    final classes = await service.getClasses();
    final sessions = await service.listSessions(classId: classes.first.id);

    final first = await service.getSessionResults(sessions.first.id);
    now = now.add(const Duration(hours: 3));
    final second = await service.getSessionResults(sessions.first.id);

    expect(second.attendance.length, first.attendance.length);
    expect(second.attempts.length, first.attempts.length);
  });

  test('phiên đang mở tích lũy lượt điểm danh theo thời gian', () async {
    final classes = await service.getClasses();
    final slots = await service.getSlotsForClass(classes.first.id);
    final session = await service.startSession(
      classId: classes.first.id,
      slot: slots.first,
    );

    final atOpen = await service.getSessionResults(session.id);
    expect(atOpen.attendance, isEmpty);

    now = now.add(const Duration(minutes: 10));
    final later = await service.getSessionResults(session.id);

    expect(later.attendance, isNotEmpty);
    expect(
      AttendanceSummary.fromSessionResults(later).isProvisional,
      isTrue,
    );
  });

  test('phiên vừa tạo xuất hiện trong danh sách theo ngày', () async {
    final classes = await service.getClasses();
    final slots = await service.getSlotsForClass(classes.first.id);
    final session = await service.startSession(
      classId: classes.first.id,
      slot: slots.first,
    );

    final today = await service.listSessions(
      classId: classes.first.id,
      date: '2026-09-22',
    );

    expect(today.map((item) => item.id), contains(session.id));
  });

  test('lớp không có roster trả lỗi roster_missing thay vì bảng rỗng', () async {
    final classes = await service.getClasses();
    final sessions = await service.listSessions(classId: classes.first.id);
    service.configureRoster(classes.first.id, const []);

    await expectLater(
      service.getSessionResults(sessions.first.id),
      throwsA(
        isA<AttendanceApiException>()
            .having((error) => error.isRosterMissing, 'isRosterMissing', isTrue),
      ),
    );
  });

  test('phiên không tồn tại trả lỗi not_found', () async {
    await expectLater(
      service.getSessionResults('SES_KHONG_CO'),
      throwsA(
        isA<AttendanceApiException>()
            .having((error) => error.isNotFound, 'isNotFound', isTrue),
      ),
    );
  });
}
