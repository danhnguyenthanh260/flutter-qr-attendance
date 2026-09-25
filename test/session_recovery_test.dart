import 'package:flutter_qr_attendance/core/storage/session_storage.dart';
import 'package:flutter_qr_attendance/data/models/session_model.dart';
import 'package:flutter_qr_attendance/data/services/attendance_service.dart';
import 'package:flutter_qr_attendance/features/teaching/session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemorySessionStorage Tests', () {
    test('Save, load and clear session correctly', () async {
      final storage = MemorySessionStorage();
      expect(await storage.loadActiveSession(), isNull);

      final now = DateTime.now();
      final session = AttendanceSession(
        id: 'SES_TEST_101',
        classId: 'CLASS_TEST',
        className: 'Test Class',
        slot: SessionSlot(
          slotNumber: 1,
          timeRange: '07:30 - 09:00',
          date: '2026-09-18',
        ),
        openedAt: now,
        status: SessionStatus.active,
      );

      await storage.saveActiveSession(session);
      final loaded = await storage.loadActiveSession();
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('SES_TEST_101'));

      await storage.clearActiveSession();
      expect(await storage.loadActiveSession(), isNull);
    });
  });

  group('Session Restoration and Safe Close Tests (Issue #21)', () {
    late MockAttendanceService mockService;
    late MemorySessionStorage memoryStorage;
    late SessionProvider provider;

    setUp(() {
      mockService = MockAttendanceService(simulateDelay: false);
      memoryStorage = MemorySessionStorage();
      provider = SessionProvider(service: mockService, storage: memoryStorage);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Starting session persists session into storage', () async {
      await provider.loadInitialData();
      final started = await provider.startSession();

      expect(started, isTrue);
      expect(provider.hasActiveSession, isTrue);

      final saved = await memoryStorage.loadActiveSession();
      expect(saved, isNotNull);
      expect(saved!.id, equals(provider.activeSession!.id));
    });

    test('Restarting app restores session from server and storage', () async {
      // Step 1: Open a session
      await provider.loadInitialData();
      await provider.startSession();
      final openedId = provider.activeSession!.id;

      // Step 2: Simulate app restart by creating a new provider with same service and storage
      final newProvider = SessionProvider(
        service: mockService,
        storage: memoryStorage,
      );
      addTearDown(() => newProvider.dispose());

      await newProvider.loadInitialData();
      expect(newProvider.hasActiveSession, isTrue);
      expect(newProvider.activeSession!.id, equals(openedId));
      expect(newProvider.isRotatingQr, isTrue);
    });

    test('Closing session safely cleans up storage and active state', () async {
      await provider.loadInitialData();
      await provider.startSession();
      expect(provider.hasActiveSession, isTrue);

      final closed = await provider.closeSession();
      expect(closed, isTrue);
      expect(provider.hasActiveSession, isFalse);
      expect(provider.isRotatingQr, isFalse);
      expect(await memoryStorage.loadActiveSession(), isNull);
    });

    test('Does not reopen already closed session after restart', () async {
      await provider.loadInitialData();
      await provider.startSession();
      await provider.closeSession();

      // Simulate app restart
      final newProvider = SessionProvider(
        service: mockService,
        storage: memoryStorage,
      );
      addTearDown(() => newProvider.dispose());

      await newProvider.loadInitialData();
      expect(newProvider.hasActiveSession, isFalse);
      expect(newProvider.activeSession, isNull);
    });
  });
}
