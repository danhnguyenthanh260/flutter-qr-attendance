import 'dart:convert';
import 'dart:io';

/// Bounded release HTTP diagnostics and opt-in timings. No credentials or PII.
class PerformanceLog {
  static const enabled = bool.fromEnvironment('ATTENDANCE_DIAGNOSTICS');
  static final Stopwatch _clock = Stopwatch()..start();
  static String? lastWriteError;

  static String get path =>
      '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}${Platform.pathSeparator}FlutterQrAttendance${Platform.pathSeparator}diagnostics-$pid.jsonl';

  static void mark(String event, [Map<String, Object?> details = const {}]) {
    if (!enabled &&
        !{'startup', 'api_failed', 'api_http', 'api_retry'}.contains(event)) {
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
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      if (file.existsSync() && file.lengthSync() > 1024 * 1024) {
        final previous = File('${file.path}.1');
        if (previous.existsSync()) previous.deleteSync();
        file.renameSync(previous.path);
      }
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      lastWriteError = null;
    } on FileSystemException catch (error) {
      lastWriteError =
          'Không ghi được log: ${error.osError?.errorCode ?? 'filesystem'}';
      stderr.writeln(lastWriteError);
    }
  }
}
