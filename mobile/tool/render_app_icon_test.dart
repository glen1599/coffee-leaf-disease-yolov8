// Renders the launcher icon from the app's own leaf glyph.
//
//     flutter test tool/render_app_icon_test.dart
//     dart run flutter_launcher_icons
//
// Writes assets/branding/icon.png (full square, for iOS and older Android)
// and icon_foreground.png (leaf only, inside the adaptive-icon safe zone).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cek_daun_kopi/ui/core/theme/app_colors.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_600.dart';
import 'package:material_ui/material_ui.dart';

import '../test/support/app_harness.dart';

const _size = 1024.0;

Future<void> _render(
  WidgetTester tester, {
  required String path,
  required Color? background,
  required double leafSize,
}) async {
  final key = GlobalKey();
  tester.view
    ..physicalSize = const Size(_size, _size)
    ..devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          width: _size,
          height: _size,
          color: background,
          alignment: Alignment.center,
          // The glyph's visual centre sits slightly low and left; nudge it.
          child: Transform.translate(
            offset: Offset(leafSize * 0.02, -leafSize * 0.02),
            child: Icon(
              LucideIcons600.leaf,
              size: leafSize,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('render the launcher icon', (tester) async {
    addTearDown(tester.view.reset);
    await _render(
      tester,
      path: 'assets/branding/icon.png',
      background: AppColors.green,
      leafSize: _size * 0.58,
    );
    // Adaptive icons crop to a circle or squircle of ~66% of the canvas.
    await _render(
      tester,
      path: 'assets/branding/icon_foreground.png',
      background: null,
      leafSize: _size * 0.40,
    );
  });
}
