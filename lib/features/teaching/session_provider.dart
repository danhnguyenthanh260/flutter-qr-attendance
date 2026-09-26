import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/storage/session_storage.dart';
import '../../core/utils/performance_log.dart';
import '../../data/models/class_model.dart';
import '../../data/models/qr_ticket_model.dart';
import '../../data/models/session_model.dart';
import '../../data/models/teaching_overview.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/teaching_repository.dart';
import '../qr/qr_controller.dart';
import 'attendance_date_policy.dart';

class SessionProvider extends ChangeNotifier {
  final AttendanceRepository _service;
  final SessionStorage _storage;

  SessionProvider({required this._service, SessionStorage? storage})
    : _storage = storage ?? LocalFileSessionStorage() {
    qr = QrController(
      issueTicket: _service.getNextQrTicket,
      onSessionInactive: () async {
        _activeSession = null;
        await _storage.clearActiveSession();
        _errorMessage = 'Phiên điểm danh đã ngừng nhận lượt quét mới. Vui lòng bắt đầu phiên mới khi phiên trước kết thúc.';
        notifyListeners();
      },
    );
  }
  late final QrController qr;

  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;

  List<SessionSlot> _slots = [];
  SessionSlot? _selectedSlot;

  AttendanceSession? _activeSession;

  bool _isLoading = false;
  bool _isLoadingSlots = false;
  bool _isRestoringSession = false;
  bool _sessionVerified = false;
  Future<void>? _startup;
  int _slotRequest = 0;
  bool _isStartingSession = false;
  bool _isClosingSession = false;
  String? _errorMessage;

  Future<
    ({
      DateTime saved,
      List<ClassModel> classes,
      Map<String, TeachingOverview> data,
    })?
  >
  readScheduleSnapshot() async {
    final service = _service;
    if (service is! ScheduleSnapshotSource) return null;
    final snapshot = await (service as ScheduleSnapshotSource)
        .readScheduleSnapshot();
    if (snapshot != null && _classes.isEmpty) {
      _classes = snapshot.classes;
      notifyListeners();
    }
    return snapshot;
  }

  Future<Map<String, TeachingOverview>> refreshTeachingWorkspace() async {
    final service = _service;
    if (service is! TeachingWorkspaceRepository) {
      await loadInitialData(loadDefaultSlots: false);
      return loadWeeklyOverview();
    }
    final workspace = await (service as TeachingWorkspaceRepository)
        .refreshWorkspace();
    if (_isDisposed) return workspace.overview;
    if (_activeSession?.id != workspace.activeSession?.id) {
      stopQrRotation();
    }
    _classes = workspace.classes;
    _activeSession = workspace.activeSession;
    _sessionVerified = true;
    _errorMessage = null;
    _isLoading = false;
    _isRestoringSession = false;
    if (_activeSession == null) {
      stopQrRotation();
      await _storage.clearActiveSession();
    } else {
      await _storage.saveActiveSession(_activeSession!);
    }
    if (!_isDisposed) notifyListeners();
    return workspace.overview;
  }

  Future<Map<String, TeachingOverview>> loadWeeklyOverview() async {
    final service = _service;
    if (service is TeachingRepository) {
      return (service as TeachingRepository).getWeeklyOverview();
    }
    final classes = await service.getClasses();
    final entries = await Future.wait(
      classes.map((c) async => MapEntry(c.id, await loadOverview(c.id))),
    );
    return Map.fromEntries(entries);
  }

  void selectLesson(ClassModel classModel, SessionSlot slot) {
    // The calendar already resolved the class and exact dated slot. Do not
    // fetch another slot list or allow an older selection request to replace it.
    _slotRequest++;
    _selectedClass = classModel;
    _slots = [slot];
    _selectedSlot = slot;
    _isLoadingSlots = false;
    notifyListeners();
  }

