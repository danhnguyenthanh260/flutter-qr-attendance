import 'package:flutter/foundation.dart';

import '../core/utils/date_key.dart';
import '../data/models/attendance_summary.dart';
import '../data/models/class_model.dart';
import '../data/models/session_model.dart';
import '../data/services/attendance_api_exception.dart';
import '../data/services/attendance_service.dart';
import '../data/services/google_apps_script_attendance_service.dart';

enum AttendanceDataStatus {
  loading,
  ok,
  noClasses,
  noSession,
  rosterMissing,
  unavailable,
}

class AttendanceResultsProvider extends ChangeNotifier {
  final AttendanceService _service;
  final DateTime Function() _clock;

  List<ClassModel> _classes = const [];
  ClassModel? _selectedClass;
  String _selectedDate = '';
  List<AttendanceSession> _sessions = const [];
  AttendanceSession? _selectedSession;
  AttendanceSummary? _summary;

  AttendanceDataStatus _status = AttendanceDataStatus.loading;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;

  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _isDisposed = false;

  int _requestToken = 0;

  AttendanceResultsProvider({
    AttendanceService? service,
    DateTime Function()? clock,
  })  : _service = service ?? createConfiguredTeacherAttendanceService(),
        _clock = clock ?? DateTime.now {
    _selectedDate = dateKey(_clock());
  }

  List<ClassModel> get classes => _classes;
  ClassModel? get selectedClass => _selectedClass;
  String get selectedDate => _selectedDate;
  List<AttendanceSession> get sessions => _sessions;
  AttendanceSession? get selectedSession => _selectedSession;
  AttendanceSummary? get summary => _summary;
  AttendanceDataStatus get status => _status;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get isInitialized => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  bool get hasData => _summary != null;
  bool get isToday => _selectedDate == dateKey(_clock());

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _status = AttendanceDataStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      _classes = await _service.getClasses();
    } catch (error) {
      _classes = const [];
      _status = AttendanceDataStatus.unavailable;
      _errorMessage = _describe(error);
      _notify();
      return;
    }

    if (_classes.isEmpty) {
      _status = AttendanceDataStatus.noClasses;
      _notify();
      return;
    }

    _selectedClass ??= _classes.first;
    await _reloadScope();
  }

  Future<void> selectClass(ClassModel? classModel) async {
    if (classModel == null || classModel.id == _selectedClass?.id) return;
    _selectedClass = classModel;
    await _reloadScope();
  }

  Future<void> selectDate(DateTime date) async {
    final key = dateKey(date);
    if (key == _selectedDate) return;
    _selectedDate = key;
    await _reloadScope();
  }

  Future<void> selectSession(AttendanceSession? session) async {
    if (session == null || session.id == _selectedSession?.id) return;
    _selectedSession = session;
    _summary = null;
    _lastUpdatedAt = null;
    await _loadResults(++_requestToken);
  }

  Future<void> refresh() async {
    if (_selectedSession == null) {
      await _reloadScope();
      return;
    }
    if (_isRefreshing) return;
    await _loadResults(_requestToken);
  }

  Future<void> _reloadScope() async {
    final token = ++_requestToken;

    _status = AttendanceDataStatus.loading;
    _summary = null;
    _selectedSession = null;
    _errorMessage = null;
    _lastUpdatedAt = null;
    _notify();

    try {
      final sessions = await _service.listSessions(
        classId: _selectedClass?.id,
        date: _selectedDate,
      );
      if (token != _requestToken) return;

      _sessions = [...sessions]
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
      _selectedSession = _pickDefaultSession(_sessions);
    } catch (error) {
      if (token != _requestToken) return;
      _sessions = const [];
      _status = AttendanceDataStatus.unavailable;
      _errorMessage = _describe(error);
      _notify();
      return;
    }

    if (_selectedSession == null) {
      _status = AttendanceDataStatus.noSession;
      _notify();
      return;
    }

    await _loadResults(token);
  }

  Future<void> _loadResults(int token) async {
    final session = _selectedSession;
    if (session == null) return;

    _isRefreshing = true;
    if (_summary == null) {
      _status = AttendanceDataStatus.loading;
    }
    _notify();

    try {
      final results = await _service.getSessionResults(session.id);
      if (token != _requestToken) return;

      _summary = AttendanceSummary.fromSessionResults(results);
      _selectedSession = results.session;
      _syncSessionInList(results.session);
      _lastUpdatedAt = results.fetchedAt;
      _status = AttendanceDataStatus.ok;
      _errorMessage = null;
    } catch (error) {
      if (token != _requestToken) return;

      _summary = null;
      if (error is AttendanceApiException && error.isRosterMissing) {
        _status = AttendanceDataStatus.rosterMissing;
      } else {
        _status = AttendanceDataStatus.unavailable;
      }
      _errorMessage = _describe(error);
    } finally {
      if (token == _requestToken) {
        _isRefreshing = false;
        _notify();
      }
    }
  }

  AttendanceSession? _pickDefaultSession(List<AttendanceSession> sessions) {
    if (sessions.isEmpty) return null;
    for (final session in sessions) {
      if (session.status == SessionStatus.active ||
          session.status == SessionStatus.closing) {
        return session;
      }
    }
    return sessions.first;
  }

  void _syncSessionInList(AttendanceSession session) {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index < 0) return;
    final updated = [..._sessions];
    updated[index] = session;
    _sessions = updated;
  }

  String _describe(Object error) {
    if (error is AttendanceApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
