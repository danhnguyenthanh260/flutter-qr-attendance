import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/storage/catalog_storage.dart';
import '../../core/utils/performance_log.dart';
import '../models/attendance_result_model.dart';
import '../models/class_model.dart';
import '../models/qr_ticket_model.dart';
import '../models/session_model.dart';
import 'attendance_api_exception.dart';
import 'attendance_service.dart';

class TeacherApiException extends AttendanceApiException {
  const TeacherApiException({
    required super.code,
    required super.message,
    super.details,
  });

  @override
  String toString() => 'TeacherApiException($code): $message';
}

/// Returned only when a release was built without the required teacher API
/// configuration. It prevents the desktop app from silently falling back to a
/// mock or to the legacy endpoint, both of which would display unusable QR data.
class ConfigurationRequiredAttendanceService implements AttendanceService {
  Never _fail() => throw const TeacherApiException(
    code: 'configuration_required',
    message: 'Cần cấu hình ATTENDANCE_TEACHER_API_URL, ATTENDANCE_TEACHER_API_KEY và ATTENDANCE_TEACHER_ID trước khi mở phiên điểm danh.',
  );

  @override
  Future<AttendanceSession> closeSession(String sessionId) async => _fail();

  @override
  Future<AttendanceSession?> getActiveSession() async => _fail();

  @override
  Future<List<ClassModel>> getClasses() async => _fail();

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) async => _fail();

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async => _fail();

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async => _fail();

  @override
  Future<List<AttendanceSession>> listSessions({
    String? classId,
    String? date,
  }) async => _fail();

  @override
  Future<SessionResults> getSessionResults(String sessionId) async => _fail();
}

AttendanceService createConfiguredTeacherAttendanceService() {
  if (AppConfig.useSeededMockData) {
    return MockAttendanceService(simulateDelay: false);
  }
  if (!AppConfig.hasTeacherApiConfiguration) {
    return ConfigurationRequiredAttendanceService();
  }
  return GoogleAppsScriptAttendanceService(
    endpoint: Uri.parse(AppConfig.teacherApiUrl),
    teacherKey: AppConfig.teacherApiKey,
    teacherId: AppConfig.teacherId,
    catalogStorage: CatalogStorage.local(
      '${AppConfig.teacherApiUrl}|${AppConfig.teacherId}|${AppConfig.teacherApiKey}',
    ),
  );
}

/// An opt-in client for the Google Apps Script teacher API from issues #4 and #9.
///
/// The application continues to use [MockAttendanceService] until a caller
/// explicitly supplies a deployed endpoint and an authenticated teacher identity.
/// QR ticket issuance remains owned by issue #7 and deliberately fails closed here.
class GoogleAppsScriptAttendanceService implements AttendanceService {
  static const Duration _classesCacheTtl = Duration(minutes: 5);

  final Uri _endpoint;
  final String _teacherKey;
  final String _teacherId;
  final http.Client _client;
  final DateTime Function() _clock;
  final CatalogStorage? catalogStorage;
  final Duration requestTimeout;
  final Map<String, Future<List<SessionSlot>>> _slotsInFlight = {};
  final Map<String, ({DateTime saved, List<SessionSlot> items})> _slotsCache =
      {};
  final Map<String, String> _pendingStartRequestIds = {};
  final Map<String, Future<dynamic>> _readsInFlight = {};
  List<ClassModel>? _classesCache;
  DateTime? _classesCachedAt;
  Future<List<ClassModel>>? _classesInFlight;

  GoogleAppsScriptAttendanceService({
    required Uri endpoint,
    required String teacherKey,
    required String teacherId,
    http.Client? client,
    DateTime Function()? clock,
    this.catalogStorage,
    this.requestTimeout = const Duration(seconds: 25),
  }) : _endpoint = endpoint,
       _teacherKey = _requireValue(teacherKey, 'teacherKey'),
       _teacherId = _requireValue(teacherId, 'teacherId'),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now {
    if (!_endpoint.hasScheme || !_endpoint.hasAuthority) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'A complete API URL is required.',
      );
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
    final cached = _classesCache;
    final cachedAt = _classesCachedAt;
    if (cached != null &&
        cachedAt != null &&
        _clock().difference(cachedAt) < _classesCacheTtl) {
      return cached;
    }

    final inFlight = _classesInFlight;
    if (inFlight != null) return inFlight;

