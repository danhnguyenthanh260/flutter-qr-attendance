import 'dart:async';
import 'package:flutter/material.dart';
import '../core/storage/session_storage.dart';
import '../data/models/class_model.dart';
import '../data/models/qr_ticket_model.dart';
import '../data/models/session_model.dart';
import '../data/services/attendance_service.dart';
import '../data/services/google_apps_script_attendance_service.dart';

class SessionProvider extends ChangeNotifier {
  final AttendanceService _service;
  final SessionStorage _storage;

  SessionProvider({
    AttendanceService? service,
    SessionStorage? storage,
  })  : _service = service ?? createConfiguredTeacherAttendanceService(),
        _storage = storage ?? LocalFileSessionStorage();

  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;

  List<SessionSlot> _slots = [];
  SessionSlot? _selectedSlot;

  AttendanceSession? _activeSession;

  bool _isLoading = false;
  bool _isStartingSession = false;
  bool _isClosingSession = false;
  String? _errorMessage;

  // QR Rotation state (Issue #10)
  QrTicketModel? _currentTicket;
  int _countdownSeconds = 30;
  Timer? _qrTimer;
  bool _isRotatingQr = false;
  bool _isOffline = false;

  // Getters
  List<ClassModel> get classes => _classes;
  ClassModel? get selectedClass => _selectedClass;
  List<SessionSlot> get slots => _slots;
  SessionSlot? get selectedSlot => _selectedSlot;
  AttendanceSession? get activeSession => _activeSession;
  bool get isLoading => _isLoading;
  bool get isStartingSession => _isStartingSession;
  bool get isClosingSession => _isClosingSession;
  String? get errorMessage => _errorMessage;
  bool get hasActiveSession =>
      _activeSession != null && _activeSession!.status == SessionStatus.active;

  QrTicketModel? get currentTicket => _currentTicket;
  int get countdownSeconds => _countdownSeconds;
  bool get isRotatingQr => _isRotatingQr;
  bool get isOffline => _isOffline;

  // Load initial classes and restore session state (Issue #21)
  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _classes = await _service.getClasses();
      if (_classes.isNotEmpty) {
        await selectClass(_classes.first);
      }

      // Check server active session and local storage
      final serverSession = await _service.getActiveSession();
      final cachedSession = await _storage.loadActiveSession();

      if (serverSession != null && serverSession.status == SessionStatus.active) {
        _activeSession = serverSession;
        await _storage.saveActiveSession(serverSession);
        await startQrRotation();
      } else if (cachedSession != null) {
        // Cache exists but server is not active or closed -> clear cache, no reopening
        await _storage.clearActiveSession();
        _activeSession = null;
      } else {
        _activeSession = null;
      }
    } catch (e) {
      _errorMessage = 'Không thể tải dữ liệu phiên: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Select class and fetch slots
  Future<void> selectClass(ClassModel? classModel) async {
    if (_selectedClass == classModel && _slots.isNotEmpty) return;

    _selectedClass = classModel;
    _slots = [];
    _selectedSlot = null;
    notifyListeners();

    if (classModel != null) {
      try {
        _slots = await _service.getSlotsForClass(classModel.id);
        if (_slots.isNotEmpty) {
          _selectedSlot = _slots.first;
        }
      } catch (e) {
        _errorMessage = 'Không thể tải ca học: $e';
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
      _activeSession = session;
      await _storage.saveActiveSession(session);
      _isStartingSession = false;
      await startQrRotation();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isStartingSession = false;
      notifyListeners();
      return false;
    }
  }

  // QR 30-second Countdown & Rotation (Issue #10)
  Future<void> startQrRotation() async {
    if (_activeSession == null) return;
    _isRotatingQr = true;
    _qrTimer?.cancel();

    await _fetchNewTicket();

    _qrTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isOffline) return;

      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();
      } else {
        await _fetchNewTicket();
      }
    });
  }

  Future<void> _fetchNewTicket() async {
    if (_activeSession == null) return;
    try {
      _currentTicket = await _service.getNextQrTicket(_activeSession!.id);
      _countdownSeconds = 30;
      _isOffline = false;
      notifyListeners();
    } catch (e) {
      _isOffline = true;
      _errorMessage = 'Không thể làm mới mã QR: $e';
      notifyListeners();
    }
  }

  Future<void> refreshQrTicketNow() async {
    _qrTimer?.cancel();
    await startQrRotation();
  }

  void stopQrRotation() {
    _qrTimer?.cancel();
    _isRotatingQr = false;
  }

  // App Lifecycle resume check (anti-expired QR display)
  Future<void> checkTicketOnResume() async {
    if (_activeSession == null || !_isRotatingQr) return;

    if (_currentTicket == null || _currentTicket!.isExpired) {
      // Mã cũ đã hết hạn trong lúc sleep/minimize, lập tức sinh vé mới
      await refreshQrTicketNow();
    } else {
      // Cập nhật lại số giây thực tế còn lại
      _countdownSeconds = _currentTicket!.remainingSeconds;
      notifyListeners();
    }
  }

  void setOffline(bool offline) {
    _isOffline = offline;
    notifyListeners();
  }

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
          .timeout(const Duration(seconds: 5));

      // Chỉ khi máy chủ xác nhận thành công mới xóa cache và đánh dấu closed
      await _storage.clearActiveSession();
      _activeSession = null;
      _currentTicket = null;
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
      _errorMessage = 'Lỗi khi đóng phiên: ${e.toString().replaceFirst('Exception: ', '')}';
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
    _qrTimer?.cancel();
    super.dispose();
  }
}
