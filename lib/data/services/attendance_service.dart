import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/attendance_result_model.dart';
import '../models/class_model.dart';
import '../models/qr_ticket_model.dart';
import '../models/session_model.dart';
import '../repositories/attendance_repository.dart';
import 'attendance_api_exception.dart';
import 'mock_attendance_data.dart';

/// Compatibility name for backend adapters and existing test doubles.
typedef AttendanceService = AttendanceRepository;

class MockAttendanceService implements AttendanceService {
  final bool simulateDelay;
  final DateTime Function() _clock;
  final List<AttendanceSession> _createdSessions = [];

  AttendanceSession? _activeSession;
  int _generationCounter = 0;
  MockAttendanceDataset? _cachedDataset;

  MockAttendanceService({this.simulateDelay = true, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  MockAttendanceDataset get dataset => _cachedDataset ??= MockAttendanceDataset(
    classes: _mockClasses,
    today: _clock(),
  );

  void configureRoster(String classId, List<RosterEntry> roster) {
    dataset.setRoster(classId, roster);
  }

  Future<void> _delay(int ms) async {
    if (simulateDelay) {
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
  }

  void _trackSession(AttendanceSession session) {
    final index = _createdSessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      _createdSessions[index] = session;
    } else {
      _createdSessions.add(session);
    }
  }

  AttendanceSession? _findSession(String sessionId) {
    for (final session in _createdSessions) {
      if (session.id == sessionId) return session;
    }
    for (final session in dataset.seededSessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  List<ClassModel> _mockClasses = const [
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

  void configureClasses(List<ClassModel> classes) {
    _mockClasses = classes;
    _cachedDataset = null;
  }

  @override
  Future<List<ClassModel>> getClasses() async {
    await _delay(300);
    return _mockClasses;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    await _delay(200);
    final today = _clock().toIso8601String().split('T').first;
    final compactDate = today.replaceAll('-', '');
    return kMockSlotTimeRanges.entries
        .map(
          (entry) => SessionSlot(
            id: 'SLOT_${classId}_${compactDate}_${entry.key}',
            slotNumber: entry.key,
            timeRange: entry.value,
            date: today,
          ),
        )
        .toList();
  }

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    await _delay(500);

    if (_activeSession != null &&
        _activeSession!.status == SessionStatus.active) {
      if (_activeSession!.classId == classId &&
          _activeSession!.slot.slotNumber == slot.slotNumber) {
        return _activeSession!;
      }
      throw Exception(
        'Đang có một phiên khác đang mở. Vui lòng đóng phiên trước khi mở phiên mới.',
      );
    }

    final classItem = _mockClasses.firstWhere(
      (c) => c.id == classId,
      orElse: () => throw Exception('Không tìm thấy thông tin lớp học'),
    );

    final now = _clock();
    final sessionId =
        'SES_${classItem.courseCode}_${now.millisecondsSinceEpoch}';
    _activeSession = AttendanceSession(
      id: sessionId,
      classId: classId,
      className: '${classItem.courseCode} - ${classItem.name}',
      slot: slot,
      openedAt: now,
      status: SessionStatus.active,
    );
    _trackSession(_activeSession!);

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

    final closed = _activeSession!.copyWith(
      closedAt: _clock(),
      status: SessionStatus.closed,
    );
    _trackSession(closed);
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
    final ticketCode =
        'TKT_${sessionId}_G${_generationCounter}_${now.millisecondsSinceEpoch % 100000}';
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

  @override
  Future<List<AttendanceSession>> listSessions({
    String? classId,
    String? date,
  }) async {
    await _delay(250);

    final byId = <String, AttendanceSession>{};
    for (final session in dataset.seededSessions) {
      byId[session.id] = session;
    }
    for (final session in _createdSessions) {
      byId[session.id] = session;
    }

    final matches =
        byId.values
            .where(
              (session) =>
                  (classId == null || session.classId == classId) &&
                  (date == null || session.slot.date == date),
            )
            .toList()
          ..sort((a, b) => b.openedAt.compareTo(a.openedAt));

    return matches;
  }

  @override
  Future<SessionResults> getSessionResults(String sessionId) async {
    await _delay(250);

    final session = _findSession(sessionId);
    if (session == null) {
      throw AttendanceApiException(
        code: 'not_found',
        message: 'Phiên điểm danh không tồn tại.',
        details: {'session_id': sessionId},
      );
    }

    return dataset.resultsFor(session, _clock());
  }
}

/*
 * LEGACY VERSION - KEPT FOR REFERENCE AS REQUESTED.
 *
 * This was the first Google Sheets implementation. It is intentionally kept
 * here as a comment so the original implementation is not deleted while the
 * refactored implementation below becomes the active one.
class GoogleSheetAttendanceService implements AttendanceService {
  static const String _baseUrl =
      'https://script.google.com/macros/s/AKfycbyk6yBoDmp3DpFXNjyHuTOeno7eFF6odQNMIQ1-FruSME9ZlUOcGSNoCplElJ_-Poz-xQ/exec';

  final MockAttendanceService _mockService;
  AttendanceSession? _remoteSession;

  GoogleSheetAttendanceService({MockAttendanceService? mockService})
      : _mockService = mockService ?? MockAttendanceService();

  Future<List<dynamic>> _getData(Uri uri) async {
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Google Sheets trả về mã lỗi ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;

    if (payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Không thể đọc dữ liệu Google Sheets');
    }

    return (payload['data'] as List<dynamic>?) ?? [];
  }

  @override
  Future<List<ClassModel>> getClasses() async {
    final data = await _getData(
      Uri.parse('$_baseUrl?action=classes'),
    );

    final classes = data
        .map((item) => ClassModel.fromJson(item as Map<String, dynamic>))
        .toList();

    _mockService.configureClasses(classes);
    return classes;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'slots',
        'classId': classId,
      },
    );
    final data = await _getData(uri);

    return data
        .map((item) => SessionSlot.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    if (slot.id == null || slot.id!.isEmpty) {
      throw Exception('Slot chưa có id để tạo session');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      // text/plain avoids the browser CORS preflight used by application/json.
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: jsonEncode({
        'action': 'create_session',
        'classId': classId,
        'slotId': slot.id,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Không thể tạo session (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Không thể tạo session');
    }

    final data = payload['data'] as Map<String, dynamic>;
    final classItem = _mockService._mockClasses.firstWhere(
      (item) => item.id == classId,
      orElse: () => throw Exception('Không tìm thấy thông tin lớp học'),
    );

    _remoteSession = AttendanceSession(
      id: data['sessionId'] as String,
      classId: classId,
      className: '${classItem.courseCode} - ${classItem.name}',
      slot: slot,
      openedAt: DateTime.parse(data['openedAt'] as String),
      status: SessionStatus.active,
      token: data['token'] as String,
    );

    return _remoteSession!;
  }

  @override
  Future<AttendanceSession?> getActiveSession() {
    return Future.value(_remoteSession);
  }

  @override
  Future<AttendanceSession> closeSession(String sessionId) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'text/plain;charset=utf-8'},
      body: jsonEncode({
        'action': 'close_session',
        'sessionId': sessionId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Không thể đóng session (${response.statusCode})');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true) {
      throw Exception(payload['message'] ?? 'Không thể đóng session');
    }

    final session = _remoteSession;
    if (session == null || session.id != sessionId) {
      throw Exception('Không tìm thấy session đang mở trong ứng dụng');
    }

    _remoteSession = session.copyWith(
      closedAt: DateTime.now(),
      status: SessionStatus.closed,
    );

    return _remoteSession!;
  }

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) {
    if (_remoteSession?.id == sessionId && _remoteSession?.token != null) {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(seconds: 30));
      return Future.value(QrTicketModel(
        ticketCode: _remoteSession!.token!,
        formUrl: jsonEncode({
          'sessionId': sessionId,
          'classId': _remoteSession!.classId,
          'slotId': _remoteSession!.slot.id,
          'token': _remoteSession!.token,
          'expiresAt': expiresAt.toIso8601String(),
        }),
        generation: 1,
        validSeconds: 30,
        createdAt: now,
        expiresAt: expiresAt,
      ));
    }

    return _mockService.getNextQrTicket(sessionId);
  }
}
*/

/// Connects the Flutter app to the Google Apps Script Web App.
///
/// The service owns transport and JSON parsing. The provider still owns UI
/// state, timers, loading flags, and error presentation.
class GoogleSheetAttendanceService implements AttendanceService {
  // Read the deployment URL from the central configuration file.
  static const String _baseUrl = AppConfig.googleSheetsApiUrl;

  // A text request avoids the browser preflight caused by application/json.
  static const String _requestContentType = 'text/plain;charset=utf-8';

  // The current backend does not expose all session endpoints yet.
  // The existing mock remains available for the unfinished fallback paths.
  final MockAttendanceService _mockService;

  // This is the remote session created during the current app run.
  AttendanceSession? _remoteSession;

  GoogleSheetAttendanceService({MockAttendanceService? mockService})
    : _mockService = mockService ?? MockAttendanceService();

  /// Decodes one successful Apps Script response and centralizes API errors.
  Map<String, dynamic> _decodePayload(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Google Sheets trả về mã lỗi ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;

    if (payload['success'] != true) {
      throw Exception(
        payload['message'] ?? 'Google Sheets trả về lỗi không xác định',
      );
    }

    return payload;
  }

  /// Sends a GET request and returns the decoded Apps Script payload.
  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await http.get(uri);
    return _decodePayload(response);
  }

  /// Sends a POST request with JSON text that remains CORS-simple in browsers.
  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': _requestContentType},
      body: jsonEncode(body),
    );

    return _decodePayload(response);
  }

  /// Reads the list returned by an Apps Script GET endpoint.
  List<dynamic> _dataList(Map<String, dynamic> payload) {
    return (payload['data'] as List<dynamic>?) ?? [];
  }

  @override
  Future<List<ClassModel>> getClasses() async {
    // The API returns class records using the keys expected by ClassModel.
    final payload = await _get(Uri.parse('$_baseUrl?action=classes'));

    final classes = _dataList(payload)
        .map((item) => ClassModel.fromJson(item as Map<String, dynamic>))
        .toList();

    // The unfinished mock session flow must also know the remote class IDs.
    _mockService.configureClasses(classes);
    return classes;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    // Uri.replace safely encodes classId instead of concatenating raw text.
    final uri = Uri.parse(_baseUrl)
        .replace(queryParameters: {'action': 'slots', 'classId': classId});
    final payload = await _get(uri);

    return _dataList(payload)
        .map((item) => SessionSlot.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    // Apps Script needs the real Slot sheet ID to create a session row.
    if (slot.id == null || slot.id!.isEmpty) {
      throw Exception('Slot chưa có id để tạo session');
    }

    final payload = await _post({
      'action': 'create_session',
      'classId': classId,
      'slotId': slot.id,
    });
    final data = payload['data'] as Map<String, dynamic>;

    // The class metadata was loaded before the user could start a session.
    final classItem = _mockService._mockClasses.firstWhere(
      (item) => item.id == classId,
      orElse: () => throw Exception('Không tìm thấy thông tin lớp học'),
    );

    // Keep the server-generated token with the local session for QR creation.
    _remoteSession = AttendanceSession(
      id: data['sessionId'] as String,
      classId: classId,
      className: '${classItem.courseCode} - ${classItem.name}',
      slot: slot,
      openedAt: DateTime.parse(data['openedAt'] as String),
      status: SessionStatus.active,
      token: data['token'] as String,
    );

    return _remoteSession!;
  }

  @override
  Future<AttendanceSession?> getActiveSession() {
    // Active-session lookup will use a backend endpoint when it is added.
    return Future.value(_remoteSession);
  }

  @override
  Future<AttendanceSession> closeSession(String sessionId) async {
    // Closing must update the same server row created by startSession().
    final payload = await _post({
      'action': 'close_session',
      'sessionId': sessionId,
    });

    final session = _remoteSession;
    if (session == null || session.id != sessionId) {
      throw Exception('Không tìm thấy session đang mở trong ứng dụng');
    }

    // Only mark local state closed after Apps Script confirms the operation.
    if ((payload['data'] as Map<String, dynamic>?)?['status'] != 'closed') {
      throw Exception('Máy chủ chưa xác nhận session đã đóng');
    }

    _remoteSession = session.copyWith(
      closedAt: DateTime.now(),
      status: SessionStatus.closed,
    );

    return _remoteSession!;
  }

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) {
    final session = _remoteSession;

    // A remote QR carries the server token and data an extension can read.
    if (session?.id == sessionId && session?.token != null) {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(seconds: 30));
      final qrPayload = jsonEncode({
        'sessionId': sessionId,
        'classId': session!.classId,
        'slotId': session.slot.id,
        'token': session.token,
        'expiresAt': expiresAt.toIso8601String(),
      });

      return Future.value(
        QrTicketModel(
          ticketCode: session.token!,
          formUrl: qrPayload,
          generation: 1,
          validSeconds: 30,
          createdAt: now,
          expiresAt: expiresAt,
        ),
      );
    }

    // Preserve the original mock QR fallback for non-remote sessions.
    return _mockService.getNextQrTicket(sessionId);
  }

  @override
  Future<List<AttendanceSession>> listSessions({
    String? classId,
    String? date,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'sessions',
        'classId': ?classId,
        'date': ?date,
      },
    );
    final payload = await _get(uri);

    return _dataList(payload)
        .map((item) => AttendanceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SessionResults> getSessionResults(String sessionId) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'action': 'session_results', 'sessionId': sessionId},
    );
    final payload = await _get(uri);
    final data = payload['data'];

    if (data is! Map) {
      throw Exception('Google Sheets trả về dữ liệu kết quả không hợp lệ');
    }

    return SessionResults.fromJson(Map<String, dynamic>.from(data));
  }
}
