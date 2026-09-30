import 'dart:convert';
import 'dart:io';

import '../../data/models/ai_usage_record.dart';

abstract class AiUsageStorage {
  Future<List<AiUsageRecord>> loadRecords();
  Future<void> saveRecords(List<AiUsageRecord> records);
  Future<void> clear();
}

/// Local file storage implementing persistence for AI usage history.
/// Default file name matches `*.cache.json` in .gitignore so it is never committed.
class LocalFileAiUsageStorage implements AiUsageStorage {
  final String fileName;

  LocalFileAiUsageStorage({this.fileName = 'ai_usage.cache.json'});

  File get _file => File(fileName);

  @override
  Future<List<AiUsageRecord>> loadRecords() async {
    try {
      if (!await _file.exists()) return [];
      final content = await _file.readAsString();
      if (content.trim().isEmpty) return [];

      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((item) => AiUsageRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveRecords(List<AiUsageRecord> records) async {
    try {
      final jsonList = records.map((r) => r.toJson()).toList();
      final content = jsonEncode(jsonList);
      await _file.writeAsString(content, flush: true);
    } catch (_) {
      // In desktop environment, file write failure shouldn't crash app
    }
  }

  @override
  Future<void> clear() async {
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } catch (_) {
      // Ignore deletion errors
    }
  }
}

/// In-memory storage for unit testing without filesystem dependencies.
class MemoryAiUsageStorage implements AiUsageStorage {
  List<AiUsageRecord> _items = [];

  @override
  Future<List<AiUsageRecord>> loadRecords() async => List.unmodifiable(_items);

  @override
  Future<void> saveRecords(List<AiUsageRecord> records) async {
    _items = List.from(records);
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}
