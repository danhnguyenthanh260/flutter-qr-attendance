import 'dart:convert';

import 'package:flutter_qr_attendance/data/services/google_apps_script_attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final persisted in [true, false]) {
    test(
      'uncertain roster write reconciles without POST replay: $persisted',
      () async {
        var writes = 0;
        final change = {
          'id': 'r',
          'roll_number': 'SE000001',
          'email': 'new@example.edu',
          'student_name': 'Student',
          'member_code': 'M',
          'is_active': true,
        };
        final service = GoogleAppsScriptAttendanceService(
          endpoint: Uri.parse('https://script.google.com/macros/s/test/exec'),
          teacherKey: 'test',
          teacherId: 'teacher',
          client: MockClient((request) async {
            if (request.method == 'POST') {
              writes++;
              return http.Response('<html>lost response</html>', 200);
            }
            expect(request.url.queryParameters['action'], 'class_roster');
            return http.Response(
              jsonEncode({
                'ok': true,
                'data': {
                  'students': [
                    {
                      ...change,
                      'email': persisted
                          ? 'new@example.edu'
                          : 'old@example.edu',
                    },
                  ],
                  'revision': 'rev',
                  'legacy_sessions': 0,
                },
              }),
              200,
            );
          }),
        );
        final result = service.updateRoster({
          'class_id': 'c',
          'revision': 'before',
          'students': [change],
        });
        if (persisted) {
          expect((await result).students.single.email, 'new@example.edu');
        } else {
          await expectLater(result, throwsA(isA<TeacherApiException>()));
        }
        expect(writes, 1);
      },
    );
  }
}
