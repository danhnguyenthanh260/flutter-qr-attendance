import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const captureUi = bool.fromEnvironment('CAPTURE_UI');

Future<void> loadCaptureFonts() async {
  if (!captureUi) return;
  final fonts = {
    'Segoe UI': const String.fromEnvironment(
      'UI_TEXT_FONT',
      defaultValue: 'C:/Windows/Fonts/segoeui.ttf',
    ),
    'MaterialIcons': const String.fromEnvironment('UI_ICON_FONT'),
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!captureUi) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/ui-review').create(recursive: true);
    await File('build/ui-review/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