    final request = _loadClasses();
    _classesInFlight = request;
    return request;
  }

  Future<List<ClassModel>> _loadClasses() async {
    try {
      var cached = await catalogStorage?.read('classes', _clock());
      List<ClassModel> decode(dynamic data) => _asList(data, 'classes')
          .map((item) => ClassModel.fromJson(_asMap(item, 'class item')))
          .toList(growable: false);
      List<ClassModel>? classes;
      if (cached != null) {
        try {
          classes = decode(cached.items);
        } catch (_) {
          cached = null;
        }
      }
      classes ??= decode(await _get('classes'));
      _classesCache = classes;
      _classesCachedAt = cached?.saved ?? _clock();
      if (cached == null) {
        await catalogStorage?.write(
          'classes',
          classes.map((item) => item.toJson()).toList(),
          _clock(),
        );
      }
      return classes;
    } finally {
      _classesInFlight = null;
    }
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) async {
    final cached = _slotsCache[classId];
    if (cached != null &&
        _clock().difference(cached.saved) < _classesCacheTtl) {
      return cached.items;
    }
    return _slotsInFlight[classId] ??= _loadSlots(classId);
  }

  Future<List<SessionSlot>> _loadSlots(String classId) async {
    try {
      var stored = await catalogStorage?.read('slots:$classId', _clock());
      List<SessionSlot> decode(dynamic data) => _asList(data, 'slots')
          .map((item) => SessionSlot.fromJson(_asMap(item, 'slot item')))
          .toList(growable: false);
      List<SessionSlot>? slots;
      if (stored != null) {
        try {
          slots = decode(stored.items);
        } catch (_) {
          stored = null;
        }
      }
      slots ??= decode(await _get('slots', query: {'class_id': classId}));
      _slotsCache[classId] = (saved: stored?.saved ?? _clock(), items: slots);
      if (stored == null) {
        await catalogStorage?.write(
          'slots:$classId',
          slots.map((item) => item.toJson()).toList(),
          _clock(),
        );
      }
      return slots;
    } finally {
      _slotsInFlight.remove(classId);
    }
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

  @override
  Future<List<AttendanceSession>> listSessions({
    String? classId,
    String? date,
  }) async {
    final data = await _get(
      'sessions',
      query: {'class_id': ?classId, 'date': ?date},
    );
    return _asList(data, 'sessions')
        .map((item) => AttendanceSession.fromJson(_asMap(item, 'session item')))
        .toList(growable: false);
  }

  @override
  Future<SessionResults> getSessionResults(String sessionId) async {
    final data = await _get(
      'session_results',
      query: {'session_id': sessionId},
    );
    return SessionResults.fromJson(
      _asMap(data, 'session_results response'),
      fetchedAt: _clock(),
    );
  }

  Future<dynamic> _get(String action, {Map<String, String> query = const {}}) {
    final keys = query.keys.toList()..sort();
    final key = jsonEncode([
      action,
      {for (final name in keys) name: query[name]},
    ]);
    return _readsInFlight[key] ??= _getOnce(action, query).whenComplete(() {
      _readsInFlight.remove(key);
    });
  }

  Future<dynamic> _getOnce(String action, Map<String, String> query) async {
    final timer = Stopwatch()..start();
    PerformanceLog.mark('api_start', {'action': action});
    final uri = _endpoint.replace(
      queryParameters: {
        ..._endpoint.queryParameters,
        'action': action,
        'teacher_key': _teacherKey,
        ...query,
      },
    );
    try {
      final response = await _withDeadline(
        _getAppsScriptResponse(uri),
        mutation: false,
      );
      final data = _decodeEnvelope(response, action);
      PerformanceLog.mark('api_done', {
        'action': action,
        'ms': timer.elapsedMilliseconds,
      });
      return data;
    } catch (_) {
      PerformanceLog.mark('api_failed', {
        'action': action,
        'ms': timer.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  /// Prevent the platform HTTP client from automatically following Apps
  /// Script's redirect. On Windows that automatic hop can stall before the
  /// response body arrives. The redirect is then followed explicitly using
  /// the same trusted-host check as POST requests.
  Future<http.Response> _getAppsScriptResponse(Uri uri) async {
    final request = http.Request('GET', uri)
      ..persistentConnection = false
      ..followRedirects = false
      ..maxRedirects = 0;
    final initialResponse = await http.Response.fromStream(
      await _client.send(request),
    );
    return _followAppsScriptRedirect(initialResponse);
  }

  Future<dynamic> _post(String action, Map<String, dynamic> body) async {
    return _withDeadline(_postOnce(action, body), mutation: true);
  }

  Future<T> _withDeadline<T>(
    Future<T> operation, {
    required bool mutation,
  }) async {
    try {
      return await operation.timeout(requestTimeout);
    } on TimeoutException {
      throw TeacherApiException(
        code: mutation ? 'operation_unconfirmed' : 'request_timeout',
        message: mutation
            ? 'Máy chủ chưa xác nhận thao tác. Hãy kiểm tra lại trạng thái phiên trước khi thử lại.'
            : 'Máy chủ phản hồi quá lâu. Vui lòng thử tải lại dữ liệu.',
      );
    }
  }

  Future<dynamic> _postOnce(String action, Map<String, dynamic> body) async {
    final request = http.Request('POST', _endpoint)
      ..persistentConnection = false
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'action': action,
        'teacher_key': _teacherKey,
        ...body,
      });
    final initialResponse = await http.Response.fromStream(
      await _client.send(request),
    );
    final response = await _followAppsScriptRedirect(initialResponse);
    return _decodeEnvelope(response, action);
  }

  /// Apps Script's ContentService returns a 302 to a short-lived
  /// script.googleusercontent.com URL. Follow only that trusted target with a
  /// GET to obtain the JSON envelope.
  Future<http.Response> _followAppsScriptRedirect(
    http.Response response,
  ) async {
    final location = response.headers['location'];
    if (response.statusCode != 302 || location == null) {
      return response;
    }

    final redirectUri = Uri.tryParse(location);
    if (redirectUri == null ||
        redirectUri.scheme != 'https' ||
        redirectUri.host != 'script.googleusercontent.com') {
      return response;
    }

    return _getAppsScriptContent(redirectUri);
  }

  /// Google occasionally serves another ContentService redirect, or a
  /// short-lived HTML response, before the JSON body is available. Every hop
  /// is made with automatic redirects disabled so the Windows HTTP client
  /// cannot enter an opaque redirect loop. The original teacher action is
  /// never replayed.
  Future<http.Response> _getAppsScriptContent(Uri redirectUri) async {
    var uri = redirectUri;
    final visitedUris = <String>{};

    for (var hop = 0; hop < 3; hop++) {
      if (!visitedUris.add(uri.toString())) {
        throw const TeacherApiException(
          code: 'invalid_response',
          message: 'Teacher API redirected repeatedly without returning data.',
        );
      }

      var response = await _getWithoutRedirect(uri);
      final nextUri = _trustedContentRedirect(response);
      if (nextUri != null) {
        uri = nextUri;
        continue;
      }

      for (var attempt = 0; attempt < 2 && !_hasJsonBody(response); attempt++) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
        response = await _getWithoutRedirect(uri);
      }
      return response;
    }

    throw const TeacherApiException(
      code: 'invalid_response',
      message: 'Teacher API redirected too many times without returning data.',
    );
  }

  Future<http.Response> _getWithoutRedirect(Uri uri) async {
    final request = http.Request('GET', uri)
      ..persistentConnection = false
      ..followRedirects = false
      ..maxRedirects = 0;
    return http.Response.fromStream(await _client.send(request));
  }

  Uri? _trustedContentRedirect(http.Response response) {
    if (response.statusCode != 302) {
      return null;
    }

    final location = response.headers['location'];
    final uri = location == null ? null : Uri.tryParse(location);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'script.googleusercontent.com') {
      return null;
    }
    return uri;
  }

  bool _hasJsonBody(http.Response response) {
    return response.body.trimLeft().startsWith('{');
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
        message:
            'Teacher API returned an invalid response envelope for $action.',
      );
    }
    final envelope = Map<String, dynamic>.from(decoded);
    final error = envelope['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        envelope['ok'] != true) {
      final errorMap = error is Map
          ? Map<String, dynamic>.from(error)
          : const <String, dynamic>{};
      throw TeacherApiException(
        code: errorMap['code'] as String? ?? 'request_failed',
        message:
            errorMap['message'] as String? ??
            'Teacher API request failed for $action.',
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
