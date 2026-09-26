import 'session_model.dart';

String normalizeEmailKey(String? email) => (email ?? '').trim().toLowerCase();

String? _blankToNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _parseTimestamp(dynamic value) {
  final text = _blankToNull(value);
  if (text == null) return null;
  return DateTime.tryParse(text);
}

String _displayNameFor(String? studentName, String email) {
  final name = _blankToNull(studentName);
  if (name != null) return name;
  final at = email.indexOf('@');
  return at > 0 ? email.substring(0, at) : email;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

class RosterEntry {
  final String memberCode;
  final bool isActive;
  final String rollNumber;
  final String id;
  final String classId;
  final String email;
  final String emailKey;
  final String? studentName;

  const RosterEntry({
    this.rollNumber = '',
    this.memberCode = '',
    this.isActive = true,
    required this.id,
    required this.classId,
    required this.email,
    required this.emailKey,
    this.studentName,
  });

  String get displayName => _displayNameFor(studentName, email);

  factory RosterEntry.fromJson(Map<String, dynamic> json) {
    final email = _blankToNull(json['email']) ?? '';
    return RosterEntry(
      rollNumber: _blankToNull(json['roll_number']) ?? '',
      memberCode: _blankToNull(json['member_code']) ?? '',
      isActive:
          json['is_active'] == null ||
          json['is_active'].toString().toLowerCase() == 'true',
      id: _blankToNull(json['id']) ?? email,
      classId: _blankToNull(json['class_id']) ?? '',
      email: email,
      emailKey:
          _blankToNull(json['email_key'])?.toLowerCase() ??
          normalizeEmailKey(email),
      studentName: _blankToNull(json['student_name']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'class_id': classId,
    'roll_number': rollNumber,
    'member_code': memberCode,
    'is_active': isActive,
    'email': email,
    'email_key': emailKey,
    'student_name': studentName,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RosterEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String? formResponseId;
  final String email;
  final String emailKey;
  final String? studentName;
  final DateTime? acceptedAt;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    this.formResponseId,
    required this.email,
    required this.emailKey,
    this.studentName,
    this.acceptedAt,
  });

  String get displayName => _displayNameFor(studentName, email);

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final email = _blankToNull(json['email']) ?? '';
    return AttendanceRecord(
      id: _blankToNull(json['id']) ?? '',
      sessionId: _blankToNull(json['session_id']) ?? '',
      formResponseId: _blankToNull(json['form_response_id']),
      email: email,
      emailKey:
          _blankToNull(json['email_key'])?.toLowerCase() ??
          normalizeEmailKey(email),
      studentName: _blankToNull(json['student_name']),
      acceptedAt: _parseTimestamp(json['accepted_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'form_response_id': formResponseId,
    'email': email,
    'email_key': emailKey,
    'student_name': studentName,
    'accepted_at': acceptedAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class AttendanceAttempt {
  final String id;
  final String sessionId;
  final String? formResponseId;
  final String email;
  final String emailKey;
  final String attemptType;
  final String? reason;
  final DateTime? occurredAt;

  const AttendanceAttempt({
    required this.id,
    required this.sessionId,
    this.formResponseId,
    required this.email,
    required this.emailKey,
    required this.attemptType,
    this.reason,
    this.occurredAt,
  });

  bool get isRetryOfAcceptedSubmission =>
      attemptType == 'duplicate_email' || attemptType == 'grant_replayed';

  factory AttendanceAttempt.fromJson(Map<String, dynamic> json) {
    final email = _blankToNull(json['email']) ?? '';
    return AttendanceAttempt(
      id: _blankToNull(json['id']) ?? '',
      sessionId: _blankToNull(json['session_id']) ?? '',
      formResponseId: _blankToNull(json['form_response_id']),
      email: email,
      emailKey:
          _blankToNull(json['email_key'])?.toLowerCase() ??
          normalizeEmailKey(email),
      attemptType: _blankToNull(json['attempt_type']) ?? 'unknown',
      reason: _blankToNull(json['reason']),
      occurredAt: _parseTimestamp(json['occurred_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'form_response_id': formResponseId,
    'email': email,
    'email_key': emailKey,
    'attempt_type': attemptType,
    'reason': reason,
    'occurred_at': occurredAt?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceAttempt &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SessionResults {
  final String rosterSnapshotKind;
  final AttendanceSession session;
  final List<RosterEntry> roster;
  final List<AttendanceRecord> attendance;
  final List<AttendanceAttempt> attempts;
  final DateTime fetchedAt;

  const SessionResults({
    this.rosterSnapshotKind = 'at_open',
    required this.session,
    required this.roster,
    required this.attendance,
    required this.attempts,
    required this.fetchedAt,
  });

  factory SessionResults.fromJson(
    Map<String, dynamic> json, {
    DateTime? fetchedAt,
  }) {
    final rawSession = json['session'];
    if (rawSession is! Map) {
      throw const FormatException(
        'session_results response is missing the session object',
      );
    }

    return SessionResults(
      rosterSnapshotKind:
          json['roster_snapshot_kind'] as String? ?? 'legacy_live',
      session: AttendanceSession.fromJson(
        Map<String, dynamic>.from(rawSession),
      ),
      roster: _mapList(json['roster'])
          .map(RosterEntry.fromJson)
          .toList(growable: false),
      attendance: _mapList(json['attendance'])
          .map(AttendanceRecord.fromJson)
          .toList(growable: false),
      attempts: _mapList(json['attempts'])
          .map(AttendanceAttempt.fromJson)
          .toList(growable: false),
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'roster_snapshot_kind': rosterSnapshotKind,
    'session': session.toJson(),
    'roster': roster.map((item) => item.toJson()).toList(),
    'attendance': attendance.map((item) => item.toJson()).toList(),
    'attempts': attempts.map((item) => item.toJson()).toList(),
  };

  SessionResults mergeWith(SessionResults newer) {
    if (newer.session.id != session.id) {
      return newer;
    }

    return SessionResults(
      rosterSnapshotKind: newer.rosterSnapshotKind,
      session: newer.session,
      roster: newer.roster,
      attendance: _unionById(attendance, newer.attendance, (item) => item.id),
      attempts: _unionById(attempts, newer.attempts, (item) => item.id),
      fetchedAt: newer.fetchedAt,
    );
  }

  static List<T> _unionById<T>(
    List<T> previous,
    List<T> next,
    String Function(T) idOf,
  ) {
    final merged = <String, T>{};
    for (final item in previous) {
      merged[idOf(item)] = item;
    }
    for (final item in next) {
      merged[idOf(item)] = item;
    }
    return List<T>.unmodifiable(merged.values);
  }
}
