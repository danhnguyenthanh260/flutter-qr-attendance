import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_qr_attendance/data/models/qr_ticket_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/providers/session_provider.dart';

void main() {
  group('QrTicketModel Tests', () {
    test('Calculates remaining seconds and expiry correctly', () {
      final now = DateTime.now();
      final validTicket = QrTicketModel(
        ticketCode: 'TKT_TEST_1',
        formUrl: 'https://example.com/form',
        generation: 1,
        validSeconds: 30,
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 25)),
      );

      expect(validTicket.isExpired, isFalse);
      expect(validTicket.remainingSeconds, inInclusiveRange(24, 25));

      final expiredTicket = QrTicketModel(
        ticketCode: 'TKT_TEST_EXPIRED',
        formUrl: 'https://example.com/form',
        generation: 2,
        validSeconds: 30,
        createdAt: now.subtract(const Duration(seconds: 35)),
        expiresAt: now.subtract(const Duration(seconds: 5)),
      );

      expect(expiredTicket.isExpired, isTrue);
      expect(expiredTicket.remainingSeconds, equals(0));
    });
  });

  group('SessionProvider QR Rotation and Lifecycle Tests', () {
    late MockAttendanceService mockService;
    late SessionProvider provider;

    setUp(() {
      mockService = MockAttendanceService();
      provider = SessionProvider(service: mockService);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Starting session automatically starts QR rotation and sets countdown', () async {
      await provider.loadInitialData();

      expect(provider.classes.isNotEmpty, isTrue);
      expect(provider.selectedClass, isNotNull);
      expect(provider.selectedSlot, isNotNull);

      final started = await provider.startSession();
      expect(started, isTrue);
      expect(provider.hasActiveSession, isTrue);
      expect(provider.isRotatingQr, isTrue);
      expect(provider.currentTicket, isNotNull);
      expect(provider.currentTicket!.generation, equals(1));
      expect(provider.countdownSeconds, equals(30));
    });

    test('checkTicketOnResume immediately refreshes ticket if expired during sleep', () async {
      await provider.loadInitialData();
      await provider.startSession();

      final firstTicket = provider.currentTicket;
      expect(firstTicket, isNotNull);
      expect(firstTicket!.generation, equals(1));

      // Simulate machine going to sleep and ticket expiring
      await provider.checkTicketOnResume();

      // Since current ticket is still fresh, it should not force refresh if not expired
      expect(provider.currentTicket!.generation, equals(1));

      // Now manual refresh
      await provider.refreshQrTicketNow();
      expect(provider.currentTicket!.generation, equals(2));
      expect(provider.countdownSeconds, equals(30));
    });

    test('Toggling offline state marks provider as offline', () async {
      await provider.loadInitialData();
      await provider.startSession();

      expect(provider.isOffline, isFalse);

      provider.setOffline(true);
      expect(provider.isOffline, isTrue);

      provider.setOffline(false);
      expect(provider.isOffline, isFalse);
    });
  });
}
