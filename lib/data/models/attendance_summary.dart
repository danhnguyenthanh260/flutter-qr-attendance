import 'attendance_result_model.dart';
import 'session_model.dart';

enum StudentAttendanceStatus { present, notYet, absent }

class StudentAttendanceRow {
  final RosterEntry student;
  final StudentAttendanceStatus status;
  final DateTime? acceptedAt;
  final int retryCount;
  final int rejectedCount;

  const StudentAttendanceRow({
    required this.student,
    required this.status,
    this.acceptedAt,
    this.retryCount = 0,
    this.rejectedCount = 0,
  });

  bool get isPresent => status == StudentAttendanceStatus.present;
  int get attemptCount => retryCount + rejectedCount;
}

class RetryEvent {
  final AttendanceAttempt attempt;
  final String displayName;
  final bool isOnRoster;
  final String? originalAttendanceId;
  final DateTime? originalAcceptedAt;

  const RetryEvent({
    required this.attempt,
    required this.displayName,
    required this.isOnRoster,
    this.originalAttendanceId,
    this.originalAcceptedAt,
  });

  String get id => attempt.id;
  String get sessionId => attempt.sessionId;
  DateTime? get occurredAt => attempt.occurredAt;
  bool get hasOriginalSubmission => originalAttendanceId != null;
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
  final List<RetryEvent> retryEvents;
  final List<UnlistedSubmission> unlistedSubmissions;
  final DateTime asOf;

  const AttendanceSummary({
    required this.scope,
    required this.session,
    required this.rows,
    required this.retryEvents,
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

  int get retryEventCount => retryEvents.length;

  int get retryStudentCount =>
      retryEvents.map((event) => event.attempt.emailKey).toSet().length;

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

    final retryCounts = <String, int>{};
    final rejectedCounts = <String, int>{};
    for (final attempt in results.attempts) {
      final counter =
          attempt.isRetryOfAcceptedSubmission ? retryCounts : rejectedCounts;
      counter[attempt.emailKey] = (counter[attempt.emailKey] ?? 0) + 1;
    }

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
        retryCount: retryCounts[student.emailKey] ?? 0,
        rejectedCount: rejectedCounts[student.emailKey] ?? 0,
      );
    }).toList()
      ..sort(_compareRows);

    final retryEvents = results.attempts.map((attempt) {
      final student = rosterByKey[attempt.emailKey];
      final accepted = acceptedByKey[attempt.emailKey];
      return RetryEvent(
        attempt: attempt,
        displayName: student?.displayName ??
            accepted?.displayName ??
            (attempt.email.isEmpty ? 'Không rõ' : attempt.email),
        isOnRoster: student != null,
        originalAttendanceId: accepted?.id,
        originalAcceptedAt: accepted?.acceptedAt,
      );
    }).toList()
      ..sort(_compareRetryEvents);

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
      retryEvents: List.unmodifiable(retryEvents),
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

  static int _compareRetryEvents(RetryEvent a, RetryEvent b) {
    final aAt = a.occurredAt;
    final bAt = b.occurredAt;
    if (aAt == null && bAt == null) return a.id.compareTo(b.id);
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    final byTime = bAt.compareTo(aAt);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
