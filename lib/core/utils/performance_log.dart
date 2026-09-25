import 'dart:convert';
import 'dart:io';

/// Local opt-in timings; no URLs, keys, student data, or session identifiers.
class PerformanceLog {
  static const enabled = bool.fromEnvironment('ATTENDANCE_DIAGNOSTICS');
  static final Stopwatch _clock = Stopwatch()..start();
  static Future<void> _pending = Future.value();

  static void mark(String event, [Map<String, Object?> details = const {}]) {
    if (!enabled) return;
    final line = jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'pid': pid,
      'elapsed_ms': _clock.elapsedMilliseconds,
      'event': event,
      ...details,
    });
    _pending = _pending.then((_) async {
      try {
        final directory = Directory(
          '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}${Platform.pathSeparator}FlutterQrAttendance',
        );
        await directory.create(recursive: true);
        await File('${directory.path}${Platform.pathSeparator}performance.log')
            .writeAsString('$line\n', mode: FileMode.append);
      } catch (_) {
        // Diagnostics must not block the app or expose request content.
      }
    });
  }
}
