import 'dart:convert';
import 'dart:io';

/// Bounded release HTTP diagnostics and opt-in timings. No credentials or PII.
class PerformanceLog {
  static const enabled = bool.fromEnvironment('ATTENDANCE_DIAGNOSTICS');
  static final Stopwatch _clock = Stopwatch()..start();
  static Future<void> _pending = Future.value();

  static String get path =>
      '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}${Platform.pathSeparator}FlutterQrAttendance${Platform.pathSeparator}performance.log';

  static void mark(String event, [Map<String, Object?> details = const {}]) {
    if (!enabled && !{'api_failed', 'api_http', 'api_retry'}.contains(event)) {
      return;
    }
    final line = jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'pid': pid,
      'build': const String.fromEnvironment(
        'APP_BUILD',
        defaultValue: 'development',
      ),
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
        final file = File(
          '${directory.path}${Platform.pathSeparator}performance.log',
        );
        if (await file.exists() && await file.length() > 1024 * 1024) {
          final previous = File('${file.path}.1');
          if (await previous.exists()) await previous.delete();
          await file.rename(previous.path);
        }
        await file.writeAsString('$line\n', mode: FileMode.append);
      } catch (_) {
        // Diagnostics must not block the app or expose request content.
      }
    });
  }
}
