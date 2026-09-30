/// Models for tracking AI token consumption, latency, and estimated cost.
class AiUsageRecord {
  final String id;
  final DateTime timestamp;
  final String operation; // e.g. 'chat', 'report'
  final String model;
  final int promptTokens;
  final int candidatesTokens;
  final int totalTokens;
  final int latencyMs;
  final String keyMasked;
  final bool isSuccess;
  final String? errorMessage;
  final double estimatedCostUsd;

  const AiUsageRecord({
    required this.id,
    required this.timestamp,
    required this.operation,
    required this.model,
    required this.promptTokens,
    required this.candidatesTokens,
    required this.totalTokens,
    required this.latencyMs,
    required this.keyMasked,
    this.isSuccess = true,
    this.errorMessage,
    required this.estimatedCostUsd,
  });

  /// Calculates estimated cost based on published Gemini 2.5 Flash pricing:
  /// - Prompt: $0.075 per 1M tokens ($0.000000075 / token)
  /// - Output (Candidates): $0.30 per 1M tokens ($0.00000030 / token)
  static double calculateCostUsd({
    required String model,
    required int promptTokens,
    required int candidatesTokens,
  }) {
    // Default to Gemini 2.5 Flash pricing tier
    const double promptRatePerMillion = 0.075;
    const double candidatesRatePerMillion = 0.30;

    final double promptCost = (promptTokens / 1000000.0) * promptRatePerMillion;
    final double candidatesCost =
        (candidatesTokens / 1000000.0) * candidatesRatePerMillion;

    return promptCost + candidatesCost;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'operation': operation,
    'model': model,
    'prompt_tokens': promptTokens,
    'candidates_tokens': candidatesTokens,
    'total_tokens': totalTokens,
    'latency_ms': latencyMs,
    'key_masked': keyMasked,
    'is_success': isSuccess,
    'error_message': errorMessage,
    'estimated_cost_usd': estimatedCostUsd,
  };

  factory AiUsageRecord.fromJson(Map<String, dynamic> json) {
    return AiUsageRecord(
      id: json['id'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      operation: json['operation'] as String? ?? 'unknown',
      model: json['model'] as String? ?? 'gemini-2.5-flash',
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      candidatesTokens: (json['candidates_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
      latencyMs: (json['latency_ms'] as num?)?.toInt() ?? 0,
      keyMasked: json['key_masked'] as String? ?? '...key',
      isSuccess: json['is_success'] as bool? ?? true,
      errorMessage: json['error_message'] as String?,
      estimatedCostUsd: (json['estimated_cost_usd'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Aggregated statistical summary for display in the AI Usage Dashboard.
class AiUsageSummary {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int totalPromptTokens;
  final int totalCandidatesTokens;
  final int totalTokens;
  final double totalCostUsd;
  final double averageLatencyMs;
  final List<AiUsageRecord> recentRecords;

  const AiUsageSummary({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.totalPromptTokens,
    required this.totalCandidatesTokens,
    required this.totalTokens,
    required this.totalCostUsd,
    required this.averageLatencyMs,
    required this.recentRecords,
  });

  factory AiUsageSummary.fromRecords(List<AiUsageRecord> records) {
    if (records.isEmpty) {
      return const AiUsageSummary(
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        totalPromptTokens: 0,
        totalCandidatesTokens: 0,
        totalTokens: 0,
        totalCostUsd: 0.0,
        averageLatencyMs: 0.0,
        recentRecords: [],
      );
    }

    int successful = 0;
    int failed = 0;
    int promptTokens = 0;
    int candidatesTokens = 0;
    int totalTokens = 0;
    double totalCost = 0.0;
    int totalLatency = 0;

    for (final r in records) {
      if (r.isSuccess) {
        successful++;
      } else {
        failed++;
      }
      promptTokens += r.promptTokens;
      candidatesTokens += r.candidatesTokens;
      totalTokens += r.totalTokens;
      totalCost += r.estimatedCostUsd;
      totalLatency += r.latencyMs;
    }

    // Sort recent records descending by timestamp
    final sorted = List<AiUsageRecord>.from(records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return AiUsageSummary(
      totalRequests: records.length,
      successfulRequests: successful,
      failedRequests: failed,
      totalPromptTokens: promptTokens,
      totalCandidatesTokens: candidatesTokens,
      totalTokens: totalTokens,
      totalCostUsd: totalCost,
      averageLatencyMs: totalLatency / records.length,
      recentRecords: sorted.take(20).toList(),
    );
  }

  double get successRatePercent =>
      totalRequests == 0 ? 100.0 : (successfulRequests / totalRequests) * 100.0;

  String get formattedCostUsd => '\$${totalCostUsd.toStringAsFixed(4)}';

  String get formattedCostVnd {
    // 1 USD ~ 25,400 VND reference rate
    final vnd = (totalCostUsd * 25400).round();
    return '$vnd ₫';
  }
}
