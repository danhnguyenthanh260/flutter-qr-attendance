import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_qr_attendance/data/models/attendance_result_model.dart';
import 'package:flutter_qr_attendance/data/models/class_model.dart';
import 'package:flutter_qr_attendance/data/models/student_absence_warning.dart';

void main() {
  group('StudentAbsenceRecord Tests', () {
    test('Calculates total absences and rate correctly without current absence', () {
      const record = StudentAbsenceRecord(
        studentName: 'Nguyễn Văn A',
        email: 'anndse1701@fpt.edu.vn',
        emailKey: 'anndse1701',
        baseAbsentSlots: 5,
        isAbsentCurrentSession: false,
        totalSlots: 30,
      );

      expect(record.totalAbsentSlots, 5);
      expect(record.absenceRate, closeTo(16.67, 0.01));
      expect(record.isBarred, isFalse);
      expect(record.isNearDanger, isTrue);
      expect(record.remainingAllowedSlots, 1);
    });

    test('Student with exactly 20% absence is NOT barred (remains in danger with 0 allowed slots left)', () {
      const record = StudentAbsenceRecord(
        studentName: 'Trần Thị B',
        email: 'binhttse1702@fpt.edu.vn',
        emailKey: 'binhttse1702',
        baseAbsentSlots: 5,
        isAbsentCurrentSession: true,
        totalSlots: 30,
      );

      expect(record.totalAbsentSlots, 6);
      expect(record.absenceRate, 20.0);
      expect(record.isBarred, isFalse); // Vắng đúng 20% vẫn KHÔNG bị cấm thi
      expect(record.isNearDanger, isTrue); // Chạm trần nguy cơ cao
      expect(record.status, AbsenceWarningStatus.danger);
      expect(record.remainingAllowedSlots, 0); // Còn 0 buổi được nghỉ
    });

    test('Student exceeding 20% absence is barred from exam', () {
      const record = StudentAbsenceRecord(
        studentName: 'Trần Thị B',
        email: 'binhttse1702@fpt.edu.vn',
        emailKey: 'binhttse1702',
        baseAbsentSlots: 6,
        isAbsentCurrentSession: true,
        totalSlots: 30,
      );

      expect(record.totalAbsentSlots, 7);
      expect(record.absenceRate, closeTo(23.33, 0.01));
      expect(record.isBarred, isTrue); // Vắng quá 20% -> BỊ CẤM THI
      expect(record.isNearDanger, isFalse);
      expect(record.status, AbsenceWarningStatus.barred);
      expect(record.remainingAllowedSlots, 0);
    });

    test('Marks student as safe when absences are well below 20%', () {
      const record = StudentAbsenceRecord(
        studentName: 'Lê Hoàng C',
        email: 'cleh@fpt.edu.vn',
        emailKey: 'cleh',
        baseAbsentSlots: 1,
        isAbsentCurrentSession: false,
        totalSlots: 30,
      );

      expect(record.totalAbsentSlots, 1);
      expect(record.status, AbsenceWarningStatus.safe);
      expect(record.isBarred, isFalse);
      expect(record.isNearDanger, isFalse);
      expect(record.remainingAllowedSlots, 5);
    });

    test('Supports custom total slots (e.g. 20 slots where max allowed is 4, barred when >= 5)', () {
      const record20Safe = StudentAbsenceRecord(
        studentName: 'Phạm Đức D',
        email: 'duclp@fpt.edu.vn',
        emailKey: 'duclp',
        baseAbsentSlots: 4,
        isAbsentCurrentSession: false,
        totalSlots: 20,
      );

      expect(record20Safe.barredThreshold, 4.0);
      expect(record20Safe.maxAllowedAbsentSlots, 4);
      expect(record20Safe.totalAbsentSlots, 4);
      expect(record20Safe.absenceRate, 20.0);
      expect(record20Safe.isBarred, isFalse); // 4/20 = 20% -> KHÔNG cấm thi
      expect(record20Safe.isNearDanger, isTrue);
      expect(record20Safe.remainingAllowedSlots, 0);

      const record20Barred = StudentAbsenceRecord(
        studentName: 'Phạm Đức D',
        email: 'duclp@fpt.edu.vn',
        emailKey: 'duclp',
        baseAbsentSlots: 5,
        isAbsentCurrentSession: false,
        totalSlots: 20,
      );
      expect(record20Barred.isBarred, isTrue); // 5/20 = 25% > 20% -> CẤM THI
    });
  });

  group('CourseAbsenceTracker Tests', () {
    test('Uses ClassModel.totalSlots directly when provided', () {
      const classModel = ClassModel(
        id: 'CLASS_TEST',
        name: 'PRM392',
        courseCode: 'PRM392',
        room: 'BE-301',
        totalStudents: 30,
        scheduleDescription: 'Mon, Thu',
        totalSlots: 45,
      );
      final roster = [
        const RosterEntry(
          id: 'ROS_1',
          classId: 'CLASS_TEST',
          email: 'student1@fpt.edu.vn',
          emailKey: 'student1',
          studentName: 'Sinh viên Một',
        ),
      ];

      final results = CourseAbsenceTracker.analyzeClassAbsences(
        fallbackRoster: roster,
        classModel: classModel,
      );

      expect(results.first.totalSlots, 45);
      expect(results.first.barredThreshold, 9.0);
    });

    test('Defaults to 20 slots when classModel is null or totalSlots not specified', () {
      final roster = [
        const RosterEntry(
          id: 'ROS_1',
          classId: 'CLASS_TEST',
          email: 'student1@fpt.edu.vn',
          emailKey: 'student1',
          studentName: 'Sinh viên Một',
        ),
      ];

      final results = CourseAbsenceTracker.analyzeClassAbsences(
        fallbackRoster: roster,
      );

      expect(results.first.totalSlots, 20);
      expect(results.first.barredThreshold, 4.0);
    });

    test('Analyzes class absences and keys strictly on unique email', () {
      final roster = [
        const RosterEntry(
          id: 'ROS_1',
          classId: 'CLASS_TEST',
          email: 'student1@fpt.edu.vn',
          emailKey: 'student1',
          studentName: 'Sinh viên Một',
        ),
        const RosterEntry(
          id: 'ROS_2',
          classId: 'CLASS_TEST',
          email: 'student2@fpt.edu.vn',
          emailKey: 'student2',
          studentName: 'Sinh viên Hai',
        ),
      ];

      final results = CourseAbsenceTracker.analyzeClassAbsences(
        fallbackRoster: roster,
        totalSlots: 30,
      );

      expect(results.length, 2);
      expect(results.every((r) => r.email.contains('@fpt.edu.vn')), isTrue);
      // Ensure unique emailKeys are preserved
      final emailKeys = results.map((r) => r.emailKey).toSet();
      expect(emailKeys.length, 2);
    });
  });
}
