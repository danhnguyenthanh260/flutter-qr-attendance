import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/google_apps_script_attendance_service.dart';

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

  test('follows the Apps Script ContentService redirect after a POST', () async {
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
  });

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
            .having((error) => error.message, 'message', 'Teacher authentication failed.'),
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
            'created_at': '2026-09-19T08:00:00.000Z',
            'expires_at': '2026-09-19T08:00:30.000Z',
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
}
