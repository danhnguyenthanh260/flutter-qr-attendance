import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/qr_ticket_model.dart';
import '../../data/services/attendance_api_exception.dart';

enum QrPhase { stopped, issuing, valid, refreshing, recovering }

/// Owns ticket rotation only. Session persistence and UI stay outside this class.
class QrController extends ChangeNotifier {
  QrController({
    required this.issueTicket,
    required this.onSessionInactive,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Future<QrTicketModel> Function(String) issueTicket;
  final Future<void> Function() onSessionInactive;
  final DateTime Function() _clock;
  String? _sessionId;
  QrTicketModel? _ticket;
  Timer? _timer;
  int _epoch = 0;
  int _retry = 0;
  Future<void>? _pending;
  bool _disposed = false;
  QrPhase phase = QrPhase.stopped;
  int countdownSeconds = 0;
  String? errorMessage;
  bool get isRotating => phase != QrPhase.stopped;
  bool get isOffline => phase == QrPhase.recovering;
  int _remaining(QrTicketModel ticket) =>
      (ticket.localExpiresAt ?? ticket.expiresAt)
          .difference(_clock())
          .inSeconds
          .clamp(0, ticket.validSeconds);
  QrTicketModel? get currentTicket =>
      _ticket != null && _remaining(_ticket!) > 0 ? _ticket : null;

  Future<void> start(String sessionId) async {
    if (_disposed) return;
    if (_sessionId != sessionId) {
      stop();
      _sessionId = sessionId;
    }
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    await refresh();
  }

  void _tick() {
    if (_disposed || _sessionId == null) return;
    countdownSeconds = currentTicket == null ? 0 : _remaining(currentTicket!);
    if (countdownSeconds == 0) _ticket = null;
    notifyListeners();
    if (_retry > 0) {
      _retry--;
      return;
    }
    if (isOffline || countdownSeconds <= 8) unawaited(refresh());
  }

  Future<void> refresh() {
    if (_disposed || _sessionId == null) return Future.value();
    return _pending ??= _fetch(
      _epoch,
      _sessionId!,
    ).whenComplete(() => _pending = null);
  }

  Future<void> _fetch(int epoch, String sessionId) async {
    phase = currentTicket == null ? QrPhase.issuing : QrPhase.refreshing;
    notifyListeners();
    try {
      final ticket = await issueTicket(sessionId);
      if (_disposed || epoch != _epoch) return;
      if (_remaining(ticket) == 0) {
        throw const AttendanceApiException(
          code: 'ticket_expired',
          message: 'Mã QR đã hết hạn. Đang lấy mã mới.',
        );
      }
      _ticket = ticket;
      countdownSeconds = _remaining(ticket);
      phase = QrPhase.valid;
      errorMessage = null;
      _retry = 0;
    } catch (error) {
      if (_disposed || epoch != _epoch) return;
      if (error is AttendanceApiException &&
          error.code == 'session_not_active') {
        stop();
        await onSessionInactive();
        return;
      }
      phase = QrPhase.recovering;
      // Preserve an already valid ticket until its actual expiry.
      countdownSeconds = currentTicket == null ? 0 : _remaining(currentTicket!);
      _retry = 5;
      errorMessage = error is AttendanceApiException
          ? 'Chưa nhận được mã QR mới. ${error.message} App sẽ tự thử kết nối lại.'
          : 'Không kết nối được máy chủ cấp QR. App sẽ tự thử kết nối lại.';
    }
    if (!_disposed && epoch == _epoch) notifyListeners();
  }

  Future<void> resume() async {
    if (!isRotating) return;
    if (currentTicket == null) {
      await refresh();
    } else {
      countdownSeconds = _remaining(currentTicket!);
      notifyListeners();
    }
  }

  void setOffline(bool offline) {
    phase = offline
        ? QrPhase.recovering
        : (_sessionId == null ? QrPhase.stopped : QrPhase.valid);
    notifyListeners();
  }

  void stop() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    _sessionId = null;
    _ticket = null;
    countdownSeconds = 0;
    _retry = 0;
    errorMessage = null;
    phase = QrPhase.stopped;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
