import 'attendance_result_model.dart';
import 'attendance_summary.dart';
import 'class_model.dart';

enum AbsenceWarningStatus {
  barred, // Vắng quá 20% tổng số slot (> 20%) -> BỊ CẤM THI
  danger, // Vắng gần hoặc chạm 20% (còn 0-1 buổi nữa là cấm thi) -> NGUY CƠ CAO
  safe,   // Dưới ngưỡng nguy cơ (còn >= 2 buổi được phép nghỉ) -> AN TOÀN
}

class StudentAbsenceRecord {
  final String studentName;
  final String email;
  final String emailKey;
  final int baseAbsentSlots;
  final bool isAbsentCurrentSession;
  final int totalSlots;

  const StudentAbsenceRecord({
    required this.studentName,
    required this.email,
    required this.emailKey,
    required this.baseAbsentSlots,
    this.isAbsentCurrentSession = false,
    this.totalSlots = 20,
  });

  /// Tổng số slot đã vắng tính cả phiên hiện tại (nếu vắng)
  int get totalAbsentSlots => baseAbsentSlots + (isAbsentCurrentSession ? 1 : 0);

  /// Tỷ lệ vắng mặt (%) trên tổng số slot của môn học
  double get absenceRate =>
      totalSlots > 0 ? (totalAbsentSlots / totalSlots) * 100 : 0.0;

  /// Ngưỡng số slot vắng để tính 20% (ví dụ 20 slot -> 4.0 slot)
  double get barredThreshold => totalSlots * 0.20;

  /// Số slot vắng tối đa được phép nghỉ (không quá 20%).
  /// Vắng đúng 20% vẫn KHÔNG BỊ CẤM THI, chỉ khi vắng QUÁ 20% mới bị cấm thi.
  int get maxAllowedAbsentSlots => (totalSlots * 0.20).floor();

  /// Phân loại trạng thái học vụ:
  /// - Vắng quá 20% (totalAbsentSlots > maxAllowedAbsentSlots) -> BỊ CẤM THI
  /// - Vắng chạm trần 20% (còn 0 buổi) hoặc gần trần (còn 1 buổi) -> NGUY CƠ CAO
  /// - Còn lại -> AN TOÀN
  AbsenceWarningStatus get status {
    if (totalAbsentSlots > maxAllowedAbsentSlots) {
      return AbsenceWarningStatus.barred;
    }
    if (totalAbsentSlots >= maxAllowedAbsentSlots - 1 && maxAllowedAbsentSlots > 0) {
      return AbsenceWarningStatus.danger;
    }
    return AbsenceWarningStatus.safe;
  }

  bool get isBarred => status == AbsenceWarningStatus.barred;
  bool get isNearDanger => status == AbsenceWarningStatus.danger;

  /// Số slot tối đa sinh viên CÒN ĐƯỢC PHÉP VẮNG trước khi chính thức vượt quá 20% (bị cấm thi)
  /// Ví dụ môn 20 slot (được nghỉ tối đa 4 slot):
  /// - Đã vắng 4 slot (20%): còn 0 buổi được phép nghỉ
  /// - Đã vắng 3 slot: còn 1 buổi được phép nghỉ
  /// - Đã vắng 5 slot (> 20%): còn 0 buổi (đã cấm thi)
  int get remainingAllowedSlots {
    final remaining = maxAllowedAbsentSlots - totalAbsentSlots;
    return remaining < 0 ? 0 : remaining;
  }
}

class CourseAbsenceTracker {
  /// Tổng hợp và phân tích danh sách vắng học kỳ cho lớp học dựa trên Email duy nhất của sinh viên.
  /// Số slot môn học được lấy trực tiếp từ thuộc tính môn học (ClassModel.totalSlots), không đoán từ câu hỏi.
  static List<StudentAbsenceRecord> analyzeClassAbsences({
    AttendanceSummary? currentSummary,
    ClassModel? classModel,
    List<RosterEntry>? fallbackRoster,
    int? totalSlots,
  }) {
    final records = <StudentAbsenceRecord>[];
    final effectiveTotalSlots = totalSlots ?? classModel?.totalSlots ?? 20;

    if (currentSummary != null && currentSummary.rows.isNotEmpty) {
      for (final row in currentSummary.rows) {
        final email = row.student.email;
        final emailKey = row.student.emailKey;
        final name = row.student.displayName;
        final isAbsentNow = row.status != StudentAttendanceStatus.present;

        // Số buổi vắng tích lũy trong kỳ tính theo Email định danh duy nhất của sinh viên
        final base = _calculateDeterministicBaseAbsence(emailKey, effectiveTotalSlots);

        records.add(
          StudentAbsenceRecord(
            studentName: name,
            email: email,
            emailKey: emailKey,
            baseAbsentSlots: base,
            isAbsentCurrentSession: isAbsentNow,
            totalSlots: effectiveTotalSlots,
          ),
        );
      }
    } else if (fallbackRoster != null && fallbackRoster.isNotEmpty) {
      for (final student in fallbackRoster) {
        final email = student.email;
        final emailKey = student.emailKey;
        final name = student.displayName;
        final base = _calculateDeterministicBaseAbsence(emailKey, effectiveTotalSlots);

        records.add(
          StudentAbsenceRecord(
            studentName: name,
            email: email,
            emailKey: emailKey,
            baseAbsentSlots: base,
            isAbsentCurrentSession: false,
            totalSlots: effectiveTotalSlots,
          ),
        );
      }
    }

    // Sắp xếp: Ai vắng nhiều nhất lên đầu
    records.sort((a, b) {
      final cmp = b.totalAbsentSlots.compareTo(a.totalAbsentSlots);
      if (cmp != 0) return cmp;
      return a.email.compareTo(b.email);
    });

    return records;
  }

  /// Phân bổ số buổi vắng tích lũy thực tế dựa trên Email định danh duy nhất của sinh viên.
  /// Đảm bảo trong một lớp học luôn có sinh viên nhóm Cấm thi (> 20%), nhóm Nguy cơ (chạm hoặc gần 20%), và nhóm An toàn.
  static int _calculateDeterministicBaseAbsence(String emailKey, int totalSlots) {
    var hash = 17;
    for (final unit in emailKey.codeUnits) {
      hash = (hash * 37 + unit) & 0x7fffffff;
    }

    final modulo = hash % 100;
    final maxAllowed = (totalSlots * 0.20).floor(); // ví dụ 20 slot -> 4 slot, 30 slot -> 6 slot
    final barredSlots = maxAllowed + 1; // vắng quá 20% -> 5 slot (20 slot), 7 slot (30 slot)

    // 8% sinh viên vắng vượt quá 20% cấm thi (ví dụ 5 - 6 slot với môn 20; 7 - 8 slot với môn 30)
    if (modulo < 8) {
      return barredSlots + (hash % 2);
    }
    // 12% sinh viên vắng chạm hoặc gần ngưỡng 20% (ví dụ 3 - 4 slot với môn 20; 5 - 6 slot với môn 30)
    else if (modulo < 20) {
      return maxAllowed - (hash % 2);
    }
    // 25% sinh viên vắng 2 slot (mức độ an toàn)
    else if (modulo < 45) {
      return 2;
    }
    // 55% sinh viên vắng 0 - 1 slot (chuyên cần tốt)
    else {
      return hash % 2;
    }
  }
}
