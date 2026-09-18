import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/class_model.dart';
import '../data/models/qr_ticket_model.dart';
import '../data/models/session_model.dart';
import '../data/services/attendance_service.dart';

class SessionProvider extends ChangeNotifier {
  final AttendanceService _service;

  SessionProvider({AttendanceService? service})
      : _service = service ?? MockAttendanceService();

  List<ClassModel> _classes = [];
  ClassModel? _selectedClass;

  List<SessionSlot> _slots = [];
  SessionSlot? _selectedSlot;

  AttendanceSession? _activeSession;

  bool _isLoading = false;
  bool _isStartingSession = false;
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
  String? get errorMessage => _errorMessage;
  bool get hasActiveSession =>
      _activeSession != null && _activeSession!.status == SessionStatus.active;

  QrTicketModel? get currentTicket => _currentTicket;
  int get countdownSeconds => _countdownSeconds;
  bool get isRotatingQr => _isRotatingQr;
  bool get isOffline => _isOffline;

  // Load initial classes
  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _classes = await _service.getClasses();
      if (_classes.isNotEmpty) {
        await selectClass(_classes.first);
      }
      _activeSession = await _service.getActiveSession();
      if (_activeSession != null && _activeSession!.status == SessionStatus.active) {
        await startQrRotation();
      }
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách lớp: $e';
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

    if (_selectedClass == null || _selectedSlot == null) {
      _errorMessage = 'Vui lòng chọn đầy đủ Lớp học và Ca học';
      notifyListeners();
      return false;
    }

    _isStartingSession = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activeSession = await _service.startSession(
        classId: _selectedClass!.id,
        slot: _selectedSlot!,
      );
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
    await _fetchNewTicket();
    startQrRotation();
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

  // Close session (Issue #21)
  Future<bool> closeSession() async {
    if (_activeSession == null) return false;

    _isLoading = true;
    stopQrRotation();
    notifyListeners();

    try {
      await _service.closeSession(_activeSession!.id);
      _activeSession = null;
      _currentTicket = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _qrTimer?.cancel();
    super.dispose();
  }
}
