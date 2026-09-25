import 'dart:async';

import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/models/qr_ticket_model.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class ClosingService extends MockAttendanceService {
  ClosingService() : super(simulateDelay: false);
  bool returnClosing = false;
  bool rejectQr = false;
  int qrCalls = 0;
  Completer<QrTicketModel>? delayedQr;

  @override
  Future<AttendanceSession> startSession({
    required String classId,
    required SessionSlot slot,
  }) async {
    final session = await super.startSession(classId: classId, slot: slot);
    if (!returnClosing) return session;
    return AttendanceSession(
      id: session.id,
      classId: classId,
      className: session.className,
      slot: slot,
      openedAt: session.openedAt,
      status: SessionStatus.closing,
    );
  }

  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) async {
    qrCalls++;
    if (rejectQr) {
      throw const AttendanceApiException(
        code: 'session_not_active',
        message: 'Closed remotely',
      );
    }
    if (delayedQr != null) return delayedQr!.future;
    return super.getNextQrTicket(sessionId);
  }
}

void main() {
  late ClosingService service;
  late MemorySessionStorage storage;
  late SessionProvider provider;

  setUp(() async {
    service = ClosingService();
    storage = MemorySessionStorage();
    provider = SessionProvider(service: service, storage: storage);
    await provider.loadInitialData();
  });
  tearDown(() => provider.dispose());

  test(
    'a closing start response never reports success or requests QR',
    () async {
      service.returnClosing = true;
      expect(await provider.startSession(), false);
      expect(service.qrCalls, 0);
      expect(provider.isRotatingQr, false);
      expect(provider.activeSession, null);
      expect(await storage.loadActiveSession(), null);
      expect(provider.errorMessage, contains('đang kết thúc'));
    },
  );

  test('a server-closed session clears QR and cached active state', () async {
    expect(await provider.startSession(), true);
    service.rejectQr = true;
    await provider.refreshQrTicketNow();
    expect(provider.hasActiveSession, false);
    expect(provider.currentTicket, null);
    expect(provider.isRotatingQr, false);
    expect(await storage.loadActiveSession(), null);
  });

  test('QR received after close cannot restore a closed session', () async {
    await provider.startSession();
    final oldTicket = provider.currentTicket!;
    service.delayedQr = Completer<QrTicketModel>();
    final refresh = provider.refreshQrTicketNow();
    expect(await provider.closeSession(), true);
    service.delayedQr!.complete(oldTicket);
    await refresh;
    expect(provider.hasActiveSession, false);
    expect(provider.currentTicket, null);
    expect(provider.isRotatingQr, false);
  });

  test('slow QR issuance cannot send overlapping requests', () async {
    await provider.startSession();
    final ticket = provider.currentTicket!;
    final calls = service.qrCalls;
    service.delayedQr = Completer<QrTicketModel>();
    final first = provider.refreshQrTicketNow();
    final second = provider.refreshQrTicketNow();
    expect(service.qrCalls, calls + 1);
    service.delayedQr!.complete(ticket);
    await Future.wait([first, second]);
  });
}
