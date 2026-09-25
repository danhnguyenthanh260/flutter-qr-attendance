import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/date_key.dart';
import '../../data/models/attendance_result_model.dart';
import '../../data/models/attendance_summary.dart';
import '../../data/models/class_model.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/services/attendance_api_exception.dart';

enum AttendanceDataStatus {
  loading,
  ok,
  noClasses,
  noSession,
  rosterMissing,
  unavailable,
}

class AttendanceResultsProvider extends ChangeNotifier {
  static const Duration defaultRefreshInterval = Duration(seconds: 12);

  final AttendanceRepository _service;
  final DateTime Function() _clock;
  final AttendanceSession? Function()? preferredSession;
  final Duration refreshInterval;

  List<ClassModel> _classes = const [];
  ClassModel? _selectedClass;
  String _selectedDate = '';
  List<AttendanceSession> _sessions = const [];
  AttendanceSession? _selectedSession;
  SessionResults? _snapshot;
  AttendanceSummary? _summary;

  AttendanceDataStatus _status = AttendanceDataStatus.loading;
  String? _errorMessage;
  String? _refreshErrorMessage;
  DateTime? _lastUpdatedAt;

  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _autoRefreshEnabled;
  bool _visible = true;
  bool _isDisposed = false;

  Timer? _refreshTimer;
  int _requestToken = 0;

  AttendanceResultsProvider({
    required this._service,
    DateTime Function()? clock,
    this.preferredSession,
    bool autoRefresh = true,
    this.refreshInterval = defaultRefreshInterval,
  }) : _clock = clock ?? DateTime.now,
       _autoRefreshEnabled = autoRefresh {
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
  String? get refreshErrorMessage => _refreshErrorMessage;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  bool get isInitialized => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  bool get autoRefreshEnabled => _autoRefreshEnabled;
  bool get hasData => _summary != null;
  bool get isToday => _selectedDate == dateKey(_clock());

  bool get canAutoRefresh =>
      _selectedSession != null &&
      _selectedSession!.status != SessionStatus.closed;

  Future<void> initialize({AttendanceSession? preferredSession}) async {
    if (_isInitialized) return;
    _isInitialized = true;
    _status = AttendanceDataStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      _classes = await _service.getClasses();
    } catch (error) {
      _isInitialized = false;
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
    await _reloadScope(
      preferredSession: preferredSession ?? this.preferredSession?.call(),
    );
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
    _snapshot = null;
    _summary = null;
    _refreshErrorMessage = null;
    _lastUpdatedAt = null;
    await _loadResults(++_requestToken);
    _scheduleNextRefresh();
  }

  Future<void> refresh() async {
    if (!_isInitialized) return initialize();
    if (_selectedSession == null) {
      await _reloadScope();
      return;
    }
    if (_isRefreshing) return;
    await _loadResults(_requestToken);
    _scheduleNextRefresh();
  }

  void setAutoRefresh(bool enabled) {
    if (_autoRefreshEnabled == enabled) return;
    _autoRefreshEnabled = enabled;
    if (enabled) {
      _scheduleNextRefresh();
    } else {
      _cancelTimer();
    }
    _notify();
  }

  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    _cancelTimer();
    if (!visible || !_isInitialized) return;
    final updated = _lastUpdatedAt;
    if (canAutoRefresh &&
        (updated == null || _clock().difference(updated) >= refreshInterval)) {
      unawaited(refresh());
    } else {
      _scheduleNextRefresh();
    }
  }

  void clearRefreshError() {
    if (_refreshErrorMessage == null) return;
    _refreshErrorMessage = null;
    _notify();
  }

  Future<void> _reloadScope({AttendanceSession? preferredSession}) async {
    final token = ++_requestToken;
    _cancelTimer();

    _status = AttendanceDataStatus.loading;
    _snapshot = null;
    _summary = null;
    _selectedSession = null;
    _errorMessage = null;
    _refreshErrorMessage = null;
    _lastUpdatedAt = null;
    _notify();

    final preferred = _preferredSessionForCurrentScope(preferredSession);
    if (preferred != null) {
      _selectedClass = _classes.firstWhere(
        (item) => item.id == preferred.classId,
      );
      _sessions = [preferred];
      _selectedSession = preferred;
      await _loadResults(token);
      _scheduleNextRefresh();
      unawaited(_refreshSessionOptionsInBackground(token));
      return;
    }

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
    _scheduleNextRefresh();
  }

  AttendanceSession? _preferredSessionForCurrentScope(
    AttendanceSession? session,
  ) {
    if (session == null || session.slot.date != _selectedDate) return null;
    return _classes.any((item) => item.id == session.classId) ? session : null;
  }

  /// The active session is already known by the session screen. Render its
  /// results first, then fill the session selector without blocking the table.
  Future<void> _refreshSessionOptionsInBackground(int token) async {
    try {
      final sessions = await _service.listSessions(
        classId: _selectedClass?.id,
        date: _selectedDate,
      );
      if (token != _requestToken) return;

      final ordered = [...sessions]
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
      final selected = _selectedSession;
      if (selected != null && !ordered.any((item) => item.id == selected.id)) {
        ordered.insert(0, selected);
      }
      _sessions = ordered;
      _notify();
    } catch (_) {
      // Results are already confirmed. A delayed session-selector refresh must
      // not hide them just because this non-critical request failed.
    }
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

      final previous = _snapshot;
      final merged = previous == null ? results : previous.mergeWith(results);

      _snapshot = merged;
      _summary = AttendanceSummary.fromSessionResults(merged);
      _selectedSession = merged.session;
      _syncSessionInList(merged.session);
      _lastUpdatedAt = merged.fetchedAt;
      _status = AttendanceDataStatus.ok;
      _errorMessage = null;
      _refreshErrorMessage = null;
    } catch (error) {
      if (token != _requestToken) return;

      if (error is AttendanceApiException && error.isRosterMissing) {
        _snapshot = null;
        _summary = null;
        _status = AttendanceDataStatus.rosterMissing;
        _errorMessage = error.message;
        _refreshErrorMessage = null;
      } else if (_summary != null) {
        _refreshErrorMessage = _describe(error);
      } else {
        _status = AttendanceDataStatus.unavailable;
        _errorMessage = _describe(error);
      }
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

  void _scheduleNextRefresh() {
    _cancelTimer();
    if (!_visible || !_autoRefreshEnabled || !canAutoRefresh || _isDisposed) {
      return;
    }
    _refreshTimer = Timer(refreshInterval, refresh);
  }

  void _cancelTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
    _cancelTimer();
    super.dispose();
  }
}
