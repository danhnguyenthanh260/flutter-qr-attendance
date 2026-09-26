import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/storage/catalog_storage.dart';
import '../../core/utils/performance_log.dart';
import '../models/attendance_result_model.dart';
import '../models/class_model.dart';
import '../models/qr_ticket_model.dart';
import '../models/session_model.dart';
import '../models/teaching_overview.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/teaching_repository.dart';
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
class GoogleAppsScriptAttendanceService
    implements
        AttendanceService,
        TeachingRepository,
        TeachingWorkspaceRepository,
        ScheduleSnapshotSource {
  Future<TeachingWorkspace>? _workspaceRead;
  @override
  Future<TeachingWorkspace> refreshWorkspace() => _workspaceRead ??=
      _fetchWorkspace().whenComplete(() => _workspaceRead = null);

  Future<TeachingWorkspace> _fetchWorkspace() async {
    final data = _asMap(await _get('workspace'), 'workspace');
    final classes = _asList(
      data['classes'],
      'classes',
    ).map((row) => ClassModel.fromJson(_asMap(row, 'class'))).toList();
    final overview = _asMap(data['overview'], 'overview').map(
      (key, value) =>
          MapEntry(key, TeachingOverview.fromJson(_asMap(value, 'overview'))),
    );
    if (classes.any((c) => !overview.containsKey(c.id)) ||
        overview.length != classes.length) {
      throw const TeacherApiException(
        code: 'invalid_workspace',
        message: 'Dữ liệu lớp và lịch không đồng bộ.',
      );
    }
    final active = data['active_session'] == null
        ? null
        : AttendanceSession.fromJson(
            _asMap(data['active_session'], 'active_session'),
          );
    final snapshot = [
      for (final c in classes)
        {
          'class': c.toJson(),
          'slots': overview[c.id]!.slots.map((s) => s.toJson()).toList(),
        },
    ];
    await catalogStorage?.write('workspace_schedule_v2', snapshot, _clock());
    await catalogStorage?.write(
      'classes',
      classes.map((c) => c.toJson()).toList(),
      _clock(),
    );
    return TeachingWorkspace(
      classes: classes,
      overview: overview,
      activeSession: active,
    );
  }

  @override
  Future<Map<String, TeachingOverview>> getWeeklyOverview() async {
    final data = _asMap(await _get('weekly_overview'), 'weekly_overview');
    final parsed = data.map(
      (key, value) => MapEntry(
        key,
        TeachingOverview.fromJson(_asMap(value, 'class overview')),
      ),
    );
    await catalogStorage?.write(
      'weekly_slots',
      parsed.entries
          .map(
            (entry) => {
              'class_id': entry.key,
              'slots': entry.value.slots.map((slot) => slot.toJson()).toList(),
            },
          )
          .toList(),
      _clock(),
    );
    return parsed;
  }

  @override
  Future<
    ({
      DateTime saved,
      List<ClassModel> classes,
      Map<String, TeachingOverview> data,
    })?
  >
  readScheduleSnapshot() async {
    final snapshot = await catalogStorage?.read(
      'workspace_schedule_v2',
      _clock(),
      maxAge: const Duration(days: 7),
    );
    if (snapshot == null) return null;
    try {
      final classes = snapshot.items
          .map(
            (row) => ClassModel.fromJson(
              Map<String, dynamic>.from(row['class'] as Map),
            ),
          )
          .toList();
      return (
        saved: snapshot.saved,
        classes: classes,
        data: {
          for (final row in snapshot.items)
            row['class']['id'] as String: TeachingOverview(
              slots: (row['slots'] as List)
                  .map(
                    (s) => SessionSlot.fromJson(
                      Map<String, dynamic>.from(s as Map),
                    ),
                  )
                  .toList(),
              roster: const [],
              sessions: const [],
              attendance: const [],
            ),
        },
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TeachingOverview> getTeachingOverview(String classId) async =>
      TeachingOverview.fromJson(
        _asMap(
          await _get('class_overview', query: {'class_id': classId}),
          'class_overview',
        ),
      );
  @override
  Future<int> importRoster(Map<String, dynamic> payload) async {
    final data = _asMap(await _post('import_roster', payload), 'import_roster');
    await _catalog.refreshClasses();
    return data['total_students'] as int;
  }

  final Uri _endpoint;
  final String _teacherKey;
  final String _teacherId;
  final http.Client _client;
  final DateTime Function() _clock;
  final CatalogStorage? catalogStorage;
  final Duration requestTimeout;
  final Map<String, String> _pendingStartRequestIds = {};
  final Map<String, String> _pendingQrRequestIds = {};
  final Map<String, Future<dynamic>> _readsInFlight = {};
  late final CatalogRepository _catalog = CatalogRepository(
    storage: catalogStorage,
    clock: _clock,
    loadClasses: () async => _asList(await _get('classes'), 'classes')
        .map((item) => ClassModel.fromJson(_asMap(item, 'class item')))
        .toList(growable: false),
    loadSlots: (classId) async =>
        _asList(await _get('slots', query: {'class_id': classId}), 'slots')
            .map((item) => SessionSlot.fromJson(_asMap(item, 'slot item')))
            .toList(growable: false),
  );

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
  Future<List<ClassModel>> getClasses() => _catalog.getClasses();

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) =>
      _catalog.getSlots(classId);

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
    } on TeacherApiException catch (error) {
      if (error.code == 'operation_unconfirmed') {
        // Observe server state once; never replay the write after a lost response.
        try {
          final active = await getActiveSession();
          if (active != null &&
              active.status == SessionStatus.active &&
              active.classId == classId &&
              active.slot.date == slot.date &&
              active.slot.slotNumber == slot.slotNumber) {
            _pendingStartRequestIds.remove(operationKey);
            return active;
          }
        } on Exception {
          // Preserve the original uncertain outcome when reconciliation fails.
        }
      }
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
    final elapsed = Stopwatch()..start();
    final requestId = _pendingQrRequestIds.putIfAbsent(sessionId, () {
      final random = Random.secure();
      return List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    });
    // Retain the same id on an unknown outcome. The server replays one ticket.
    dynamic data;
    try {
      data = await _post('issue_qr', {
        'session_id': sessionId,
        'request_id': requestId,
      });
    } on TeacherApiException catch (error) {
      if (error.code != 'operation_unconfirmed') rethrow;
      // Receipt server_time is sampled after the original write. Measure only
      // this read's transit rather than subtracting the failed POST again.
      elapsed.reset();
      try {
        data = await _get(
          'qr_receipt',
          query: {'session_id': sessionId, 'request_id': requestId},
        );
      } on Exception {
        throw error;
      }
      if (data == null) rethrow;
    }
    final ticket = QrTicketModel.fromJson(
      _asMap(data, 'issue_qr response'),
      transit: elapsed.elapsed,
    );
    _pendingQrRequestIds.remove(sessionId);
    if (ticket.remainingSeconds == 0) {
      throw const TeacherApiException(
        code: 'ticket_expired',
        message: 'Mã QR đã hết hạn trong lúc chờ máy chủ. Đang lấy mã mới.',
      );
    }
    return ticket;
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

  Future<dynamic> _getOnce(
    String action,
    Map<String, String> query,
  ) => runZoned(
    () => _getLoggedOnce(action, query),
    zoneValues: {
      #action: action,
      #requestState: <String, bool>{'expired': false},
      #requestId:
          '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}',
    },
  );
  Future<dynamic> _getLoggedOnce(
    String action,
    Map<String, String> query,
  ) async {
    final timer = Stopwatch()..start();
    PerformanceLog.mark('api_start', {'action': action});
    final uri = _endpoint.replace(
      queryParameters: {
        ..._endpoint.queryParameters,
        'action': action,
        '_trace_id': Zone.current[#requestId] as String,
        'teacher_key': _teacherKey,
        ...query,
      },
    );
    try {
      final response = await _withDeadline(
        _readWithOneRetry(uri),
        mutation: false,
      );
      final data = _decodeEnvelope(response, action);
      PerformanceLog.mark('api_done', {
        'action': action,
        'ms': timer.elapsedMilliseconds,
      });
      return data;
    } catch (error) {
      PerformanceLog.mark('api_failed', {
        'request_id': Zone.current[#requestId],
        'code': error is AttendanceApiException
            ? error.code
            : 'transport_error',
        'action': action,
        'ms': timer.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  Future<http.Response> _readWithOneRetry(Uri uri) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _getAppsScriptResponse(uri);
        if (attempt == 0 &&
            !_hasJsonBody(response) &&
            (response.statusCode == 200 || response.statusCode >= 500)) {
          continue;
        }
        return response;
      } on TeacherApiException catch (error) {
        if (attempt != 0 ||
            !{
              'redirect_to_execution',
              'content_unavailable',
            }.contains(error.code)) {
          rethrow;
        }
        PerformanceLog.mark('api_retry', {
          'request_id': Zone.current[#requestId],
          'code': error.code,
        });
        uri = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            '_request_nonce': DateTime.now().microsecondsSinceEpoch.toString(),
          },
        );
      }
    }
    throw StateError('Unreachable read retry');
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
    final initialResponse = await _sendObserved(request);
    return _followAppsScriptRedirect(initialResponse);
  }

  Future<dynamic> _post(String action, Map<String, dynamic> body) => runZoned(
    () => _postLogged(action, body),
    zoneValues: {
      #action: action,
      #requestState: <String, bool>{'expired': false},
      #requestId:
          '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}',
    },
  );
  Future<dynamic> _postLogged(String action, Map<String, dynamic> body) async {
    final timer = Stopwatch()..start();
    PerformanceLog.mark('api_start', {'action': action});
    try {
      final result = await _withDeadline(
        _postOnce(action, body),
        mutation: true,
      );
      PerformanceLog.mark('api_done', {
        'action': action,
        'ms': timer.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      PerformanceLog.mark('api_failed', {
        'request_id': Zone.current[#requestId],
        'action': action,
        'ms': timer.elapsedMilliseconds,
        'code': error is AttendanceApiException
            ? error.code
            : 'transport_error',
      });
      rethrow;
    }
  }

  Future<T> _withDeadline<T>(
    Future<T> operation, {
    required bool mutation,
  }) async {
    try {
      return await operation.timeout(requestTimeout);
    } on TimeoutException {
      (Zone.current[#requestState] as Map<String, bool>?)?['expired'] = true;
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
        '_trace_id': Zone.current[#requestId] as String,
        'teacher_key': _teacherKey,
        ...body,
      });
    final initialResponse = await _sendObserved(request);
    try {
      final response = await _followAppsScriptRedirect(initialResponse)
          .timeout(const Duration(seconds: 10));
      return _decodeEnvelope(response, action);
    } on TimeoutException {
      throw const TeacherApiException(
        code: 'operation_unconfirmed',
        message: 'Chưa nhận được kết quả. Đang đối soát trạng thái máy chủ.',
      );
    } on TeacherApiException catch (error) {
      if (error.code.startsWith('redirect_') ||
          error.code == 'invalid_response' ||
          error.code == 'content_unavailable') {
        throw TeacherApiException(
          code: 'operation_unconfirmed',
          message: 'Chưa nhận được xác nhận từ máy chủ. Kiểm tra trạng thái phiên trước khi thử lại.',
          details: {'cause': error.code},
        );
      }
      rethrow;
    }
  }

  /// Apps Script's ContentService returns a 302 to a short-lived
  /// script.googleusercontent.com URL. Follow only that trusted target with a
  /// GET to obtain the JSON envelope.
  Future<http.Response> _followAppsScriptRedirect(
    http.Response response,
  ) async {
    final location = response.headers['location'];
    if (!{301, 302, 303, 307, 308}.contains(response.statusCode)) {
      return response;
    }

    if (location == null) {
      throw const TeacherApiException(
        code: 'redirect_missing_location',
        message: 'API thiếu địa chỉ chuyển hướng.',
      );
    }
    final redirectUri = _endpoint.resolve(location);
    if (redirectUri.host == 'accounts.google.com') {
      throw const TeacherApiException(
        code: 'redirect_auth',
        message: 'API yêu cầu đăng nhập. Kiểm tra quyền deployment.',
      );
    }
    if (redirectUri.scheme != 'https' ||
        redirectUri.host != 'script.googleusercontent.com') {
      throw const TeacherApiException(
        code: 'redirect_untrusted',
        message: 'API chuyển hướng tới địa chỉ không được phép.',
      );
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
    final visited = <String>{};
    var htmlRetries = 0;
    for (var hop = 0; hop < 5; hop++) {
      if (!visited.add(uri.toString())) {
        throw const TeacherApiException(
          code: 'redirect_loop',
          message: 'API bị lặp chuyển hướng. Hãy thử tải lại.',
        );
      }
      var response = await _getWithoutRedirect(uri);
      while (true) {
        if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
          final target = uri.resolve(response.headers['location'] ?? '');
          if (target.scheme == 'https' &&
              target.host == _endpoint.host &&
              target.path == _endpoint.path) {
            throw const TeacherApiException(
              code: 'redirect_to_execution',
              message: 'Google chuyển ngược về API thay vì trả dữ liệu. Hãy thử tải lại.',
            );
          }
          if (target.host == 'accounts.google.com') {
            throw const TeacherApiException(
              code: 'redirect_auth',
              message: 'API yêu cầu đăng nhập. Kiểm tra quyền deployment.',
            );
          }
          if (target.scheme != 'https' ||
              target.host != 'script.googleusercontent.com') {
            throw const TeacherApiException(
              code: 'redirect_untrusted',
              message: 'API chuyển hướng tới địa chỉ không được phép.',
            );
          }
          uri = target;
          break;
        }
        if (response.statusCode == 404 || response.statusCode == 410) {
          throw const TeacherApiException(
            code: 'content_unavailable',
            message: 'Google không trả được nội dung API. Hãy thử tải lại.',
          );
        }
        if (_hasJsonBody(response) ||
            response.statusCode != 200 ||
            htmlRetries >= 2) {
          return response;
        }
        htmlRetries++;
        await Future<void>.delayed(Duration(milliseconds: 250 * htmlRetries));
        response = await _getWithoutRedirect(uri);
      }
    }
    throw const TeacherApiException(
      code: 'redirect_limit',
      message: 'API chuyển hướng quá nhiều lần.',
    );
  }

  Future<http.Response> _sendObserved(http.BaseRequest request) async {
    if ((Zone.current[#requestState] as Map<String, bool>?)?['expired'] ==
        true) {
      throw TimeoutException('Request deadline elapsed');
    }
    final timer = Stopwatch()..start();
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    PerformanceLog.mark('api_http', {
      'action': Zone.current[#action],
      'request_id': Zone.current[#requestId],
      'host': request.url.host,
      'method': request.method,
      'status': response.statusCode,
      'content_type': response.headers['content-type']?.split(';').first,
      'bytes': response.bodyBytes.length,
      'ms': timer.elapsedMilliseconds,
      'redirect_host': Uri.tryParse(response.headers['location'] ?? '')?.host,
    });
    return response;
  }

  Future<http.Response> _getWithoutRedirect(Uri uri) async {
    final request = http.Request('GET', uri)
      ..persistentConnection = false
      ..followRedirects = false
      ..maxRedirects = 0;
    return _sendObserved(request);
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
        message: response.statusCode == 401 || response.statusCode == 403
            ? 'Máy chủ từ chối quyền truy cập. Vui lòng kiểm tra cấu hình tài khoản.'
            : 'Máy chủ trả về dữ liệu không hợp lệ. Vui lòng thử lại; đây không nhất thiết là lỗi Wi-Fi.',
        details: {
          'action': action,
          'http_status': response.statusCode,
          'content_type': response.headers['content-type'] ?? 'unknown',
        },
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
            ? Map<String, dynamic>.from(
                errorMap['details'] as Map<Object?, Object?>,
              )
            : null,
      );
    }
    return envelope['data'];
  }

  Map<String, dynamic> _asMap(dynamic value, String context) {
    if (value is Map<Object?, Object?>) {
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
