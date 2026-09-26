import 'attendance_result_model.dart';
import 'session_model.dart';

class TeachingOverview {
  const TeachingOverview({
    this.sessionRosters = const {},
    this.rosterSources = const {},
    required this.slots,
    required this.roster,
    required this.sessions,
    required this.attendance,
  });
  final Map<String, List<RosterEntry>> sessionRosters;
  final Map<String, String> rosterSources;
  final List<SessionSlot> slots;
  final List<RosterEntry> roster;
  final List<AttendanceSession> sessions;
  final List<AttendanceRecord> attendance;
  factory TeachingOverview.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) => (json[key] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return TeachingOverview(
      sessionRosters: (json['session_rosters'] as Map? ?? {}).map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List)
              .map(
                (r) =>
                    RosterEntry.fromJson(Map<String, dynamic>.from(r as Map)),
              )
              .toList(),
        ),
      ),
      rosterSources: (json['roster_sources'] as Map? ?? {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      slots: rows('slots').map(SessionSlot.fromJson).toList(),
      roster: rows('roster').map(RosterEntry.fromJson).toList(),
      sessions: rows('sessions').map(AttendanceSession.fromJson).toList(),
      attendance: rows('attendance').map(AttendanceRecord.fromJson).toList(),
    );
  }
  List<AttendanceSession> sessionsFor(SessionSlot slot) => sessions
      .where(
        (s) => s.slot.date == slot.date && s.slot.slotNumber == slot.slotNumber,
      )
      .toList();
  List<RosterEntry> get historicalRoster {
    final all = <String, RosterEntry>{};
    for (final list in [...sessionRosters.values, roster]) {
      for (final student in list) {
        all[student.id] = student;
      }
    }
    return all.values.toList()
      ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
  }

  List<RosterEntry> rosterFor(SessionSlot slot) {
    final matching = sessionsFor(slot);
    if (matching.isEmpty) return roster;
    final all = <String, RosterEntry>{};
    for (final session in matching) {
      for (final student in sessionRosters[session.id] ?? roster) {
        all[student.id] = student;
      }
    }
    return all.values.toList();
  }

  String status(RosterEntry student, SessionSlot slot) {
    final matching = sessionsFor(slot);
    if (matching.isEmpty) return '—';
    final enrolled = <AttendanceSession>[];
    for (final session in matching) {
      final member = (sessionRosters[session.id] ?? roster)
          .where((r) => r.id == student.id)
          .firstOrNull;
      if (member == null) continue;
      enrolled.add(session);
      if (attendance.any(
        (a) => a.sessionId == session.id && a.emailKey == member.emailKey,
      )) {
        return 'P';
      }
    }
    if (enrolled.isEmpty) return '∅';
    if (enrolled.any(
      (s) => (rosterSources[s.id] ?? 'legacy_live') != 'at_open',
    )) {
      return '?';
    }
    return enrolled.every((s) => s.status == SessionStatus.closed) ? 'A' : '…';
  }

  int present(SessionSlot slot) =>
      rosterFor(slot).where((r) => status(r, slot) == 'P').length;
}
