import 'dart:io';

/// A small dependency gate, in addition to analyzer checks.
void main() {
  final violations = <String>[];
  final imports = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');
  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final source = file.path.replaceAll('\\', '/');
    for (final match in imports.allMatches(file.readAsStringSync())) {
      final uri = match.group(1)!;
      final target = uri.startsWith('package:flutter_qr_attendance/')
          ? 'lib/${uri.substring('package:flutter_qr_attendance/'.length)}'
          : file.uri.resolve(uri).path;
      final presentation =
          target.contains('/features/') || target.contains('/app/');
      if ((source.startsWith('lib/core/') || source.startsWith('lib/data/')) &&
          (presentation || uri.startsWith('package:provider/'))) {
        violations.add('$source -> $uri');
      }
      if (!source.startsWith('lib/dev/') && target.contains('/dev/')) {
        violations.add('$source imports development fixtures: $uri');
      }
      if (source.startsWith('lib/features/') &&
          (target.endsWith('/google_apps_script_attendance_service.dart') ||
              target.endsWith('/attendance_service.dart'))) {
        violations.add('$source must depend on repository contracts: $uri');
      }
    }
  }
  if (violations.isNotEmpty) {
    stderr.writeln(violations.join('\n'));
    exitCode = 1;
  } else {
    stdout.writeln('Architecture boundaries passed.');
  }
}
