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

  test('does not invent QR ticket support owned by issue #7', () async {
    final client = MockClient((request) async => http.Response('', 500));

    expect(
      createService(client).getNextQrTicket('SES_1'),
      throwsA(
        isA<TeacherApiException>()
            .having((error) => error.code, 'code', 'feature_not_ready'),
      ),
    );
  });
}
