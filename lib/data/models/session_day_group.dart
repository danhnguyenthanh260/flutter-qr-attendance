import 'session_model.dart';

class SessionDayGroup {
  final String key;
  final String classId;
  final String className;
  final String date;
  final int slotNumber;
  final String timeRange;
  final List<AttendanceSession> sessions;

  const SessionDayGroup({
    required this.key,
    required this.classId,
    required this.className,
    required this.date,
    required this.slotNumber,
    required this.timeRange,
    required this.sessions,
  });

  int get sessionCount => sessions.length;

  bool get isFinalized =>
      sessions.isNotEmpty &&
      sessions.every((session) => session.status == SessionStatus.closed);

  bool get isSettling =>
      sessions.any((session) => session.status == SessionStatus.closing);

  bool get hasOpenSession =>
      sessions.any((session) => session.status == SessionStatus.active);

  DateTime get firstOpenedAt => sessions
      .map((session) => session.openedAt)
      .reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime? get lastClosedAt {
    final closed = sessions
        .map((session) => session.closedAt)
        .whereType<DateTime>()
        .toList();
    if (closed.isEmpty) return null;
    return closed.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<String> get sessionIds =>
      sessions.map((session) => session.id).toList(growable: false);

  static String keyFor(AttendanceSession session) =>
      '${session.classId}|${session.slot.date}|${session.slot.slotNumber}';

  static List<SessionDayGroup> fromSessions(List<AttendanceSession> sessions) {
    final buckets = <String, List<AttendanceSession>>{};
    for (final session in sessions) {
      buckets.putIfAbsent(keyFor(session), () => []).add(session);
    }

    final groups = buckets.entries.map((entry) {
      final items = [...entry.value]
        ..sort((a, b) => a.openedAt.compareTo(b.openedAt));
      final reference = items.first;
      return SessionDayGroup(
        key: entry.key,
        classId: reference.classId,
        className: reference.className,
        date: reference.slot.date,
        slotNumber: reference.slot.slotNumber,
        timeRange: reference.slot.timeRange,
        sessions: List.unmodifiable(items),
      );
    }).toList();

    groups.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      return a.slotNumber.compareTo(b.slotNumber);
    });

    return List.unmodifiable(groups);
  }
}
