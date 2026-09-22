import 'attendance_result_model.dart';
import 'session_model.dart';

enum StudentAttendanceStatus { present, notYet, absent }

class StudentAttendanceRow {
  final RosterEntry student;
  final StudentAttendanceStatus status;
  final DateTime? acceptedAt;

  const StudentAttendanceRow({
    required this.student,
    required this.status,
    this.acceptedAt,
  });

  bool get isPresent => status == StudentAttendanceStatus.present;
}

class UnlistedSubmission {
  final AttendanceRecord record;

  const UnlistedSubmission(this.record);

  String get email => record.email;
  DateTime? get acceptedAt => record.acceptedAt;
}

class AttendanceScope {
  final String classId;
  final String className;
  final String date;
  final int slotNumber;
  final String timeRange;
  final String sessionId;

  const AttendanceScope({
    required this.classId,
    required this.className,
    required this.date,
    required this.slotNumber,
    required this.timeRange,
    required this.sessionId,
  });

  String get label => '$className · Slot $slotNumber · $date';
}

class AttendanceSummary {
  final AttendanceScope scope;
  final AttendanceSession session;
  final List<StudentAttendanceRow> rows;
  final List<UnlistedSubmission> unlistedSubmissions;
  final DateTime asOf;

  const AttendanceSummary({
    required this.scope,
    required this.session,
    required this.rows,
    required this.unlistedSubmissions,
    required this.asOf,
  });

  bool get isFinalized => session.status == SessionStatus.closed;

  bool get isSettling => session.status == SessionStatus.closing;

  bool get isProvisional => !isFinalized;

  bool get hasRoster => rows.isNotEmpty;

  int get totalStudents => rows.length;

  int get presentCount =>
      rows.where((row) => row.status == StudentAttendanceStatus.present).length;

  int get notYetCount =>
      rows.where((row) => row.status == StudentAttendanceStatus.notYet).length;

  int get absentCount =>
      rows.where((row) => row.status == StudentAttendanceStatus.absent).length;

  int get pendingCount => isFinalized ? absentCount : notYetCount;

  double? get attendanceRate =>
      totalStudents == 0 ? null : presentCount / totalStudents;

  factory AttendanceSummary.fromSessionResults(
    SessionResults results, {
    DateTime? asOf,
  }) {
    final session = results.session;
    final rosterByKey = {
      for (final entry in results.roster) entry.emailKey: entry,
    };
    final acceptedByKey = _earliestAcceptedByEmail(results.attendance);
    final finalized = session.status == SessionStatus.closed;

    final rows = results.roster.map((student) {
      final accepted = acceptedByKey[student.emailKey];
      final status = accepted != null
          ? StudentAttendanceStatus.present
          : finalized
              ? StudentAttendanceStatus.absent
              : StudentAttendanceStatus.notYet;

      return StudentAttendanceRow(
        student: student,
        status: status,
        acceptedAt: accepted?.acceptedAt,
      );
    }).toList()
      ..sort(_compareRows);

    final unlisted = acceptedByKey.entries
        .where((entry) => !rosterByKey.containsKey(entry.key))
        .map((entry) => UnlistedSubmission(entry.value))
        .toList()
      ..sort((a, b) => a.email.compareTo(b.email));

    return AttendanceSummary(
      scope: AttendanceScope(
        classId: session.classId,
        className: session.className,
        date: session.slot.date,
        slotNumber: session.slot.slotNumber,
        timeRange: session.slot.timeRange,
        sessionId: session.id,
      ),
      session: session,
      rows: List.unmodifiable(rows),
      unlistedSubmissions: List.unmodifiable(unlisted),
      asOf: asOf ?? results.fetchedAt,
    );
  }

  static Map<String, AttendanceRecord> _earliestAcceptedByEmail(
    List<AttendanceRecord> records,
  ) {
    final accepted = <String, AttendanceRecord>{};
    for (final record in records) {
      if (record.emailKey.isEmpty) continue;
      final current = accepted[record.emailKey];
      if (current == null || _isEarlier(record, current)) {
        accepted[record.emailKey] = record;
      }
    }
    return accepted;
  }

  static bool _isEarlier(AttendanceRecord candidate, AttendanceRecord current) {
    final candidateAt = candidate.acceptedAt;
    final currentAt = current.acceptedAt;
    if (candidateAt == null) return false;
    if (currentAt == null) return true;
    return candidateAt.isBefore(currentAt);
  }

  static int _compareRows(StudentAttendanceRow a, StudentAttendanceRow b) {
    final byName = a.student.displayName
        .toLowerCase()
        .compareTo(b.student.displayName.toLowerCase());
    return byName != 0 ? byName : a.student.email.compareTo(b.student.email);
  }
}
