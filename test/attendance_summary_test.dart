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

  group('Chống trùng khi đối chiếu roster', () {
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

  group('Phạm vi số liệu', () {
    test('scope bám đúng lớp, buổi và phiên đang xem', () {
      final summary = AttendanceSummary.fromSessionResults(
        buildResults(roster: roster),
      );

      expect(summary.scope.classId, kClassId);
      expect(summary.scope.sessionId, 'SES_1');
      expect(summary.scope.slotNumber, 2);
      expect(summary.scope.date, '2026-09-22');
      expect(summary.asOf, kBaseTime.add(const Duration(minutes: 10)));
    });
  });
}
