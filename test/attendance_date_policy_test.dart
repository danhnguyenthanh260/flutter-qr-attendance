import 'package:flutter_qr_attendance/features/teaching/attendance_date_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vietnam midnight separates past, today and future', () {
    final now = DateTime.parse('2026-09-26T17:00:00Z');
    expect(attendanceToday(now: now), '2026-09-27');
    expect(isPastAttendanceDate('2026-09-26', now: now), isTrue);
    expect(isPastAttendanceDate('2026-09-27', now: now), isFalse);
    expect(isPastAttendanceDate('2026-09-28', now: now), isFalse);
  });
}
