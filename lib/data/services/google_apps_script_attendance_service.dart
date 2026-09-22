import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/class_model.dart';
import '../models/qr_ticket_model.dart';
import '../models/session_model.dart';
import 'attendance_service.dart';

class TeacherApiException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  const TeacherApiException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'TeacherApiException($code): $message';
}

/// An opt-in client for the Google Apps Script teacher API from issues #4 and #9.
///
/// The application continues to use [MockAttendanceService] until a caller
/// explicitly supplies a deployed endpoint and an authenticated teacher identity.
/// QR ticket issuance remains owned by issue #7 and deliberately fails closed here.
class GoogleAppsScriptAttendanceService implements AttendanceService {
  final Uri _endpoint;
  final String _teacherKey;
  final String _teacherId;
  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, String> _pendingStartRequestIds = {};

  GoogleAppsScriptAttendanceService({
    required Uri endpoint,
    required String teacherKey,
    required String teacherId,
    http.Client? client,
    DateTime Function()? clock,
  })  : _endpoint = endpoint,
        _teacherKey = _requireValue(teacherKey, 'teacherKey'),
        _teacherId = _requireValue(teacherId, 'teacherId'),
        _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now {
    if (!_endpoint.hasScheme || !_endpoint.hasAuthority) {
      throw ArgumentError.value(endpoint, 'endpoint', 'A complete API URL is required.');
    }
  }

  static String _requireValue(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, '$name must not be empty.');
    }
    return normalized;
  }

  @override
  Future<List<ClassModel>> getClasses() async {
    final data = await _get('classes');
    return _asList(data, 'classes')
        .map((item) => ClassModel.fromJson(_asMap(item, 'class item')))
        .toList(growable: false);
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    final data = await _get('slots', query: {'class_id': classId});
    return _asList(data, 'slots')
        .map((item) => SessionSlot.fromJson(_asMap(item, 'slot item')))
        .toList(growable: false);
  }

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    final operationKey = '$classId|${slot.slotNumber}|${slot.date}';
    final requestId = _pendingStartRequestIds.putIfAbsent(
      operationKey,
      () => 'flutter_${_clock().microsecondsSinceEpoch}_$operationKey',
    );

    try {
      final data = await _post('start_session', {
        'class_id': classId,
        'slot': slot.toJson(),
        'request_id': requestId,
        'teacher_id': _teacherId,
      });
      _pendingStartRequestIds.remove(operationKey);
      return AttendanceSession.fromJson(_asMap(data, 'start_session response'));
    } on TeacherApiException {
      rethrow;
    }
  }

  @override
  Future<AttendanceSession?> getActiveSession() async {
    final data = await _get('active_session');
    if (data == null) {
      return null;
    }
    return AttendanceSession.fromJson(_asMap(data, 'active_session response'));
  }

  @override
  Future<AttendanceSession> closeSession(String sessionId) async {
    final data = await _post('close_session', {'session_id': sessionId});
    return AttendanceSession.fromJson(_asMap(data, 'close_session response'));
  }

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) async {
    final data = await _post('issue_qr', {'session_id': sessionId});
    return QrTicketModel.fromJson(_asMap(data, 'issue_qr response'));
  }

  Future<dynamic> _get(
    String action, {
    Map<String, String> query = const {},
  }) async {
    final uri = _endpoint.replace(
      queryParameters: {
        ..._endpoint.queryParameters,
        'action': action,
        'teacher_key': _teacherKey,
        ...query,
      },
    );
    final response = await _client.get(uri);
    return _decodeEnvelope(response, action);
  }

  Future<dynamic> _post(String action, Map<String, dynamic> body) async {
    final response = await _client.post(
      _endpoint,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'action': action,
        'teacher_key': _teacherKey,
        ...body,
      }),
    );
    return _decodeEnvelope(response, action);
  }

  dynamic _decodeEnvelope(http.Response response, String action) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw TeacherApiException(
        code: 'invalid_response',
        message: 'Teacher API returned invalid JSON for $action.',
      );
    }

    if (decoded is! Map) {
      throw TeacherApiException(
        code: 'invalid_response',
        message: 'Teacher API returned an invalid response envelope for $action.',
      );
    }
    final envelope = Map<String, dynamic>.from(decoded);
    final error = envelope['error'];
    if (response.statusCode < 200 || response.statusCode >= 300 || envelope['ok'] != true) {
      final errorMap = error is Map ? Map<String, dynamic>.from(error) : const <String, dynamic>{};
      throw TeacherApiException(
        code: errorMap['code'] as String? ?? 'request_failed',
        message: errorMap['message'] as String? ?? 'Teacher API request failed for $action.',
        details: errorMap['details'] is Map
            ? Map<String, dynamic>.from(errorMap['details'] as Map)
            : null,
      );
    }
    return envelope['data'];
  }

  Map<String, dynamic> _asMap(dynamic value, String context) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw TeacherApiException(
      code: 'invalid_response',
      message: 'Expected an object for $context.',
    );
  }

  List<dynamic> _asList(dynamic value, String context) {
    if (value is List) {
      return value;
    }
    throw TeacherApiException(
      code: 'invalid_response',
      message: 'Expected a list for $context.',
    );
  }
}
