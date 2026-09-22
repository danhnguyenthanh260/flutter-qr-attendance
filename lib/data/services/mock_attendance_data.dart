import '../models/attendance_result_model.dart';
import '../models/class_model.dart';
import '../models/session_model.dart';
import 'attendance_api_exception.dart';

const Map<int, String> kMockSlotTimeRanges = {
  1: '07:30 - 09:00',
  2: '09:15 - 10:45',
  3: '12:30 - 14:00',
  4: '14:15 - 15:45',
};

const Map<int, int> _slotStartMinutes = {
  1: 7 * 60 + 30,
  2: 9 * 60 + 15,
  3: 12 * 60 + 30,
  4: 14 * 60 + 15,
};

const List<String> _surnames = [
  'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ',
  'Võ', 'Đặng', 'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương', 'Lý',
];

const List<String> _middleNames = [
  'Văn', 'Thị', 'Hữu', 'Đức', 'Minh', 'Thanh', 'Quang', 'Hoài',
  'Gia', 'Khánh', 'Ngọc', 'Thu', 'Anh', 'Bảo', 'Tuấn', 'Xuân',
];

const List<String> _givenNames = [
  'An', 'Bình', 'Cường', 'Dũng', 'Duy', 'Giang', 'Hà', 'Hải',
  'Hạnh', 'Hiếu', 'Hùng', 'Huy', 'Khoa', 'Lâm', 'Linh', 'Long',
  'Mai', 'Nam', 'Nga', 'Ngân', 'Nhung', 'Phong', 'Phúc', 'Quân',
  'Quỳnh', 'Sơn', 'Tài', 'Tâm', 'Thảo', 'Thắng', 'Trang', 'Trung',
  'Tuấn', 'Vy', 'Yến', 'Đạt',
];

const Map<String, String> _asciiFolding = {
  'à': 'a', 'á': 'a', 'ạ': 'a', 'ả': 'a', 'ã': 'a', 'â': 'a', 'ầ': 'a',
  'ấ': 'a', 'ậ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ă': 'a', 'ằ': 'a', 'ắ': 'a',
  'ặ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'è': 'e', 'é': 'e', 'ẹ': 'e', 'ẻ': 'e',
  'ẽ': 'e', 'ê': 'e', 'ề': 'e', 'ế': 'e', 'ệ': 'e', 'ể': 'e', 'ễ': 'e',
  'ì': 'i', 'í': 'i', 'ị': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ò': 'o', 'ó': 'o',
  'ọ': 'o', 'ỏ': 'o', 'õ': 'o', 'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ộ': 'o',
  'ổ': 'o', 'ỗ': 'o', 'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ợ': 'o', 'ở': 'o',
  'ỡ': 'o', 'ù': 'u', 'ú': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u', 'ư': 'u',
  'ừ': 'u', 'ứ': 'u', 'ự': 'u', 'ử': 'u', 'ữ': 'u', 'ỳ': 'y', 'ý': 'y',
  'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'đ': 'd',
};

