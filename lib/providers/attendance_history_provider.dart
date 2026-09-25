import 'package:flutter/foundation.dart';

import '../core/utils/date_key.dart';
import '../data/models/attendance_result_model.dart';
import '../data/models/attendance_summary.dart';
import '../data/models/class_model.dart';
import '../data/models/session_day_group.dart';
import '../data/services/attendance_api_exception.dart';
import '../data/services/attendance_service.dart';
import '../data/services/google_apps_script_attendance_service.dart';

enum HistoryDataStatus { loading, ok, noClasses, empty, unavailable }

enum HistoryDetailStatus { none, loading, ok, rosterMissing, unavailable }

class AttendanceHistoryProvider extends ChangeNotifier {
  static const int defaultRangeDays = 14;

  final AttendanceService _service;
  final DateTime Function() _clock;

  List<ClassModel> _classes = const [];
  ClassModel? _selectedClass;
  late DateTime _fromDate;
  late DateTime _toDate;

  List<SessionDayGroup> _groups = const [];
  SessionDayGroup? _selectedGroup;
  AttendanceSummary? _detail;

  HistoryDataStatus _status = HistoryDataStatus.loading;
  HistoryDetailStatus _detailStatus = HistoryDetailStatus.none;
  String? _errorMessage;
  String? _detailErrorMessage;

  bool _isInitialized = false;
  bool _isDisposed = false;
  int _groupsToken = 0;
  int _detailToken = 0;

  AttendanceHistoryProvider({
    AttendanceService? service,
    DateTime Function()? clock,
  }) : _service = service ?? createConfiguredTeacherAttendanceService(),
       _clock = clock ?? DateTime.now {
    final today = startOfDay(_clock());
    _toDate = today;
    _fromDate = today.subtract(const Duration(days: defaultRangeDays - 1));
  }

  List<ClassModel> get classes => _classes;
  ClassModel? get selectedClass => _selectedClass;
  DateTime get fromDate => _fromDate;
  DateTime get toDate => _toDate;
  List<SessionDayGroup> get groups => _groups;
  SessionDayGroup? get selectedGroup => _selectedGroup;
  AttendanceSummary? get detail => _detail;
  HistoryDataStatus get status => _status;
  HistoryDetailStatus get detailStatus => _detailStatus;
  String? get errorMessage => _errorMessage;
  String? get detailErrorMessage => _detailErrorMessage;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _status = HistoryDataStatus.loading;
    _notify();

    try {
      _classes = await _service.getClasses();
    } catch (error) {
      _isInitialized = false;
      _classes = const [];
      _status = HistoryDataStatus.unavailable;
      _errorMessage = _describe(error);
      _notify();
      return;
    }

    if (_classes.isEmpty) {
      _status = HistoryDataStatus.noClasses;
      _notify();
      return;
    }

    _selectedClass ??= _classes.first;
    await loadGroups();
  }

  Future<void> selectClass(ClassModel? classModel) async {
    if (classModel == null || classModel.id == _selectedClass?.id) return;
    _selectedClass = classModel;
    await loadGroups();
  }

  Future<void> setRange(DateTime from, DateTime to) async {
    final lower = startOfDay(from);
    final upper = startOfDay(to);
    final normalizedFrom = lower.isAfter(upper) ? upper : lower;
    final normalizedTo = lower.isAfter(upper) ? lower : upper;

    if (normalizedFrom == _fromDate && normalizedTo == _toDate) return;
    _fromDate = normalizedFrom;
    _toDate = normalizedTo;
    await loadGroups();
  }

  Future<void> loadGroups() async {
    if (!_isInitialized) return initialize();
    final token = ++_groupsToken;
    _status = HistoryDataStatus.loading;
    _errorMessage = null;
    _groups = const [];
    _clearDetail();
    _notify();

    List<SessionDayGroup> groups;
    try {
      final sessions = await _service.listSessions(classId: _selectedClass?.id);
      if (token != _groupsToken) return;

      final withinRange = sessions
          .where(
            (session) => isDateKeyWithin(session.slot.date, _fromDate, _toDate),
          )
          .toList();
      groups = SessionDayGroup.fromSessions(withinRange);
    } catch (error) {
      if (token != _groupsToken) return;
      _status = HistoryDataStatus.unavailable;
      _errorMessage = _describe(error);
      _notify();
      return;
    }

    _groups = groups;
    _status = groups.isEmpty ? HistoryDataStatus.empty : HistoryDataStatus.ok;
    _notify();

    if (groups.isNotEmpty) {
      await selectGroup(groups.first);
    }
  }

  Future<void> selectGroup(SessionDayGroup? group) async {
    if (group == null) return;

    _selectedGroup = group;
    _detail = null;
    _detailErrorMessage = null;
    _detailStatus = HistoryDetailStatus.loading;
    _notify();

    final token = ++_detailToken;
    final snapshots = <SessionResults>[];
    Object? failure;

    await Future.wait(
      group.sessionIds.map((sessionId) async {
        try {
          snapshots.add(await _service.getSessionResults(sessionId));
        } catch (error) {
          failure ??= error;
        }
      }),
    );

    if (token != _detailToken) return;

    final error = failure;
    if (error != null) {
      _detail = null;
      _detailErrorMessage = _describe(error);
      _detailStatus = error is AttendanceApiException && error.isRosterMissing
          ? HistoryDetailStatus.rosterMissing
          : HistoryDetailStatus.unavailable;
      _notify();
      return;
    }

    if (snapshots.isEmpty) {
      _detail = null;
      _detailErrorMessage = 'Buổi học này chưa có phiên nào để đọc kết quả.';
      _detailStatus = HistoryDetailStatus.unavailable;
      _notify();
      return;
    }

    _detail = AttendanceSummary.fromMultipleSessions(snapshots);
    _detailStatus = HistoryDetailStatus.ok;
    _detailErrorMessage = null;
    _notify();
  }

  Future<void> refreshDetail() async {
    final group = _selectedGroup;
    if (group == null) return;
    _detailToken++;
    await selectGroup(group);
  }

  void _clearDetail() {
    _selectedGroup = null;
    _detail = null;
    _detailErrorMessage = null;
    _detailStatus = HistoryDetailStatus.none;
    _detailToken++;
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
