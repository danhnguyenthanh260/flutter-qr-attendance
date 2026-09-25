import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_qr_attendance/core/storage/catalog_storage.dart';
import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/models/class_model.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/google_apps_script_attendance_service.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/attendance_fixtures.dart';

class SlowRecoveryService extends FakeAttendanceService {
  final recovery = Completer<AttendanceSession?>();
  final slotRequests = <String, Completer<List<SessionSlot>>>{};
  int classCalls = 0;
  int recoveryCalls = 0;
  @override
  Future<List<ClassModel>> getClasses() async {
    classCalls++;
    return classes;
  }

  @override
  Future<AttendanceSession?> getActiveSession() {
    recoveryCalls++;
    return recovery.future;
  }

  @override
  Future<List<SessionSlot>> getSlotsForClass(String classId) =>
      (slotRequests[classId] ??= Completer<List<SessionSlot>>()).future;
}

void main() {
  test('coalesces identical reads and disables stale pooled Apps Script connections', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final service = GoogleAppsScriptAttendanceService(
      endpoint: Uri.parse('https://script.google.com/macros/s/test/exec'),
      teacherKey: 'test',
      teacherId: 'test',
      client: MockClient((request) {
        calls++;
        expect(request.persistentConnection, isFalse);
        return pending.future;
      }),
    );
    final first = service.listSessions(classId: 'A');
    final second = service.listSessions(classId: 'A');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(http.Response('{"ok":true,"data":[]}', 200));
    expect(await first, isEmpty);
    expect(await second, isEmpty);
  });
  test('catalog renders before slow recovery; startup coalesces and start stays guarded', () async {
    final service = SlowRecoveryService();
    final provider = SessionProvider(
      service: service,
      storage: MemorySessionStorage(),
    );
    addTearDown(provider.dispose);
    final first = provider.loadInitialData();
    final second = provider.loadInitialData();
    await Future<void>.delayed(Duration.zero);
    expect(service.classCalls, 1);
    expect(service.recoveryCalls, 1);
    expect(provider.classes, isNotEmpty);
    expect(provider.isLoading, isFalse);
    expect(provider.isRestoringSession, isTrue);
    expect(await provider.startSession(), isFalse);
    service.slotRequests[kClassId]!.complete([buildSession().slot]);
    service.recovery.complete(null);
    await Future.wait([first, second]);
    expect(provider.canStartSession, isTrue);
  });

  test(
    'late slots from an old class cannot overwrite the current selection',
    () async {
      final service = SlowRecoveryService();
      final provider = SessionProvider(
        service: service,
        storage: MemorySessionStorage(),
      );
      addTearDown(provider.dispose);
      final a = provider.selectClass(buildClass(id: 'A'));
      final b = provider.selectClass(buildClass(id: 'B'));
      final slotB = buildSession(slotNumber: 3).slot;
      service.slotRequests['B']!.complete([slotB]);
      await b;
      service.slotRequests['A']!.complete([buildSession(slotNumber: 1).slot]);
      await a;
      expect(provider.selectedClass!.id, 'B');
      expect(provider.selectedSlot, slotB);
    },
  );

  test(
    'disk catalog is scoped and expires; fresh restart avoids network',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-cache-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = CatalogStorage(directory: directory, scope: 'account-a');
      await storage.write('classes', [buildClass().toJson()], kBaseTime);
      var calls = 0;
      var now = kBaseTime.add(const Duration(minutes: 4));
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'ok': true,
            'data': [buildClass().toJson()],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = GoogleAppsScriptAttendanceService(
        endpoint: Uri.parse('https://example.com/exec'),
        teacherKey: 'test',
        teacherId: 'test',
        client: client,
        clock: () => now,
        catalogStorage: storage,
      );
      expect(await service.getClasses(), hasLength(1));
      expect(calls, 0);
      now = kBaseTime.add(const Duration(minutes: 6));
      await service.getClasses();
      expect(calls, 1);
      expect(
        await CatalogStorage(
          directory: directory,
          scope: 'account-b',
        ).read('classes', kBaseTime),
        isNull,
      );
    },
  );

  test(
    'mutation deadline reports unknown outcome without replaying POST',
    () async {
      final pending = Completer<http.Response>();
      var requests = 0;
      final service = GoogleAppsScriptAttendanceService(
        endpoint: Uri.parse('https://example.com/exec'),
        teacherKey: 'test',
        teacherId: 'test',
        requestTimeout: const Duration(milliseconds: 5),
        client: MockClient((_) {
          requests++;
          return pending.future;
        }),
      );
      await expectLater(
        service.getNextQrTicket('session'),
        throwsA(
          isA<TeacherApiException>().having(
            (e) => e.code,
            'code',
            'operation_unconfirmed',
          ),
        ),
      );
      expect(requests, 1);
      pending.complete(
        http.Response('{"ok":false,"error":{"code":"not_found"}}', 200),
      );
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
    },
  );
}
