import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cek_daun_kopi/app.dart';
import 'package:cek_daun_kopi/data/repositories/detection_repository.dart';
import 'package:cek_daun_kopi/data/repositories/history_repository.dart';
import 'package:cek_daun_kopi/ui/app_scope.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

/// The moment every widget test pretends it is: a Tuesday morning.
final testNow = DateTime(2026, 11, 17, 9, 12);

/// A phone the size the design was drawn for.
const phoneSize = Size(390, 844);

/// Register the bundled fonts, so text is measured (and drawn in previews)
/// with the real typeface instead of the test placeholder font.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// The app with every door to the outside world replaced by a fake.
class AppHarness {
  AppHarness()
    : directory = Directory.systemTemp.createTempSync('cek_daun_kopi_test') {
    history = HistoryRepository(
      Directory('${directory.path}/history'),
      clock: () => now,
    );
  }

  final Directory directory;
  final photos = FakePhotoPicker();
  final reminders = FakeReminderScheduler();
  final sharer = FakeSharer();
  final settings = FakeSettingsOpener();
  final _boundary = GlobalKey();

  late final HistoryRepository history;
  DateTime now = testNow;

  /// What the model "sees"; swap it per test.
  DetectionRepository detection = replayDetection('karat_daun');

  void dispose() => directory.deleteSync(recursive: true);

  /// Save a check of sample [key] as if it had been made at [at].
  Future<void> seed(String key, DateTime at, {String? block}) async {
    final present = now;
    now = at;
    await history.add(
      imageBytes: samplePhoto(key),
      result: sampleResult(key),
      block: block,
    );
    now = present;
  }

  Future<void> pump(WidgetTester tester, {Size size = phoneSize}) async {
    tester.view
      ..physicalSize = size * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: CekDaunKopiApp(
          dependencies: AppDependencies(
            content: loadContent(),
            detection: detection,
            history: history,
            photos: photos,
            reminders: reminders,
            sharer: sharer,
            settings: settings,
            clock: () => now,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Let real file access and image decoding finish, then finish animations.
  ///
  /// Widget tests run on a fake clock where real I/O never completes on its
  /// own; `runAsync` opens a window in which it can.
  Future<void> settle(WidgetTester tester) async {
    // Keep opening real-time windows while something is still moving (the
    // progress bar while a photo is analysed), for at most ~10 seconds.
    for (var round = 0; round < 200; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (round >= 2 && !tester.binding.hasScheduledFrame) break;
    }
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  /// Write what is on screen to `$PREVIEW_DIR/<name>.png`, when that
  /// variable is set. This is how the screens are reviewed without a phone:
  ///
  ///     PREVIEW_DIR=build/previews flutter test test/ui/screens
  Future<void> preview(WidgetTester tester, String name) async {
    final target = Platform.environment['PREVIEW_DIR'];
    if (target == null || target.isEmpty) return;
    // Photos decode on real time, which the test clock does not give them.
    // Loads started on the test clock may never finish, so start over.
    imageCache
      ..clear()
      ..clearLiveImages();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(
          image.image,
          element,
          onError: (_, _) {},
        ).timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    });
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          _boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('$target/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }
}
