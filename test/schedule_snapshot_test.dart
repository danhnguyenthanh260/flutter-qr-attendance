import 'dart:convert';
import 'dart:io';

import 'package:flutter_qr_attendance/core/storage/catalog_storage.dart';
import 'package:flutter_qr_attendance/data/services/google_apps_script_attendance_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('restart snapshot stores schedule only and expires independently from live catalog', () async {
    final dir = await Directory.systemTemp.createTemp('schedule-test');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.utc(2026, 9, 26);
    final storage = CatalogStorage(directory: dir, scope: 'test-account');
    await storage.write('classes', [
      {
        'id': 'c1',
        'name': 'Test class',
        'course_code': 'T',
        'room': 'A',
        'total_students': 1,
        'schedule_description': '',
      },
    ], now);
    final service = GoogleAppsScriptAttendanceService(
      endpoint: Uri.parse('https://script.google.com/macros/s/test/exec'),
      teacherKey: 'test-key',
      teacherId: 'test-teacher',
      catalogStorage: storage,
      clock: () => now,
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'ok': true,
            'data': {
              'c1': {
                'slots': [
                  {
                    'slot_number': 1,
                    'time_range': '07:00 - 08:00',
                    'date': '2026-09-26',
                  },
                ],
                'roster': <dynamic>[],
                'sessions': <dynamic>[],
                'attendance': <dynamic>[],
              },
            },
          }),
          200,
        ),
      ),
    );
    await service.getWeeklyOverview();
    final cached = await service.readScheduleSnapshot();
    expect(cached!.data['c1']!.slots.single.date, '2026-09-26');
    expect(cached.data['c1']!.sessions, isEmpty);
    final stored = await storage.read(
      'weekly_slots',
      now.add(const Duration(hours: 1)),
      maxAge: const Duration(days: 7),
    );
    expect(stored!.items.single.keys, unorderedEquals(['class_id', 'slots']));
    expect(
      await storage.read(
        'weekly_slots',
        now.add(const Duration(days: 8)),
        maxAge: const Duration(days: 7),
      ),
      isNull,
    );
    final isolated = CatalogStorage(directory: dir, scope: 'other-account');
    expect(await isolated.read('weekly_slots', now), isNull);
  });
}
