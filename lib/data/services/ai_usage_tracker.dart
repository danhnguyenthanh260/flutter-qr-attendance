import 'package:flutter/foundation.dart';

import '../../core/storage/ai_usage_storage.dart';
import '../models/ai_usage_record.dart';

/// Central service for tracking, recording, and summarizing AI usage metrics.
class AiUsageTracker extends ChangeNotifier {
  final AiUsageStorage _storage;
  final List<AiUsageRecord> _records = [];
  bool _isInitialized = false;

  AiUsageTracker({AiUsageStorage? storage})
    : _storage = storage ?? LocalFileAiUsageStorage();

  static AiUsageTracker? _instance;

  /// Global shared instance for application-wide tracking
  static AiUsageTracker get instance => _instance ??= AiUsageTracker();

  /// Visible for testing to inject custom mock storage
  @visibleForTesting
  static void setMockInstance(AiUsageTracker tracker) {
    _instance = tracker;
  }

  bool get isInitialized => _isInitialized;
  List<AiUsageRecord> get records => List.unmodifiable(_records);

  /// Load persisted history from storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    final loaded = await _storage.loadRecords();
    _records.clear();
    _records.addAll(loaded);
    _isInitialized = true;
    notifyListeners();
  }

  /// Record an AI invocation event with automatic cost calculation
  Future<AiUsageRecord> record({
    required String operation,
    required String model,
    required int promptTokens,
    required int candidatesTokens,
    required int latencyMs,
    required String keyMasked,
    bool isSuccess = true,
    String? errorMessage,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final totalTokens = promptTokens + candidatesTokens;
    final estimatedCost = AiUsageRecord.calculateCostUsd(
      model: model,
      promptTokens: promptTokens,
      candidatesTokens: candidatesTokens,
    );

    final record = AiUsageRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_records.length + 1}',
      timestamp: DateTime.now(),
      operation: operation,
      model: model,
      promptTokens: promptTokens,
      candidatesTokens: candidatesTokens,
      totalTokens: totalTokens,
      latencyMs: latencyMs,
      keyMasked: keyMasked,
      isSuccess: isSuccess,
      errorMessage: errorMessage,
      estimatedCostUsd: estimatedCost,
    );

    _records.add(record);
    notifyListeners();

    // Persist to storage
    await _storage.saveRecords(_records);

    return record;
  }

  /// Get aggregated summary of all usage metrics
  AiUsageSummary getSummary() {
    return AiUsageSummary.fromRecords(_records);
  }

  /// Clear all usage history
  Future<void> clearHistory() async {
    _records.clear();
    await _storage.clear();
    notifyListeners();
  }
}
