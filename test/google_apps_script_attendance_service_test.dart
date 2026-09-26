import 'dart:convert';

import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/google_apps_script_attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GoogleAppsScriptAttendanceService createService(http.Client client) {
  return GoogleAppsScriptAttendanceService(
    endpoint: Uri.parse('https://script.google.com/macros/s/example/exec'),
    teacherKey: 'teacher-key',
    teacherId: 'teacher-42',
    client: client,
    clock: () => DateTime.utc(2026, 9, 19, 8),
  );
}

void main() {
  for (final matching in [true, false]) {
    test(
      'lost start response reconciles matching lesson only: $matching',
      () async {
        var posts = 0;
        final service = createService(
          MockClient((request) async {
            if (request.method == 'POST') {
              posts++;
              return http.Response('<html>lost response</html>', 200);
            }
            expect(request.url.queryParameters['action'], 'active_session');
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'id': 'recovered',
                  'class_id': matching ? 'CLASS_1' : 'OTHER',
                  'class_name': 'Class',
                  'status': 'active',
                  'opened_at': '2026-09-19T08:00:00Z',
                  'slot': {
                    'date': '2026-09-19',
                    'slot_number': 2,
                    'time_range': '09:15 - 10:45',
                  },
                },
              }),
              200,
            );
          }),
        );
        final result = service.startSession(
          classId: 'CLASS_1',
          slot: const SessionSlot(
            slotNumber: 2,
            timeRange: '09:15 - 10:45',
            date: '2026-09-19',
          ),
        );
        if (matching) {
          expect((await result).id, 'recovered');
        } else {
          await expectLater(
            result,
            throwsA(
              isA<TeacherApiException>().having(
                (e) => e.code,
                'code',
                'operation_unconfirmed',
              ),
            ),
          );
        }
        expect(posts, 1);
      },
    );
  }
  test('lost QR response reads exact receipt without replaying POST', () async {
    var posts = 0;
    String? requestId;
    final service = createService(
      MockClient((request) async {
        if (request.method == 'POST') {
          posts++;
          requestId = (jsonDecode(request.body) as Map)['request_id'] as String;
          return http.Response('<html>lost response</html>', 200);
        }
        expect(request.url.queryParameters['action'], 'qr_receipt');
        expect(request.url.queryParameters['request_id'], requestId);
        final now = DateTime.now().toUtc();
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'ticket_code': 'receipt',
              'form_url': 'https://docs.google.com/forms/test',
              'generation': 1,
              'valid_seconds': 30,
              'created_at': now.toIso8601String(),
              'expires_at': now
                  .add(const Duration(seconds: 30))
                  .toIso8601String(),
              'server_time': now.toIso8601String(),
            },
          }),
          200,
        );
      }),
    );
    expect((await service.getNextQrTicket('SES_1')).ticketCode, 'receipt');
    expect(posts, 1);
  });
  test('maps classes and sends the configured teacher key on reads', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.queryParameters['action'], 'classes');
      expect(request.url.queryParameters['teacher_key'], 'teacher-key');
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {
              'id': 'CLASS_1',
              'name': 'Flutter',
              'course_code': 'PRM392',
              'room': 'BE-302',
              'total_students': 32,
              'schedule_description': 'Slot 2',
            },
          ],
        }),
        200,
      );
    });

    final classes = await createService(client).getClasses();

    expect(classes, hasLength(1));
    expect(classes.single.id, 'CLASS_1');
    expect(classes.single.totalStudents, 32);
  });

  test(
    'coalesces and caches class reads for the shared teacher service',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': [
              {
                'id': 'CLASS_1',
                'name': 'Flutter',
                'course_code': 'PRM392',
                'room': 'BE-302',
                'total_students': 32,
                'schedule_description': 'Slot 2',
              },
            ],
          }),
          200,
        );
      });
      final service = createService(client);

      final responses = await Future.wait([
        service.getClasses(),
        service.getClasses(),
      ]);
      expect(responses.first.single.id, 'CLASS_1');
      expect(responses.last.single.id, 'CLASS_1');
      expect(requests, 1);

      await service.getClasses();
      expect(requests, 1);
    },
  );

  test('posts a typed session request and maps a closing response', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      expect(body['action'], 'start_session');
      expect(body['teacher_key'], 'teacher-key');
      expect(body['teacher_id'], 'teacher-42');
      expect(body['class_id'], 'CLASS_1');
      expect(body['slot'], isA<Map<String, dynamic>>());
      expect(body['request_id'], startsWith('flutter_'));
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'id': 'SES_1',
            'class_id': 'CLASS_1',
            'class_name': 'PRM392 - Flutter',
            'slot': {
              'slot_number': 2,
              'time_range': '09:15 - 10:45',
              'date': '2026-09-19',
            },
            'opened_at': '2026-09-19T08:00:00.000Z',
            'closed_at': null,
            'status': 'closing',
          },
        }),
        200,
      );
    });
    final service = createService(client);

    final session = await service.startSession(
      classId: 'CLASS_1',
      slot: const SessionSlot(
        slotNumber: 2,
        timeRange: '09:15 - 10:45',
        date: '2026-09-19',
      ),
    );

    expect(session.id, 'SES_1');
    expect(session.status, SessionStatus.closing);
  });

  test(
    'follows the Apps Script ContentService redirect after a POST',
    () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.followRedirects, isFalse);
          expect(request.maxRedirects, 0);
          return http.Response(
            '',
            302,
            headers: const {
              'location': 'https://script.googleusercontent.com/macros/echo?ticket=short-lived',
            },
          );
        }

        expect(request.method, 'GET');
        expect(request.url.host, 'script.googleusercontent.com');
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'id': 'SES_REDIRECT',
              'class_id': 'CLASS_1',
              'class_name': 'PRM392 - Flutter',
              'slot': {
                'slot_number': 2,
                'time_range': '09:15 - 10:45',
                'date': '2026-09-19',
              },
              'opened_at': '2026-09-19T08:00:00.000Z',
              'closed_at': null,
              'status': 'active',
            },
          }),
          200,
        );
      });

      final session = await createService(client).startSession(
        classId: 'CLASS_1',
        slot: const SessionSlot(
          slotNumber: 2,
          timeRange: '09:15 - 10:45',
          date: '2026-09-19',
        ),
      );

      expect(session.id, 'SES_REDIRECT');
    },
  );

  test('follows the Apps Script ContentService redirect after a GET', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'script.google.com') {
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
        return http.Response(
          '',
          302,
          headers: const {
            'location': 'https://script.googleusercontent.com/macros/echo?ticket=short-lived',
          },
        );
      }

      expect(request.method, 'GET');
      expect(request.url.host, 'script.googleusercontent.com');
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {
              'id': 'CLASS_1',
              'name': 'Flutter',
              'course_code': 'PRM392',
              'room': 'BE-302',
              'total_students': 32,
              'schedule_description': 'Slot 2',
            },
          ],
        }),
        200,
      );
    });

    final classes = await createService(client).getClasses();

    expect(classes.single.id, 'CLASS_1');
  });

  test('retries a transient non-JSON Apps Script content response', () async {
    var contentRequests = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'script.google.com') {
        return http.Response(
          '',
          302,
          headers: const {
            'location': 'https://script.googleusercontent.com/macros/echo?ticket=short-lived',
          },
        );
      }

      contentRequests++;
      if (contentRequests == 1) {
        return http.Response('<html>Loading</html>', 200);
      }
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {
              'id': 'CLASS_1',
              'name': 'Flutter',
              'course_code': 'PRM392',
              'room': 'BE-302',
              'total_students': 32,
              'schedule_description': 'Slot 2',
            },
          ],
        }),
        200,
      );
    });

    final classes = await createService(client).getClasses();

    expect(classes.single.id, 'CLASS_1');
    expect(contentRequests, 2);
  });

  test('follows a second trusted ContentService redirect without a client loop', () async {
    var contentRequests = 0;
    final client = MockClient((request) async {
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      if (request.url.host == 'script.google.com') {
        return http.Response(
          '',
          302,
          headers: const {
            'location':
                'https://script.googleusercontent.com/macros/echo?ticket=first',
          },
        );
      }

      contentRequests++;
      if (contentRequests == 1) {
        return http.Response(
          '',
          302,
          headers: const {
            'location': 'https://script.googleusercontent.com/macros/echo?ticket=second',
          },
        );
      }
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {
              'id': 'CLASS_1',
              'name': 'Flutter',
              'course_code': 'PRM392',
              'room': 'BE-302',
              'total_students': 32,
              'schedule_description': 'Slot 2',
            },
          ],
        }),
        200,
      );
    });

    final classes = await createService(client).getClasses();

    expect(classes.single.id, 'CLASS_1');
    expect(contentRequests, 2);
  });

  test('surfaces API envelopes as typed errors', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'ok': false,
          'error': {
            'code': 'unauthorized',
            'message': 'Teacher authentication failed.',
          },
        }),
        200,
      );
    });

    expect(
      createService(client).getClasses(),
      throwsA(
        isA<TeacherApiException>()
            .having((error) => error.code, 'code', 'unauthorized')
            .having(
              (error) => error.message,
              'message',
              'Teacher authentication failed.',
            ),
      ),
    );
  });

  test('requests a server-issued QR claim URL', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      expect(body['action'], 'issue_qr');
      expect(body['session_id'], 'SES_1');
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'ticket_code': 'TKT_1',
            'form_url': 'https://script.google.com/macros/s/example/exec?route=claim&ticket_id=TKT_1',
            'generation': 3,
            'valid_seconds': 30,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(seconds: 30))
                .toIso8601String(),
          },
        }),
        200,
      );
    });

    final ticket = await createService(client).getNextQrTicket('SES_1');

    expect(ticket.ticketCode, 'TKT_1');
    expect(ticket.generation, 3);
    expect(ticket.formUrl, contains('route=claim'));
  });

  test('transient HTML on a read retries once and recovers JSON', () async {
    var calls = 0;
    final service = createService(
      MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response('<html>Temporary error</html>', 200)
            : http.Response('{"ok":true,"data":[]}', 200);
      }),
    );
    expect(await service.listSessions(), isEmpty);
    expect(calls, 2);
  });
  test(
    'persistent HTML exposes safe metadata instead of claiming lost wifi',
    () async {
      final service = createService(
        MockClient(
          (request) async => http.Response(
            '<html>Private content</html>',
            503,
            headers: {'content-type': 'text/html'},
          ),
        ),
      );
      await expectLater(
        service.listSessions(),
        throwsA(
          isA<TeacherApiException>()
              .having((e) => e.code, 'code', 'invalid_response')
              .having((e) => e.details?['http_status'], 'status', 503)
              .having(
                (e) => e.message.contains('Private content'),
                'private body excluded',
                false,
              ),
        ),
      );
    },
  );

  test(
    'return-to-exec read retries once at configured endpoint and recovers',
    () async {
      var executions = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'script.google.com') {
          executions++;
          if (executions == 2) {
            return http.Response('{"ok":true,"data":[]}', 200);
          }
          return http.Response(
            '',
            302,
            headers: {
              'location': 'https://script.googleusercontent.com/macros/echo?private=secret',
            },
          );
        }
        return http.Response(
          '',
          302,
          headers: {
            'location':
                'https://script.google.com/macros/s/example/exec?injected=bad',
          },
        );
      });
      expect(await createService(client).listSessions(), isEmpty);
      expect(executions, 2);
    },
  );
  test(
    'persistent return-to-exec stops after two reads with explicit error',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          '',
          302,
          headers: {
            'location': request.url.host == 'script.google.com'
                ? 'https://script.googleusercontent.com/macros/echo'
                : 'https://script.google.com/macros/s/example/exec',
          },
        );
      });
      await expectLater(
        createService(client).listSessions(),
        throwsA(
          isA<TeacherApiException>().having(
            (e) => e.code,
            'code',
            'redirect_to_execution',
          ),
        ),
      );
      expect(calls, 4);
    },
  );
  test(
    'POST return-to-exec is unconfirmed and never replays a write',
    () async {
      var posts = 0;
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.method == 'POST') posts++;
        return http.Response(
          '',
          302,
          headers: {
            'location': request.url.host == 'script.google.com'
                ? 'https://script.googleusercontent.com/macros/echo'
                : 'https://script.google.com/macros/s/example/exec',
          },
        );
      });
      await expectLater(
        createService(client).closeSession('session-test'),
        throwsA(
          isA<TeacherApiException>().having(
            (e) => e.code,
            'code',
            'operation_unconfirmed',
          ),
        ),
      );
      expect(posts, 1);
      expect(calls, 2);
    },
  );
  test('untrusted content redirect is not followed', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(
        '',
        302,
        headers: {
          'location': calls == 1
              ? 'https://script.googleusercontent.com/macros/echo'
              : 'https://untrusted.invalid/private',
        },
      );
    });
    await expectLater(
      createService(client).listSessions(),
      throwsA(
        isA<TeacherApiException>().having(
          (e) => e.code,
          'code',
          'redirect_untrusted',
        ),
      ),
    );
    expect(calls, 2);
  });

  test('missing one-time content is retried as read, not reused', () async {
    var executions = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'script.google.com') {
        executions++;
        if (executions == 2) {
          return http.Response('{"ok":true,"data":[]}', 200);
        }
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://script.googleusercontent.com/macros/echo',
          },
        );
      }
      return http.Response('<html>not found</html>', 404);
    });
    expect(await createService(client).listSessions(), isEmpty);
    expect(executions, 2);
  });
}
