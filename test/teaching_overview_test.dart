import 'package:flutter_qr_attendance/data/models/attendance_result_model.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/models/teaching_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lesson matrix separates dates and slots and does not mark unopened lessons absent', () {
    const slot = SessionSlot(
      slotNumber: 1,
      timeRange: '07:00–08:30',
      date: '2026-09-26',
    );
    const other = SessionSlot(
      slotNumber: 2,
      timeRange: '09:00–10:30',
      date: '2026-09-26',
    );
    const student = RosterEntry(
      id: 'r',
      classId: 'c',
      email: 'a@example.edu',
      emailKey: 'a@example.edu',
    );
    final session = AttendanceSession(
      id: 's',
      classId: 'c',
      className: 'Class',
      slot: slot,
      openedAt: DateTime(2026, 9, 26),
    );
    TeachingOverview data(
      SessionStatus status,
      List<AttendanceRecord> records,
    ) => TeachingOverview(
      slots: [slot, other],
      roster: [student],
      sessions: [session.copyWith(status: status)],
      attendance: records,
    );
    expect(data(SessionStatus.active, []).status(student, slot), '…');
    expect(data(SessionStatus.closed, []).status(student, slot), 'A');
    expect(data(SessionStatus.closed, []).status(student, other), '—');
    final accepted = data(SessionStatus.closed, [
      const AttendanceRecord(
        id: 'a',
        sessionId: 's',
        email: 'a@example.edu',
        emailKey: 'a@example.edu',
      ),
    ]);
    expect(accepted.status(student, slot), 'P');
    expect(accepted.present(slot), 1);
    expect(accepted.present(other), 0);
  });
}
