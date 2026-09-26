import 'package:flutter/material.dart';
import 'package:flutter_qr_attendance/core/theme/app_theme.dart';
import 'package:flutter_qr_attendance/dev/component_gallery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/visual_capture.dart';

void main() {
  setUpAll(loadCaptureFonts);
  testWidgets('isolated components switch states and retry without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RepaintBoundary(key: boundary, child: const ComponentGallery()),
      ),
    );
    await tester.tap(find.text('error'));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('empty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bảng điểm danh'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, boundary, 'components');
  });
}
