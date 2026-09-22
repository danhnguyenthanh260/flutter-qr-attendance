import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_qr_attendance/data/models/attendance_summary.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';

import 'helpers/attendance_fixtures.dart';

void main() {
  final roster = [
    buildRosterEntry('an@fpt.edu.vn', name: 'Nguyễn Văn An'),
    buildRosterEntry('binh@fpt.edu.vn', name: 'Trần Thị Bình'),
    buildRosterEntry('cuong@fpt.edu.vn', name: 'Lê Hữu Cường'),
  ];

  group('Trạng thái sinh viên theo vòng đời phiên', () {
    test('phiên đang mở: chưa nộp là chưa điểm danh, không phải vắng', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          session: buildSession(status: SessionStatus.active),
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
        ),
      );

      expect(summary.presentCount, 1);
      expect(summary.notYetCount, 2);
      expect(summary.absentCount, 0);
      expect(summary.isProvisional, isTrue);
      expect(summary.isFinalized, isFalse);
      expect(summary.pendingCount, 2);
    });

    test('phiên đang chốt sổ vẫn là tạm tính, chưa kết luận vắng', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          session: buildSession(status: SessionStatus.closing),
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
        ),
      );

      expect(summary.isSettling, isTrue);
      expect(summary.isFinalized, isFalse);
      expect(summary.absentCount, 0);
      expect(summary.notYetCount, 2);
    });

    test('phiên đã chốt: chưa nộp mới được tính là vắng', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          session: buildSession(
            status: SessionStatus.closed,
            closedAt: kBaseTime.add(const Duration(minutes: 50)),
          ),
          roster: roster,
          attendance: [buildAttendance('an@fpt.edu.vn')],
        ),
      );

      expect(summary.isFinalized, isTrue);
      expect(summary.absentCount, 2);
      expect(summary.notYetCount, 0);
      expect(summary.pendingCount, 2);
    });

    test('thời điểm ghi nhận lấy lượt hợp lệ sớm nhất', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attendance: [
            buildAttendance(
              'an@fpt.edu.vn',
              id: 'ATT_LATE',
              acceptedAt: kBaseTime.add(const Duration(minutes: 8)),
            ),
            buildAttendance(
              'an@fpt.edu.vn',
              id: 'ATT_EARLY',
              acceptedAt: kBaseTime.add(const Duration(minutes: 2)),
            ),
          ],
        ),
      );

      final row = summary.rows.firstWhere(
        (item) => item.student.email == 'an@fpt.edu.vn',
      );
      expect(row.acceptedAt, kBaseTime.add(const Duration(minutes: 2)));
    });
  });

  group('Chống trùng và lượt nộp lại', () {
    test('hai bản ghi cùng email chỉ tính một người có mặt', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_1'),
            buildAttendance('an@fpt.edu.vn', id: 'ATT_2'),
          ],
        ),
      );

      expect(summary.presentCount, 1);
    });

    test('email khác hoa thường vẫn là cùng một sinh viên', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attendance: [buildAttendance('AN@FPT.EDU.VN')],
        ),
      );

      expect(summary.presentCount, 1);
      expect(summary.unlistedSubmissions, isEmpty);
    });

    test('lượt nộp lại không tăng số có mặt và tham chiếu được lượt gốc', () {
      final acceptedAt = kBaseTime.add(const Duration(minutes: 2));
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attendance: [
            buildAttendance(
              'an@fpt.edu.vn',
              id: 'ATT_GOC',
              acceptedAt: acceptedAt,
            ),
          ],
          attempts: [
            buildAttempt('an@fpt.edu.vn', id: 'ATM_1'),
            buildAttempt('an@fpt.edu.vn', id: 'ATM_2'),
          ],
        ),
      );

      expect(summary.presentCount, 1);
      expect(summary.retryEventCount, 2);
      expect(summary.retryStudentCount, 1);

      final event = summary.retryEvents.first;
      expect(event.originalAttendanceId, 'ATT_GOC');
      expect(event.originalAcceptedAt, acceptedAt);
      expect(event.isOnRoster, isTrue);
      expect(event.sessionId, 'SES_1');

      final row = summary.rows.firstWhere(
        (item) => item.student.email == 'an@fpt.edu.vn',
      );
      expect(row.retryCount, 2);
      expect(row.rejectedCount, 0);
    });

    test('lượt bị từ chối được tách khỏi lượt nộp lại', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attempts: [
            buildAttempt(
              'binh@fpt.edu.vn',
              id: 'ATM_EXP',
              attemptType: 'grant_expired',
              reason: 'grace_expired',
            ),
          ],
        ),
      );

      final row = summary.rows.firstWhere(
        (item) => item.student.email == 'binh@fpt.edu.vn',
      );
      expect(row.retryCount, 0);
      expect(row.rejectedCount, 1);
      expect(summary.retryEvents.single.hasOriginalSubmission, isFalse);
    });

    test('cảnh báo sắp xếp mới nhất trước', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attempts: [
            buildAttempt(
              'an@fpt.edu.vn',
              id: 'ATM_CU',
              occurredAt: kBaseTime.add(const Duration(minutes: 3)),
            ),
            buildAttempt(
              'binh@fpt.edu.vn',
              id: 'ATM_MOI',
              occurredAt: kBaseTime.add(const Duration(minutes: 9)),
            ),
          ],
        ),
      );

      expect(summary.retryEvents.map((event) => event.id).toList(),
          ['ATM_MOI', 'ATM_CU']);
    });
  });

  group('Roster là mẫu số và không suy diễn khi thiếu dữ liệu', () {
    test('roster rỗng không tạo tỷ lệ giả', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(roster: const []),
      );

      expect(summary.hasRoster, isFalse);
      expect(summary.totalStudents, 0);
      expect(summary.attendanceRate, isNull);
      expect(summary.absentCount, 0);
    });

    test('lượt điểm danh ngoài roster không tính vào tỷ lệ của lớp', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn'),
            buildAttendance('nguoila@gmail.com', id: 'ATT_NGOAI'),
          ],
        ),
      );

      expect(summary.totalStudents, 3);
      expect(summary.presentCount, 1);
      expect(summary.unlistedSubmissions.single.email, 'nguoila@gmail.com');
    });

    test('tỷ lệ tính trên sĩ số roster', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(
          roster: roster,
          attendance: [
            buildAttendance('an@fpt.edu.vn', id: 'ATT_1'),
            buildAttendance('binh@fpt.edu.vn', id: 'ATT_2'),
          ],
        ),
      );

      expect(summary.attendanceRate, closeTo(2 / 3, 0.0001));
    });
  });

  group('Hợp nhất snapshot khi đọc lại', () {
    test('union theo id không nhân đôi cảnh báo', () {
      final first = buildResults(
        roster: roster,
        attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
        attempts: [buildAttempt('an@fpt.edu.vn', id: 'ATM_1')],
      );
      final second = buildResults(
        roster: roster,
        attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
        attempts: [
          buildAttempt('an@fpt.edu.vn', id: 'ATM_1'),
          buildAttempt('binh@fpt.edu.vn', id: 'ATM_2'),
        ],
      );

      final merged = first.mergeWith(second);

      expect(merged.attendance.length, 1);
      expect(merged.attempts.length, 2);
    });

    test('đọc lại thiếu dữ liệu không làm mất sự kiện đã có', () {
      final first = buildResults(
        roster: roster,
        attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
        attempts: [buildAttempt('an@fpt.edu.vn', id: 'ATM_1')],
      );
      final partial = buildResults(roster: roster);

      final merged = first.mergeWith(partial);

      expect(merged.attendance.length, 1);
      expect(merged.attempts.length, 1);
    });

    test('snapshot của phiên khác thay thế hoàn toàn', () {
      final first = buildResults(
        roster: roster,
        attendance: [buildAttendance('an@fpt.edu.vn', id: 'ATT_1')],
      );
      final other = buildResults(
        session: buildSession(id: 'SES_KHAC'),
        roster: roster,
        attendance: [
          buildAttendance('binh@fpt.edu.vn', id: 'ATT_9', sessionId: 'SES_KHAC'),
        ],
      );

      final merged = first.mergeWith(other);

      expect(merged.session.id, 'SES_KHAC');
      expect(merged.attendance.single.id, 'ATT_9');
    });
  });
}
