import '../models/class_model.dart';
import '../models/qr_ticket_model.dart';
import '../models/session_model.dart';

abstract class AttendanceService {
  Future<List<ClassModel>> getClasses();
  Future<List<SessionSlot>> getSlotsForClass(String classId);
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  });
  Future<AttendanceSession?> getActiveSession();
  Future<AttendanceSession> closeSession(String sessionId);
  Future<QrTicketModel> getNextQrTicket(String sessionId);
}

class MockAttendanceService implements AttendanceService {
  final bool simulateDelay;
  AttendanceSession? _activeSession;
  int _generationCounter = 0;

  MockAttendanceService({this.simulateDelay = true});

  Future<void> _delay(int ms) async {
    if (simulateDelay) {
      await Future.delayed(Duration(milliseconds: ms));
    }
  }

  final List<ClassModel> _mockClasses = const [
    ClassModel(
      id: 'CLASS_PRM392_SE1701',
      name: 'Lập trình Di động (Flutter)',
      courseCode: 'PRM392',
      room: 'BE-302 (Lab C)',
      totalStudents: 32,
      scheduleDescription: 'Thứ 2 - Thứ 6 (Slot 2)',
    ),
    ClassModel(
      id: 'CLASS_SWP391_SE1702',
      name: 'Đồ án Phát triển Phần mềm',
      courseCode: 'SWP391',
      room: 'AL-205 (Hội trường)',
      totalStudents: 28,
      scheduleDescription: 'Thứ 4 - Thứ 7 (Slot 3)',
    ),
    ClassModel(
      id: 'CLASS_CSD201_IA1701',
      name: 'Cấu trúc dữ liệu & Giải thuật',
      courseCode: 'CSD201',
      room: 'DE-101 (Phòng lý thuyết)',
      totalStudents: 35,
      scheduleDescription: 'Thứ 3 - Thứ 5 (Slot 1)',
    ),
  ];

  @override
  Future<List<ClassModel>> getClasses() async {
    await _delay(300);
    return _mockClasses;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    await _delay(200);
    final today = DateTime.now().toIso8601String().split('T').first;
    return [
      SessionSlot(slotNumber: 1, timeRange: '07:30 - 09:00', date: today),
      SessionSlot(slotNumber: 2, timeRange: '09:15 - 10:45', date: today),
      SessionSlot(slotNumber: 3, timeRange: '12:30 - 14:00', date: today),
      SessionSlot(slotNumber: 4, timeRange: '14:15 - 15:45', date: today),
    ];
  }

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    await _delay(500);

    if (_activeSession != null && _activeSession!.status == SessionStatus.active) {
      if (_activeSession!.classId == classId &&
          _activeSession!.slot.slotNumber == slot.slotNumber) {
        return _activeSession!;
      }
      throw Exception('Đang có một phiên khác đang mở. Vui lòng đóng phiên trước khi mở phiên mới.');
    }

    final classItem = _mockClasses.firstWhere(
      (c) => c.id == classId,
      orElse: () => throw Exception('Không tìm thấy thông tin lớp học'),
    );

    final sessionId = 'SES_${classItem.courseCode}_${DateTime.now().millisecondsSinceEpoch}';
    _activeSession = AttendanceSession(
      id: sessionId,
      classId: classId,
      className: '${classItem.courseCode} - ${classItem.name}',
      slot: slot,
      openedAt: DateTime.now(),
      status: SessionStatus.active,
    );

    return _activeSession!;
  }

  @override
  Future<AttendanceSession?> getActiveSession() async {
    await _delay(150);
    return _activeSession;
  }

  @override
  Future<AttendanceSession> closeSession(String sessionId) async {
    await _delay(400);
    if (_activeSession == null || _activeSession!.id != sessionId) {
      throw Exception('Phiên không tồn tại hoặc đã kết thúc');
    }

    _activeSession = _activeSession!.copyWith(
      closedAt: DateTime.now(),
      status: SessionStatus.closed,
    );
    final closed = _activeSession!;
    _activeSession = null;
    _generationCounter = 0;
    return closed;
  }

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) async {
    await _delay(100);
    _generationCounter++;
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(seconds: 30));
    final ticketCode = 'TKT_${sessionId}_G${_generationCounter}_${now.millisecondsSinceEpoch % 100000}';
    final formUrl =
        'https://docs.google.com/forms/d/e/1FAIpQLScMockForms/viewform?usp=pp_url&entry.1001=$ticketCode&entry.1002=$sessionId';

    return QrTicketModel(
      ticketCode: ticketCode,
      formUrl: formUrl,
      generation: _generationCounter,
      validSeconds: 30,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }
}
