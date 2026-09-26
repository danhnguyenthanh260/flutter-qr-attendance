import 'attendance_result_model.dart';
import 'session_model.dart';

enum StudentAttendanceStatus { present, notYet, absent }

class StudentAttendanceRow {
  final RosterEntry student;
  final StudentAttendanceStatus status;
  final DateTime? acceptedAt;
  final String? acceptedSessionId;
  final int retryCount;
  final int rejectedCount;

  const StudentAttendanceRow({
    required this.student,
    required this.status,
    this.acceptedAt,
    this.acceptedSessionId,
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
  final List<String> sessionIds;

  const AttendanceScope({
    required this.classId,
    required this.className,
    required this.date,
    required this.slotNumber,
    required this.timeRange,
    required this.sessionIds,
  });

  String get label => '$className · Slot $slotNumber · $date';
}

class AttendanceSummary {
  final bool hasLegacyRoster;
  final AttendanceScope scope;
  final List<AttendanceSession> sessions;
  final List<StudentAttendanceRow> rows;
  final List<RetryEvent> retryEvents;
  final List<UnlistedSubmission> unlistedSubmissions;
  final bool rosterChangedBetweenSessions;
  final DateTime asOf;

  const AttendanceSummary({
    this.hasLegacyRoster = false,
    required this.scope,
    required this.sessions,
    required this.rows,
    required this.retryEvents,
    required this.unlistedSubmissions,
    required this.rosterChangedBetweenSessions,
    required this.asOf,
  });

  bool get isFinalized =>
      sessions.isNotEmpty &&
      sessions.every((session) => session.status == SessionStatus.closed);

  bool get isSettling =>
      sessions.any((session) => session.status == SessionStatus.closing);

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
    return AttendanceSummary.fromMultipleSessions([results], asOf: asOf);
  }

  factory AttendanceSummary.fromMultipleSessions(
    List<SessionResults> snapshots, {
    DateTime? asOf,
  }) {
    if (snapshots.isEmpty) {
      throw ArgumentError.value(
        snapshots,
        'snapshots',
        'At least one session snapshot is required to build a summary.',
      );
    }

    final ordered = [...snapshots]
      ..sort((a, b) => a.session.openedAt.compareTo(b.session.openedAt));
    final sessions = ordered.map((snapshot) => snapshot.session).toList();
    final reference = ordered.first.session;

    final roster = _mergeRosters(ordered);
    final rosterByKey = {
      for (final snapshot in ordered)
        for (final entry in snapshot.roster) entry.emailKey: entry,
    };
    final acceptedByKey = _earliestAcceptedByEmail(ordered);
    final attempts = _allAttempts(ordered);

    final legacyRoster = ordered.any((s) => s.rosterSnapshotKind != 'at_open');
    final finalized =
        !legacyRoster &&
        sessions.every((session) => session.status == SessionStatus.closed);

    final retryCounts = <String, int>{};
    final rejectedCounts = <String, int>{};
    for (final attempt in attempts) {
      final counter = attempt.isRetryOfAcceptedSubmission
          ? retryCounts
          : rejectedCounts;
      counter[attempt.emailKey] = (counter[attempt.emailKey] ?? 0) + 1;
    }

    final rows = roster.map((student) {
      AttendanceRecord? accepted;
      for (final snapshot in ordered) {
        final member = snapshot.roster
            .where((r) => r.id == student.id)
            .firstOrNull;
        if (member == null) continue;
        for (final record in snapshot.attendance.where(
          (a) => a.emailKey == member.emailKey,
        )) {
          if (accepted == null || _isEarlier(record, accepted)) {
            accepted = record;
          }
        }
      }
      final status = accepted != null
          ? StudentAttendanceStatus.present
          : finalized
          ? StudentAttendanceStatus.absent
          : StudentAttendanceStatus.notYet;

      return StudentAttendanceRow(
        student: student,
        status: status,
        acceptedAt: accepted?.acceptedAt,
        acceptedSessionId: accepted?.sessionId,
        retryCount: retryCounts[student.emailKey] ?? 0,
        rejectedCount: rejectedCounts[student.emailKey] ?? 0,
      );
    }).toList()..sort(_compareRows);

    final retryEvents = attempts.map((attempt) {
      final student = rosterByKey[attempt.emailKey];
      final accepted = acceptedByKey[attempt.emailKey];
      return RetryEvent(
        attempt: attempt,
        displayName:
            student?.displayName ??
            accepted?.displayName ??
            (attempt.email.isEmpty ? 'Không rõ' : attempt.email),
        isOnRoster: student != null,
        originalAttendanceId: accepted?.id,
        originalAcceptedAt: accepted?.acceptedAt,
      );
    }).toList()..sort(_compareRetryEvents);

    final unlisted =
        acceptedByKey.entries
            .where((entry) => !rosterByKey.containsKey(entry.key))
            .map((entry) => UnlistedSubmission(entry.value))
            .toList()
          ..sort((a, b) => a.email.compareTo(b.email));

    return AttendanceSummary(
      hasLegacyRoster: legacyRoster,
      scope: AttendanceScope(
        classId: reference.classId,
        className: reference.className,
        date: reference.slot.date,
        slotNumber: reference.slot.slotNumber,
        timeRange: reference.slot.timeRange,
        sessionIds: sessions
            .map((session) => session.id)
            .toList(growable: false),
      ),
      sessions: List.unmodifiable(sessions),
      rows: List.unmodifiable(rows),
      retryEvents: List.unmodifiable(retryEvents),
      unlistedSubmissions: List.unmodifiable(unlisted),
      rosterChangedBetweenSessions: _rosterChanged(ordered),
      asOf:
          asOf ?? ordered.map((snapshot) => snapshot.fetchedAt).reduce(_latest),
    );
  }

  static DateTime _latest(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static List<RosterEntry> _mergeRosters(List<SessionResults> ordered) {
    final merged = <String, RosterEntry>{};
    for (final snapshot in ordered) {
      for (final entry in snapshot.roster) {
        merged[entry.id] = entry;
      }
    }
    return merged.values.toList(growable: false);
  }

  static bool _rosterChanged(List<SessionResults> ordered) {
    if (ordered.length < 2) return false;
    final first = ordered.first.roster.map((entry) => entry.emailKey).toSet();
    return ordered.any(
      (snapshot) => !_setEquals(
        snapshot.roster.map((entry) => entry.emailKey).toSet(),
        first,
      ),
    );
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static Map<String, AttendanceRecord> _earliestAcceptedByEmail(
    List<SessionResults> ordered,
  ) {
    final accepted = <String, AttendanceRecord>{};
    for (final snapshot in ordered) {
      for (final record in snapshot.attendance) {
        if (record.emailKey.isEmpty) continue;
        final current = accepted[record.emailKey];
        if (current == null || _isEarlier(record, current)) {
          accepted[record.emailKey] = record;
        }
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

  static List<AttendanceAttempt> _allAttempts(List<SessionResults> ordered) {
    final attempts = <String, AttendanceAttempt>{};
    for (final snapshot in ordered) {
      for (final attempt in snapshot.attempts) {
        attempts[attempt.id] = attempt;
      }
    }
    return attempts.values.toList(growable: false);
  }

  static int _compareRows(StudentAttendanceRow a, StudentAttendanceRow b) {
    final byName = a.student.displayName.toLowerCase().compareTo(
      b.student.displayName.toLowerCase(),
    );
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
