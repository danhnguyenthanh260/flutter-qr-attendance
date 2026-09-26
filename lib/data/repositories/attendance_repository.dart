import '../models/attendance_result_model.dart';
import '../models/class_model.dart';
import '../models/qr_ticket_model.dart';
import '../models/session_model.dart';

abstract interface class AttendanceRepository {
  Future<List<ClassModel>> getClasses();
  Future<List<SessionSlot>> getSlotsForClass(String classId);
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  });
  Future<AttendanceSession?> getActiveSession();
  Future<AttendanceSession> closeSession(String sessionId);
  Future<QrTicketModel> getNextQrTicket(String sessionId);
  Future<List<AttendanceSession>> listSessions({String? classId, String? date});
  Future<SessionResults> getSessionResults(String sessionId);
}
