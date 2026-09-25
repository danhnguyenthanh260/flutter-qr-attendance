import 'dart:async';

import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/models/qr_ticket_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/qr/qr_controller.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

QrTicketModel ticket(DateTime now) => QrTicketModel(
  ticketCode: 'test',
  formUrl: 'https://example.com',
  generation: 1,
  validSeconds: 30,
  createdAt: now,
  expiresAt: now.add(const Duration(seconds: 30)),
);

void main() {
  testWidgets(
    'closed controller ignores late ticket and prevents overlapping requests',
    (tester) async {
      final pending = Completer<QrTicketModel>();
      var calls = 0;
      final controller = QrController(
        issueTicket: (_) {
          calls++;
          return pending.future;
        },
        onSessionInactive: () async {},
      );
      final first = controller.start('session');
      final second = controller.refresh();
      expect(calls, 1);
      controller.stop();
      pending.complete(ticket(DateTime.now()));
      await Future.wait([first, second]);
      expect(controller.currentTicket, isNull);
      expect(controller.phase, QrPhase.stopped);
      controller.dispose();
    },
  );

  testWidgets(
    'failed prefetch retains valid QR only until the injected clock expires it',
    (tester) async {
      var now = DateTime(2026, 9, 25);
      var calls = 0;
      final controller = QrController(
        clock: () => now,
        issueTicket: (_) async {
          if (++calls > 1) throw TimeoutException('test');
          return ticket(now);
        },
        onSessionInactive: () async {},
      );
      await controller.start('session');
      now = now.add(const Duration(seconds: 23));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.phase, QrPhase.recovering);
      expect(controller.currentTicket, isNotNull);
      now = now.add(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 1));
      expect(controller.currentTicket, isNull);
      controller.dispose();
    },
  );

  testWidgets('QR ticks do not notify session selection listeners', (
    tester,
  ) async {
    final provider = SessionProvider(
      service: MockAttendanceService(simulateDelay: false),
      storage: MemorySessionStorage(),
    );
    await provider.loadInitialData();
    await provider.startSession();
    var notifications = 0;
    provider.addListener(() => notifications++);
    await tester.pump(const Duration(seconds: 3));
    expect(notifications, 0);
    provider.dispose();
  });
}
