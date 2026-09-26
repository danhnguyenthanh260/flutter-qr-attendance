String attendanceToday({DateTime? now}) => (now ?? DateTime.now())
    .toUtc()
    .add(const Duration(hours: 7))
    .toIso8601String()
    .substring(0, 10);

bool isPastAttendanceDate(String date, {DateTime? now}) =>
    date.compareTo(attendanceToday(now: now)) < 0;