String _toAscii(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(_asciiFolding[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

class _Random {
  int _state;

  _Random(int seed) : _state = seed == 0 ? 1 : seed & 0x7fffffff;

  int nextInt(int max) {
    if (max <= 0) return 0;
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state % max;
  }

  bool chance(int percent) => nextInt(100) < percent;
}

int _seedFrom(String text) {
  var hash = 7;
  for (final unit in text.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

enum _PlannedEventKind { accepted, retry, rejected }

class _PlannedEvent {
  final _PlannedEventKind kind;
  final String email;
  final String? studentName;
  final int offsetSeconds;
  final String attemptType;
  final String reason;

  const _PlannedEvent({
    required this.kind,
    required this.email,
    required this.studentName,
    required this.offsetSeconds,
    this.attemptType = '',
    this.reason = '',
  });
}

class MockAttendanceDataset {
  static const int _closingGraceSeconds = 15;
  static const Duration _sessionDuration = Duration(minutes: 50);

  final Map<String, List<RosterEntry>> _rosterByClass = {};
  final List<AttendanceSession> _seededSessions = [];

  MockAttendanceDataset({
    required List<ClassModel> classes,
    required DateTime today,
  }) {
    for (var index = 0; index < classes.length; index++) {
      final classModel = classes[index];
      _rosterByClass[classModel.id] = _buildRoster(classModel);
      _seededSessions.addAll(_buildHistory(classModel, today, index));
    }
  }

  List<AttendanceSession> get seededSessions =>
      List.unmodifiable(_seededSessions);

  List<RosterEntry> rosterFor(String classId) =>
      _rosterByClass[classId] ?? const [];

  void setRoster(String classId, List<RosterEntry> roster) {
    _rosterByClass[classId] = List.unmodifiable(roster);
  }

  SessionResults resultsFor(AttendanceSession session, DateTime now) {
    final roster = rosterFor(session.classId);
    if (roster.isEmpty) {
      throw AttendanceApiException(
        code: 'roster_missing',
        message: 'Lớp học chưa có danh sách sinh viên đang hoạt động.',
        details: {'class_id': session.classId},
      );
    }

    final cutoff = session.closedAt?.add(
          const Duration(seconds: _closingGraceSeconds),
        ) ??
        now;
    final effectiveNow = now.isBefore(cutoff) ? now : cutoff;
    final elapsedSeconds =
        effectiveNow.difference(session.openedAt).inSeconds;

    final attendance = <AttendanceRecord>[];
    final attempts = <AttendanceAttempt>[];
    final events = _planFor(session, roster);

    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      if (event.offsetSeconds > elapsedSeconds) continue;

      final occurredAt =
          session.openedAt.add(Duration(seconds: event.offsetSeconds));

      if (event.kind == _PlannedEventKind.accepted) {
        attendance.add(
          AttendanceRecord(
            id: 'ATT_${session.id}_$index',
            sessionId: session.id,
            formResponseId: 'FR_${session.id}_$index',
            email: event.email,
            emailKey: normalizeEmailKey(event.email),
            studentName: event.studentName,
            acceptedAt: occurredAt,
          ),
        );
      } else {
        attempts.add(
          AttendanceAttempt(
            id: 'ATM_${session.id}_$index',
            sessionId: session.id,
            formResponseId: 'FR_${session.id}_$index',
            email: event.email,
            emailKey: normalizeEmailKey(event.email),
            attemptType: event.attemptType,
            reason: event.reason,
            occurredAt: occurredAt,
          ),
        );
      }
    }

    return SessionResults(
      session: session,
      roster: roster,
      attendance: List.unmodifiable(attendance),
      attempts: List.unmodifiable(attempts),
      fetchedAt: now,
    );
  }

  List<RosterEntry> _buildRoster(ClassModel classModel) {
    final random = _Random(_seedFrom(classModel.id));
    final suffix = _classEmailSuffix(classModel.id);
    final entries = <RosterEntry>[];
    final usedEmails = <String>{};

    for (var index = 0; index < classModel.totalStudents; index++) {
      final surname = _surnames[random.nextInt(_surnames.length)];
      final middleName = _middleNames[random.nextInt(_middleNames.length)];
      final givenName = _givenNames[random.nextInt(_givenNames.length)];
      final initials = '${_toAscii(surname)[0]}${_toAscii(middleName)[0]}';
      final ordinal = (index + 1).toString().padLeft(2, '0');

      var email =
          '${_toAscii(givenName)}$initials$suffix$ordinal@fpt.edu.vn';
      while (!usedEmails.add(email)) {
        email = '${_toAscii(givenName)}$initials$suffix${ordinal}x@fpt.edu.vn';
      }

      entries.add(
        RosterEntry(
          id: 'ROS_${classModel.id}_$ordinal',
          classId: classModel.id,
          email: email,
          emailKey: normalizeEmailKey(email),
          studentName: '$surname $middleName $givenName',
        ),
      );
    }

    return List.unmodifiable(entries);
  }

  String _classEmailSuffix(String classId) {
    final segments = classId.split('_');
    return _toAscii(segments.isEmpty ? classId : segments.last);
  }

  List<AttendanceSession> _buildHistory(
    ClassModel classModel,
    DateTime today,
    int classIndex,
  ) {
    final schedule = _historySchedules[classIndex % _historySchedules.length];
    final sessions = <AttendanceSession>[];
    final sequenceByKey = <String, int>{};

    for (final entry in schedule) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: entry.$1));
      final slotNumber = entry.$2;
      final key = '${_formatDate(date)}|$slotNumber';
      final sequence = (sequenceByKey[key] ?? 0) + 1;
      sequenceByKey[key] = sequence;

      final startMinutes = _slotStartMinutes[slotNumber] ?? 8 * 60;
      final openedAt = date.add(
        Duration(minutes: startMinutes + 2 + (sequence - 1) * 55),
      );
      final closedAt = openedAt.add(
        sequence == 1 ? _sessionDuration : const Duration(minutes: 28),
      );

      sessions.add(
        AttendanceSession(
          id: 'SES_${classModel.courseCode}_${_compactDate(date)}_S${slotNumber}_$sequence',
          classId: classModel.id,
          className: '${classModel.courseCode} - ${classModel.name}',
          slot: SessionSlot(
            id: 'SLOT_${classModel.id}_${_compactDate(date)}_$slotNumber',
            slotNumber: slotNumber,
            timeRange: kMockSlotTimeRanges[slotNumber] ?? '07:30 - 09:00',
            date: _formatDate(date),
          ),
          openedAt: openedAt,
          closedAt: closedAt,
          status: SessionStatus.closed,
        ),
      );
    }

    return sessions;
  }

  List<_PlannedEvent> _planFor(
    AttendanceSession session,
    List<RosterEntry> roster,
  ) {
    final random = _Random(_seedFrom(session.id));
    final shuffled = _shuffled(roster, random);
    final attendanceRate = 72 + random.nextInt(24);
    final presentCount = (roster.length * attendanceRate / 100).round();
    final events = <_PlannedEvent>[];

    for (var index = 0; index < presentCount; index++) {
      final student = shuffled[index];
      final arrivalOffset = 5 + random.nextInt(420);

      events.add(
        _PlannedEvent(
          kind: _PlannedEventKind.accepted,
          email: student.email,
          studentName: student.studentName,
          offsetSeconds: arrivalOffset,
        ),
      );

      if (random.chance(18)) {
        events.add(
          _PlannedEvent(
            kind: _PlannedEventKind.retry,
            email: student.email,
            studentName: student.studentName,
            offsetSeconds: arrivalOffset + 15 + random.nextInt(240),
            attemptType: 'duplicate_email',
            reason: 'duplicate_email',
          ),
        );
      }
    }

    for (var index = presentCount; index < shuffled.length; index++) {
      if (!random.chance(24)) continue;
      final student = shuffled[index];
      final expired = random.chance(60);

      events.add(
        _PlannedEvent(
          kind: _PlannedEventKind.rejected,
          email: student.email,
          studentName: student.studentName,
          offsetSeconds: 60 + random.nextInt(500),
          attemptType: expired ? 'grant_expired' : 'session_closed',
          reason: expired ? 'grace_expired' : 'session_not_accepting_submissions',
        ),
      );
    }

    if (random.chance(30)) {
      events.add(
        _PlannedEvent(
          kind: _PlannedEventKind.rejected,
          email: 'khachvanglai@gmail.com',
          studentName: null,
          offsetSeconds: 90 + random.nextInt(400),
          attemptType: 'roster_mismatch',
          reason: 'email_not_in_roster',
        ),
      );
    }

    if (random.chance(25)) {
      events.add(
        _PlannedEvent(
          kind: _PlannedEventKind.accepted,
          email: 'sinhvienchuyenlop@fpt.edu.vn',
          studentName: 'Sinh viên đã chuyển lớp',
          offsetSeconds: 40 + random.nextInt(300),
        ),
      );
    }

    events.sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));
    return events;
  }

  List<T> _shuffled<T>(List<T> source, _Random random) {
    final copy = [...source];
    for (var index = copy.length - 1; index > 0; index--) {
      final target = random.nextInt(index + 1);
      final swap = copy[index];
      copy[index] = copy[target];
      copy[target] = swap;
    }
    return copy;
  }

  static const List<List<(int, int)>> _historySchedules = [
    [(2, 2), (4, 2), (7, 2), (7, 2), (9, 2), (11, 2), (14, 2)],
    [(3, 3), (6, 3), (10, 3), (13, 3)],
    [(1, 1), (5, 1), (8, 1), (12, 1)],
  ];

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _compactDate(DateTime date) =>
      _formatDate(date).replaceAll('-', '');
}