  Future<TeachingOverview> loadOverview(String classId) async {
    final service = _service;
    if (service is TeachingRepository) {
      return (service as TeachingRepository).getTeachingOverview(classId);
    }
    return TeachingOverview(
      slots: await service.getSlotsForClass(classId),
      roster: const [],
      sessions: await service.listSessions(classId: classId),
      attendance: const [],
    );
  }

  Future<int> importRoster(Map<String, dynamic> payload) async {
    final service = _service;
    if (service is! TeachingRepository) {
      throw StateError('Backend chưa hỗ trợ nhập roster.');
    }
    final count = await (service as TeachingRepository).importRoster(payload);
    _classes = await _service.getClasses();
    notifyListeners();
    return count;
  }

  // Getters
  List<ClassModel> get classes => _classes;
  ClassModel? get selectedClass => _selectedClass;
  List<SessionSlot> get slots => _slots;
  SessionSlot? get selectedSlot => _selectedSlot;
  AttendanceSession? get activeSession => _activeSession;
  bool get isLoading => _isLoading;
  bool get isLoadingSlots => _isLoadingSlots;
  bool get isRestoringSession => _isRestoringSession;
  bool get canStartSession =>
      _sessionVerified &&
      !_isRestoringSession &&
      !_isLoadingSlots &&
      _selectedSlot != null;
  bool get isStartingSession => _isStartingSession;
  bool get isClosingSession => _isClosingSession;
  String? get errorMessage => _errorMessage;
  bool get hasActiveSession =>
      _activeSession != null && _activeSession!.status == SessionStatus.active;

  QrTicketModel? get currentTicket => qr.currentTicket;
  int get countdownSeconds => qr.countdownSeconds;
  bool get isRotatingQr => qr.isRotating;
  bool get isOffline => qr.isOffline;

  // Load initial classes and restore session state (Issue #21)
  bool get isInitialized => _classes.isNotEmpty && _sessionVerified;

  Future<void> loadInitialData({
    bool force = false,
    bool loadDefaultSlots = true,
  }) => _startup ??= _loadInitialData(loadDefaultSlots: loadDefaultSlots);

