import '../models/class_model.dart';
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
}

class MockAttendanceService implements AttendanceService {
  AttendanceSession? _activeSession;

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
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockClasses;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    await Future.delayed(const Duration(milliseconds: 200));
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
    await Future.delayed(const Duration(milliseconds: 500));

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
    await Future.delayed(const Duration(milliseconds: 150));
    return _activeSession;
  }

  @override
  Future<AttendanceSession> closeSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_activeSession == null || _activeSession!.id != sessionId) {
      throw Exception('Phiên không tồn tại hoặc đã kết thúc');
    }

    _activeSession = _activeSession!.copyWith(
      closedAt: DateTime.now(),
      status: SessionStatus.closed,
    );
    final closed = _activeSession!;
    _activeSession = null;
    return closed;
  }
}
