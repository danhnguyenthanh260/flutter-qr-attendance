import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/models/qr_ticket_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_api_exception.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/data/services/google_apps_script_attendance_service.dart';
import 'package:flutter_qr_attendance/providers/session_provider.dart';

class RecoveringService extends MockAttendanceService {
  RecoveringService() : super(simulateDelay: false);
  int calls = 0;
  @override
  Future<QrTicketModel> getNextQrTicket(String sessionId) async {
    calls++;
    if (calls == 1) {
      throw const AttendanceApiException(
        code: 'operation_unconfirmed',
        message: 'Timeout',
      );
    }
    return super.getNextQrTicket(sessionId);
  }
}

void main() {
  test('server expiry remains bounded despite a skewed desktop clock', () {
    final server = DateTime.now().add(const Duration(minutes: 5));
    final ticket = QrTicketModel.fromJson({
      'ticket_code': 'skew',
      'form_url': 'https://example.com',
      'generation': 1,
      'created_at': server.toIso8601String(),
      'expires_at': server.add(const Duration(seconds: 30)).toIso8601String(),
      'server_time': server.toIso8601String(),
    }, transit: const Duration(seconds: 7));
    expect(ticket.remainingSeconds, inInclusiveRange(22, 23));
  });
  testWidgets(
    'QR automatically recovers after timeout instead of staying offline',
    (tester) async {
      final service = RecoveringService();
      final provider = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      await provider.loadInitialData();
      await provider.startSession();
      expect(provider.isOffline, true);
      expect(provider.currentTicket, isNull);
      await tester.pump(const Duration(seconds: 6));
      expect(service.calls, 2);
      expect(provider.isOffline, false);
      expect(provider.currentTicket, isNotNull);
      provider.dispose();
    },
  );

  test('QR timeout retries use same request ID and successful next cycle uses new ID', () async {
    final ids = <String>[];
    final pending = Completer<http.Response>();
    final service = GoogleAppsScriptAttendanceService(
      endpoint: Uri.parse('https://example.com/exec'),
      teacherKey: 'test',
      teacherId: 'test',
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((request) async {
        ids.add(jsonDecode(request.body)['request_id'] as String);
        if (ids.length == 1) return pending.future;
        final now = DateTime.now();
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'ticket_code': 'ticket',
              'form_url': 'https://example.com/claim',
              'generation': 1,
              'created_at': now.toIso8601String(),
              'expires_at': now
                  .add(const Duration(seconds: 30))
                  .toIso8601String(),
            },
          }),
          200,
        );
      }),
    );
    await expectLater(
      service.getNextQrTicket('s'),
      throwsA(isA<AttendanceApiException>()),
    );
    await service.getNextQrTicket('s');
    await service.getNextQrTicket('s');
    expect(ids[0], ids[1]);
    expect(ids[1], isNot(ids[2]));
    pending.complete(
      http.Response('{"ok":false,"error":{"code":"not_found"}}', 200),
    );
  });
}
