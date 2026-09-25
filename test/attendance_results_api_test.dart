import 'dart:convert';

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
    clock: () => DateTime.utc(2026, 9, 22, 8),
  );
}

void main() {
  test('listSessions gửi đúng action và bộ lọc lớp/ngày', () async {
    late Uri requested;

    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': [
            {
              'id': 'SES_1',
              'class_id': 'CLASS_1',
              'class_name': 'PRM392 - Flutter',
              'slot': {
                'slot_number': 2,
                'time_range': '09:15 - 10:45',
                'date': '2026-09-22',
              },
              'opened_at': '2026-09-22T09:17:00.000',
              'closed_at': null,
              'status': 'active',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final sessions = await createService(client)
        .listSessions(classId: 'CLASS_1', date: '2026-09-22');

    expect(requested.queryParameters['action'], 'sessions');
    expect(requested.queryParameters['class_id'], 'CLASS_1');
    expect(requested.queryParameters['date'], '2026-09-22');
    expect(requested.queryParameters['teacher_key'], 'teacher-key');
    expect(sessions.single.id, 'SES_1');
    expect(sessions.single.slot.slotNumber, 2);
  });

  test('getSessionResults đọc đủ roster, attendance và attempts', () async {
    late Uri requested;

    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'session': {
              'id': 'SES_1',
              'class_id': 'CLASS_1',
              'class_name': 'PRM392 - Flutter',
              'slot': {
                'slot_number': 2,
                'time_range': '09:15 - 10:45',
                'date': '2026-09-22',
              },
              'opened_at': '2026-09-22T09:17:00.000',
              'closed_at': '2026-09-22T10:05:00.000',
              'status': 'closed',
            },
            'roster': [
              {
                'id': 'ROS_1',
                'class_id': 'CLASS_1',
                'email': 'An@FPT.edu.vn',
                'email_key': 'an@fpt.edu.vn',
                'student_name': 'Nguyễn Văn An',
              },
              {
                'id': 'ROS_2',
                'class_id': 'CLASS_1',
                'email': 'binh@fpt.edu.vn',
                'email_key': 'binh@fpt.edu.vn',
                'student_name': '',
              },
            ],
            'attendance': [
              {
                'id': 'ATT_1',
                'session_id': 'SES_1',
                'form_response_id': 'FR_1',
                'email': 'an@fpt.edu.vn',
                'email_key': 'an@fpt.edu.vn',
                'student_name': 'Nguyễn Văn An',
                'accepted_at': '2026-09-22T09:19:00.000',
              },
            ],
            'attempts': [
              {
                'id': 'ATM_1',
                'session_id': 'SES_1',
                'form_response_id': 'FR_2',
                'email': 'an@fpt.edu.vn',
                'email_key': 'an@fpt.edu.vn',
                'attempt_type': 'duplicate_email',
                'reason': 'duplicate_email',
                'occurred_at': '2026-09-22T09:25:00.000',
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final results = await createService(client).getSessionResults('SES_1');

    expect(requested.queryParameters['action'], 'session_results');
    expect(requested.queryParameters['session_id'], 'SES_1');
    expect(results.session.id, 'SES_1');
    expect(results.roster.length, 2);
    expect(results.roster.first.emailKey, 'an@fpt.edu.vn');
    expect(results.roster.last.studentName, isNull);
    expect(results.roster.last.displayName, 'binh');
    expect(
      results.attendance.single.acceptedAt,
      DateTime.parse('2026-09-22T09:19:00.000'),
    );
    expect(results.attempts.single.isRetryOfAcceptedSubmission, isTrue);
    expect(results.fetchedAt, DateTime.utc(2026, 9, 22, 8));
  });

  test('lỗi roster_missing giữ nguyên mã lỗi cho tầng hiển thị', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'ok': false,
          'error': {
            'code': 'roster_missing',
            'message': 'No active roster exists for this class.',
            'details': {'class_id': 'CLASS_1'},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      createService(client).getSessionResults('SES_1'),
      throwsA(
        isA<TeacherApiException>()
            .having((error) => error.code, 'code', 'roster_missing')
            .having(
              (error) => error.isRosterMissing,
              'isRosterMissing',
              isTrue,
            ),
      ),
    );
  });

  test('phản hồi thiếu session bị từ chối thay vì dựng bảng rỗng', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'ok': true,
          'data': {
            'roster': <Object?>[],
            'attendance': <Object?>[],
            'attempts': <Object?>[],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await expectLater(
      createService(client).getSessionResults('SES_1'),
      throwsA(isA<FormatException>()),
    );
  });
}