  Future<void> _loadInitialData({required bool loadDefaultSlots}) async {
    _isLoading = true;
    _isRestoringSession = true;
    _sessionVerified = false;
    _errorMessage = null;
    notifyListeners();
    final recovery = _recoverSession();
    try {
      _classes = await _service.getClasses();
      PerformanceLog.mark('classes_ready', {'count': _classes.length});
      _isLoading = false;
      notifyListeners();
      if (loadDefaultSlots && _classes.isNotEmpty) {
        await selectClass(_selectedClass ?? _classes.first);
      }
    } catch (e) {
      _errorMessage = 'Không thể tải dữ liệu phiên: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await recovery;
    _startup = null;
  }

  Future<void> _recoverSession() async {
    try {
      await _restoreActiveSession();
      _sessionVerified = true;
      PerformanceLog.mark('session_verified', {'active': hasActiveSession});
    } catch (e) {
      _errorMessage = 'Chưa xác minh được phiên trên máy chủ: $e';
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  /// Slots and the server-side active-session lookup are independent. Starting
  /// them together prevents the launch screen from waiting for two Apps Script
  /// round trips in sequence.
  Future<void> _restoreActiveSession() async {
    final values = await Future.wait<Object?>([
      _service.getActiveSession(),
      _storage.loadActiveSession(),
    ]);
    final serverSession = values[0] as AttendanceSession?;
    final cachedSession = values[1] as AttendanceSession?;

    if (serverSession != null && serverSession.status == SessionStatus.active) {
      _activeSession = serverSession;
      await _storage.saveActiveSession(serverSession);
      unawaited(startQrRotation());
    } else if (cachedSession != null) {
      stopQrRotation();
      // Cache exists but server is not active or closed -> clear cache, no reopening.
      await _storage.clearActiveSession();
      _activeSession = null;
    } else {
      stopQrRotation();
      _activeSession = null;
    }
  }

  // Select class and fetch slots
  Future<void> selectClass(ClassModel? classModel) async {
    if (_selectedClass == classModel && _slots.isNotEmpty) return;

    _selectedClass = classModel;
    _slots = [];
    _selectedSlot = null;
    final request = ++_slotRequest;
    _isLoadingSlots = classModel != null;
    notifyListeners();

    if (classModel != null) {
      try {
        final slots = await _service.getSlotsForClass(classModel.id);
        if (request != _slotRequest || _isDisposed) return;
        _slots = slots;
        PerformanceLog.mark('slots_ready', {'count': slots.length});
        if (_slots.isNotEmpty) {
          _selectedSlot = _slots.first;
        }
      } catch (e) {
        if (request != _slotRequest || _isDisposed) return;
        _errorMessage = 'Không thể tải ca học: $e';
      } finally {
        if (request == _slotRequest) _isLoadingSlots = false;
      }
      notifyListeners();
    }
  }

  // Select slot
  void selectSlot(SessionSlot? slot) {
    _selectedSlot = slot;
    notifyListeners();
  }

  // Start Session with Debounce / Guard against double-click
  Future<bool> startSession() async {
    if (_isStartingSession) {
      return false;
    }

    // If session already active, don't create duplicate
    if (hasActiveSession) {
      return true;
    }
    if (!canStartSession) return false;

    if (_selectedClass == null || _selectedSlot == null) {
      _errorMessage = 'Vui lòng chọn đầy đủ Lớp học và Ca học';
      notifyListeners();
      return false;
    }

    _isStartingSession = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _service.startSession(
        classId: _selectedClass!.id,
        slot: _selectedSlot!,
      );
      if (session.status != SessionStatus.active) {
        stopQrRotation();
        _activeSession = null;
        await _storage.clearActiveSession();
        _isStartingSession = false;
        _errorMessage = session.status == SessionStatus.closing
            ? 'Phiên trước đang kết thúc và chờ các lượt đã quét gửi biểu mẫu. Vui lòng thử lại sau.'
            : 'Phiên này đã kết thúc. Vui lòng bắt đầu một phiên mới.';
        notifyListeners();
        return false;
      }
      _activeSession = session;
      await _storage.saveActiveSession(session);
      _isStartingSession = false;
      notifyListeners();
      await startQrRotation();
      notifyListeners();
      return hasActiveSession;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isStartingSession = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> startQrRotation() async {
    if (!hasActiveSession || _isClosingSession || _isDisposed) return;
    if (isPastAttendanceDate(_activeSession!.slot.date)) return;
    await qr.start(_activeSession!.id);
  }

  Future<void> refreshQrTicketNow() => startQrRotation();
  void stopQrRotation() => qr.stop();
  Future<void> checkTicketOnResume() => qr.resume();
  void setOffline(bool offline) => qr.setOffline(offline);

  // Close session with timeout, anti-double-click and no false success (Issue #21)
  Future<bool> closeSession() async {
    if (_activeSession == null) return false;
    if (_isClosingSession) return false;

    _isClosingSession = true;
    _errorMessage = null;
    // Dừng QR ngay lập tức để sinh viên không quét thêm
    stopQrRotation();
    notifyListeners();

    try {
      // Đợi xác nhận từ máy chủ API với timeout 5 giây
      await _service
          .closeSession(_activeSession!.id)
          .timeout(const Duration(seconds: 30));

      // Chỉ khi máy chủ xác nhận thành công mới xóa cache và đánh dấu closed
      await _storage.clearActiveSession();
      _activeSession = null;
      _isClosingSession = false;
      notifyListeners();
      return true;
    } on TimeoutException {
      // Không báo thành công giả khi timeout
      _isClosingSession = false;
      _errorMessage = 'Hết thời gian chờ phản hồi từ máy chủ khi đóng phiên. Vui lòng kiểm tra lại mạng.';
      notifyListeners();
      return false;
    } catch (e) {
      _isClosingSession = false;
      _errorMessage =
          'Lỗi khi đóng phiên: ${e.toString().replaceFirst('Exception: ', '')}';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    qr.dispose();
    super.dispose();
  }
}
