import 'package:flutter_qr_attendance/core/storage/ai_usage_storage.dart';
import 'package:flutter_qr_attendance/data/models/ai_usage_record.dart';
import 'package:flutter_qr_attendance/data/services/ai_usage_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiUsageRecord & Cost Calculation Tests', () {
    test(
      'calculateCostUsd accurately computes Gemini 2.5 Flash token rates',
      () {
        // 1,000,000 prompt tokens = $0.075
        // 1,000,000 candidate tokens = $0.30
        final cost = AiUsageRecord.calculateCostUsd(
          model: 'gemini-2.5-flash',
          promptTokens: 1000000,
          candidatesTokens: 1000000,
        );

        expect(cost, closeTo(0.375, 0.000001));

        // Realistic query: 500 prompt tokens, 200 candidate tokens
        final smallCost = AiUsageRecord.calculateCostUsd(
          model: 'gemini-2.5-flash',
          promptTokens: 500,
          candidatesTokens: 200,
        );

        // (500 * 0.075 / 1e6) + (200 * 0.30 / 1e6) = 0.0000375 + 0.00006 = 0.0000975
        expect(smallCost, closeTo(0.0000975, 0.0000001));
      },
    );

    test('AiUsageRecord serialization roundtrip', () {
      final record = AiUsageRecord(
        id: 'rec_1',
        timestamp: DateTime(2026, 9, 30, 10, 0),
        operation: 'chat',
        model: 'gemini-2.5-flash',
        promptTokens: 400,
        candidatesTokens: 150,
        totalTokens: 550,
        latencyMs: 1200,
        keyMasked: '...4x8a',
        isSuccess: true,
        estimatedCostUsd: 0.0001,
      );

      final json = record.toJson();
      final fromJson = AiUsageRecord.fromJson(json);

      expect(fromJson.id, equals('rec_1'));
      expect(fromJson.operation, equals('chat'));
      expect(fromJson.promptTokens, equals(400));
      expect(fromJson.candidatesTokens, equals(150));
      expect(fromJson.totalTokens, equals(550));
      expect(fromJson.latencyMs, equals(1200));
      expect(fromJson.keyMasked, equals('...4x8a'));
      expect(fromJson.isSuccess, isTrue);
      expect(fromJson.estimatedCostUsd, closeTo(0.0001, 0.00001));
    });
  });

  group('AiUsageSummary Tests', () {
    test('Empty records produce zeroed summary with 100% success rate', () {
      final summary = AiUsageSummary.fromRecords([]);

      expect(summary.totalRequests, equals(0));
      expect(summary.successfulRequests, equals(0));
      expect(summary.failedRequests, equals(0));
      expect(summary.totalTokens, equals(0));
      expect(summary.totalCostUsd, equals(0.0));
      expect(summary.successRatePercent, equals(100.0));
      expect(summary.formattedCostUsd, equals('\$0.0000'));
      expect(summary.formattedCostVnd, equals('0 ₫'));
    });

    test('Aggregates metrics correctly across multiple requests', () {
      final records = [
        AiUsageRecord(
          id: '1',
          timestamp: DateTime(2026, 9, 30, 10, 0),
          operation: 'chat',
          model: 'gemini-2.5-flash',
          promptTokens: 1000,
          candidatesTokens: 500,
          totalTokens: 1500,
          latencyMs: 1000,
          keyMasked: '...key1',
          isSuccess: true,
          estimatedCostUsd: 0.000225,
        ),
        AiUsageRecord(
          id: '2',
          timestamp: DateTime(2026, 9, 30, 10, 5),
          operation: 'report',
          model: 'gemini-2.5-flash',
          promptTokens: 2000,
          candidatesTokens: 1000,
          totalTokens: 3000,
          latencyMs: 2000,
          keyMasked: '...key2',
          isSuccess: true,
          estimatedCostUsd: 0.00045,
        ),
        AiUsageRecord(
          id: '3',
          timestamp: DateTime(2026, 9, 30, 10, 10),
          operation: 'chat',
          model: 'gemini-2.5-flash',
          promptTokens: 0,
          candidatesTokens: 0,
          totalTokens: 0,
          latencyMs: 600,
          keyMasked: '...key1',
          isSuccess: false,
          errorMessage: '503 Service Unavailable',
          estimatedCostUsd: 0.0,
        ),
      ];

      final summary = AiUsageSummary.fromRecords(records);

      expect(summary.totalRequests, equals(3));
      expect(summary.successfulRequests, equals(2));
      expect(summary.failedRequests, equals(1));
      expect(summary.totalPromptTokens, equals(3000));
      expect(summary.totalCandidatesTokens, equals(1500));
      expect(summary.totalTokens, equals(4500));
      expect(summary.totalCostUsd, closeTo(0.000675, 0.000001));
      expect(summary.averageLatencyMs, closeTo(1200.0, 0.01));
      expect(summary.successRatePercent, closeTo(66.67, 0.01));
      expect(summary.recentRecords.first.id, equals('3')); // Most recent first
    });
  });

  group('AiUsageTracker Service Tests', () {
    late MemoryAiUsageStorage storage;
    late AiUsageTracker tracker;

    setUp(() {
      storage = MemoryAiUsageStorage();
      tracker = AiUsageTracker(storage: storage);
    });

    test('Records usage event and persists to storage', () async {
      await tracker.initialize();
      expect(tracker.records.isEmpty, isTrue);

      final rec = await tracker.record(
        operation: 'chat',
        model: 'gemini-2.5-flash',
        promptTokens: 300,
        candidatesTokens: 120,
        latencyMs: 950,
        keyMasked: '...7x9c',
      );

      expect(rec.totalTokens, equals(420));
      expect(rec.isSuccess, isTrue);
      expect(tracker.records.length, equals(1));

      // Verify persistence in storage
      final stored = await storage.loadRecords();
      expect(stored.length, equals(1));
      expect(stored.first.id, equals(rec.id));

      final summary = tracker.getSummary();
      expect(summary.totalRequests, equals(1));
      expect(summary.totalTokens, equals(420));
    });

    test('clearHistory wipes memory and storage', () async {
      await tracker.initialize();
      await tracker.record(
        operation: 'report',
        model: 'gemini-2.5-flash',
        promptTokens: 500,
        candidatesTokens: 200,
        latencyMs: 1500,
        keyMasked: '...abc1',
      );

      expect(tracker.records.length, equals(1));

      await tracker.clearHistory();

      expect(tracker.records.isEmpty, isTrue);
      final stored = await storage.loadRecords();
      expect(stored.isEmpty, isTrue);
      expect(tracker.getSummary().totalRequests, equals(0));
    });

    test('budget cap management and warnings work accurately', () async {
      await tracker.initialize();
      expect(tracker.budgetCapUsd, equals(1.0));

      await tracker.setBudgetCap(0.0001);
      expect(tracker.budgetCapUsd, equals(0.0001));

      // Ban đầu chưa có chi phí
      expect(tracker.isBudgetExceeded, isFalse);
      expect(tracker.isBudgetWarning, isFalse);
      expect(tracker.budgetUsageRatio, equals(0.0));

      // Ghi nhận lượt gọi tạo ra chi phí ~ $0.0000975 (vượt 80% của 0.0001)
      await tracker.record(
        operation: 'chat',
        model: 'gemini-2.5-flash',
        promptTokens: 500,
        candidatesTokens: 200,
        latencyMs: 1200,
        keyMasked: '...4x8a',
      );

      expect(tracker.isBudgetWarning, isTrue);
      expect(tracker.isBudgetExceeded, isFalse);
      expect(tracker.budgetUsageRatio, greaterThanOrEqualTo(0.8));

      // Ghi nhận thêm lượt gọi để vượt 100% hạn mức
      await tracker.record(
        operation: 'chat',
        model: 'gemini-2.5-flash',
        promptTokens: 500,
        candidatesTokens: 200,
        latencyMs: 1200,
        keyMasked: '...4x8a',
      );

      expect(tracker.isBudgetExceeded, isTrue);
      expect(tracker.budgetUsageRatio, equals(1.0));
    });
  });
}
