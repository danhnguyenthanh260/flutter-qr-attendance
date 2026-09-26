import 'package:flutter_qr_attendance/data/models/attendance_result_model.dart';
import 'package:flutter_qr_attendance/data/models/class_model.dart';
import 'package:flutter_qr_attendance/data/models/qr_ticket_model.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';

const String kClassId = 'CLASS_PRM392';
final DateTime kBaseTime = DateTime(2026, 9, 22, 9, 15);

ClassModel buildClass({
  String id = kClassId,
  String courseCode = 'PRM392',
  String name = 'Lập trình Di động',
  int totalStudents = 3,
}) {
  return ClassModel(
    id: id,
    name: name,
    courseCode: courseCode,
    room: 'BE-302',
    totalStudents: totalStudents,
    scheduleDescription: 'Slot 2',
  );
}

AttendanceSession buildSession({
  String id = 'SES_1',
  String classId = kClassId,
  String className = 'PRM392 - Lập trình Di động',
  int slotNumber = 2,
  String date = '2026-09-22',
  String timeRange = '09:15 - 10:45',
  DateTime? openedAt,
  DateTime? closedAt,
  SessionStatus status = SessionStatus.active,
}) {
  return AttendanceSession(
    id: id,
    classId: classId,
    className: className,
    slot: SessionSlot(
      id: 'SLOT_$id',
      slotNumber: slotNumber,
      timeRange: timeRange,
      date: date,
    ),
    openedAt: openedAt ?? kBaseTime,
    closedAt: closedAt,
    status: status,
  );
}

RosterEntry buildRosterEntry(
  String email, {
  String? name,
  String classId = kClassId,
  String? id,
}) {
  return RosterEntry(
    id: id ?? 'ROS_$email',
    classId: classId,
    email: email,
    emailKey: normalizeEmailKey(email),
    studentName: name,
  );
}

AttendanceRecord buildAttendance(
  String email, {
  String id = 'ATT_1',
  String sessionId = 'SES_1',
  String? name,
  DateTime? acceptedAt,
}) {
  return AttendanceRecord(
    id: id,
    sessionId: sessionId,
    formResponseId: 'FR_$id',
    email: email,
    emailKey: normalizeEmailKey(email),
    studentName: name,
    acceptedAt: acceptedAt ?? kBaseTime.add(const Duration(minutes: 1)),
  );
}

AttendanceAttempt buildAttempt(
  String email, {
  String id = 'ATM_1',
  String sessionId = 'SES_1',
  String attemptType = 'duplicate_email',
  String reason = 'duplicate_email',
  DateTime? occurredAt,
}) {
  return AttendanceAttempt(
    id: id,
    sessionId: sessionId,
    formResponseId: 'FR_$id',
    email: email,
    emailKey: normalizeEmailKey(email),
    attemptType: attemptType,
    reason: reason,
    occurredAt: occurredAt ?? kBaseTime.add(const Duration(minutes: 5)),
  );
}

SessionResults buildResults({
  AttendanceSession? session,
  List<RosterEntry> roster = const [],
  List<AttendanceRecord> attendance = const [],
  List<AttendanceAttempt> attempts = const [],
  DateTime? fetchedAt,
}) {
  return SessionResults(
    session: session ?? buildSession(),
    roster: roster,
    attendance: attendance,
    attempts: attempts,
    fetchedAt: fetchedAt ?? kBaseTime.add(const Duration(minutes: 10)),
  );
}

class FakeAttendanceService implements AttendanceService {
  final List<ClassModel> classes;
  final Map<String, SessionResults> resultsBySession = {};
  final Map<String, Object> failuresBySession = {};

  List<AttendanceSession> sessions;
  Object? listSessionsFailure;
  Object? classesFailure;

  int getSessionResultsCalls = 0;
  int listSessionsCalls = 0;

  FakeAttendanceService({
    List<ClassModel>? classes,
    List<AttendanceSession>? sessions,
  }) : classes = classes ?? [buildClass()],
       sessions = sessions ?? [];

  void setResults(SessionResults results) {
    resultsBySession[results.session.id] = results;
    failuresBySession.remove(results.session.id);
  }

  void failSession(String sessionId, Object error) {
    failuresBySession[sessionId] = error;
  }

  void clearFailure(String sessionId) {
    failuresBySession.remove(sessionId);
  }

  @override
  Future<List<ClassModel>> getClasses() async {
    final failure = classesFailure;
    if (failure != null) throw failure;
    return classes;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async => const [];

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AttendanceSession?> getActiveSession() async => null;

  @override
  Future<AttendanceSession> closeSession(String sessionId) async {
    throw UnimplementedError();
  }

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<AttendanceSession>> listSessions({
    String? classId,
    String? date,
  }) async {
    listSessionsCalls++;
    final failure = listSessionsFailure;
    if (failure != null) throw failure;
    return sessions
        .where(
          (session) =>
              (classId == null || session.classId == classId) &&
              (date == null || session.slot.date == date),
        )
        .toList();
  }

  @override
  Future<SessionResults> getSessionResults(String sessionId) async {
    getSessionResultsCalls++;
    final failure = failuresBySession[sessionId];
    if (failure != null) throw failure;

    final results = resultsBySession[sessionId];
    if (results == null) {
      throw const AttendanceApiException(
        code: 'not_found',
        message: 'Phiên điểm danh không tồn tại.',
      );
    }
    return results;
  }
}
