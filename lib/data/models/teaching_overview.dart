import 'attendance_result_model.dart';
import 'session_model.dart';

class TeachingOverview {
  const TeachingOverview({
    required this.slots,
    required this.roster,
    required this.sessions,
    required this.attendance,
  });
  final List<SessionSlot> slots;
  final List<RosterEntry> roster;
  final List<AttendanceSession> sessions;
  final List<AttendanceRecord> attendance;
  factory TeachingOverview.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) => (json[key] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return TeachingOverview(
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
  String status(RosterEntry student, SessionSlot slot) {
    final matching = sessionsFor(slot);
    final ids = matching.map((s) => s.id).toSet();
    if (attendance.any(
      (a) => ids.contains(a.sessionId) && a.emailKey == student.emailKey,
    )) {
      return 'P';
    }
    if (matching.isEmpty) return '—';
    return matching.every((s) => s.status == SessionStatus.closed) ? 'A' : '…';
  }

  int present(SessionSlot slot) =>
      roster.where((r) => status(r, slot) == 'P').length;
}
