import 'dart:convert';
import 'dart:io';

import '../../data/models/session_model.dart';

abstract class SessionStorage {
  Future<void> saveActiveSession(AttendanceSession session);
  Future<AttendanceSession?> loadActiveSession();
  Future<void> clearActiveSession();
}

class LocalFileSessionStorage implements SessionStorage {
  final String fileName;

  LocalFileSessionStorage({this.fileName = 'session_cache.json'});

  File get _file => File(fileName);

  @override
  Future<void> saveActiveSession(AttendanceSession session) async {
    try {
      final jsonStr = jsonEncode(session.toJson());
      await _file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      // In desktop environment, file write failure shouldn't crash app
    }
  }

  @override
  Future<AttendanceSession?> loadActiveSession() async {
    try {
      if (!await _file.exists()) return null;
      final content = await _file.readAsString();
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      final session = AttendanceSession.fromJson(json);

      if (session.status == SessionStatus.closed) {
        await clearActiveSession();
        return null;
      }

      return session;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearActiveSession() async {
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } catch (e) {
      // Ignore deletion errors
    }
  }
}

class MemorySessionStorage implements SessionStorage {
  AttendanceSession? _session;

  @override
  Future<void> saveActiveSession(AttendanceSession session) async {
    _session = session;
  }

  @override
  Future<AttendanceSession?> loadActiveSession() async => _session;

  @override
  Future<void> clearActiveSession() async {
    _session = null;
  }
}
