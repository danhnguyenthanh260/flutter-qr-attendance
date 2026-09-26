import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Only class/slot catalog data, never session state or attendance results.
class CatalogStorage {
  final Directory directory;
  final String scope;

  CatalogStorage({required this.directory, required this.scope});

  factory CatalogStorage.local(String scope) => CatalogStorage(
    directory: Directory(
      '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}${Platform.pathSeparator}FlutterQrAttendance${Platform.pathSeparator}catalog',
    ),
    scope: scope,
  );

  File _file(String key) => File(
    '${directory.path}${Platform.pathSeparator}${sha256.convert(utf8.encode('$scope|$key'))}.json',
  );

  Future<({DateTime saved, List<dynamic> items})?> read(
    String key,
    DateTime now, {
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    try {
      final data = jsonDecode(await _file(key).readAsString()) as Map;
      final saved = DateTime.parse(data['saved_at'] as String);
      final age = now.difference(saved);
      if (age.isNegative || age > maxAge) return null;
      return (saved: saved, items: data['items'] as List<dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, List<dynamic> items, DateTime now) async {
    try {
      await directory.create(recursive: true);
      await _file(key).writeAsString(
        jsonEncode({'saved_at': now.toIso8601String(), 'items': items}),
        flush: true,
      );
    } catch (_) {
      // A cache failure must not invalidate a successful API response.
    }
  }
}
