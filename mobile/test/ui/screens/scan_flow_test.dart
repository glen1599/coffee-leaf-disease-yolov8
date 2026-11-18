import 'dart:typed_data';

import 'package:cek_daun_kopi/data/services/photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

void main() {
  late AppHarness app;

  setUpAll(loadAppFonts);
  setUp(() => app = AppHarness());
  tearDown(() => app.dispose());

  testWidgets('a photo goes from the camera straight to its result', (
    tester,
  ) async {
    app.photos.enqueue(samplePhoto('karat_daun'));
    await app.pump(tester);

    await app.tap(tester, find.text('Foto Daun'));

    expect(app.photos.requests, [PhotoSource.camera]);
    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
    expect(find.text('Karat Daun'), findsOneWidget);
    expect(find.text('Hasil ini tersimpan di Riwayat'), findsOneWidget);
    await app.preview(tester, 'hasil-baru');

    // Back goes to Beranda, which now lists the check.
    await app.tap(tester, find.byTooltip('Kembali'));
    expect(find.text('Pemeriksaan terakhir'), findsOneWidget);
  });

  testWidgets('closing the gallery returns to Beranda', (tester) async {
    app.photos.enqueue(null);
    await app.pump(tester);

    await app.tap(tester, find.text('Pilih dari Galeri'));

    expect(app.photos.requests, [PhotoSource.gallery]);
    expect(find.text('Periksa daun kopi Anda'), findsOneWidget);
  });

  testWidgets('a photo without a leaf explains how to take a better one', (
    tester,
  ) async {
    app.detection = detectionWith(ReplayRunner.blind());
    app.photos.enqueue(samplePhoto('sehat'));
    await app.pump(tester);

    await app.tap(tester, find.text('Foto Daun'));

    expect(find.text('Daun kopi tidak terlihat'), findsOneWidget);
    expect(find.textContaining('Pastikan satu daun'), findsOneWidget);
    await app.preview(tester, 'pesan-tidak-ada-daun');

    await app.tap(tester, find.text('Lihat Cara Foto yang Baik'));
    expect(find.text('Cara Foto yang Baik'), findsOneWidget);
  });

  testWidgets('a refused camera points to the settings', (tester) async {
    app.photos.enqueue(const CameraAccessDeniedException());
    await app.pump(tester);

    await app.tap(tester, find.text('Foto Daun'));

    expect(find.text('Kamera belum diizinkan'), findsOneWidget);
    await app.preview(tester, 'pesan-kamera');
    await app.tap(tester, find.text('Buka Pengaturan'));
    expect(app.settings.opened, 1);

    app.photos.enqueue(samplePhoto('karat_daun'));
    await app.tap(tester, find.text('Pilih dari Galeri'));
    expect(app.photos.requests.last, PhotoSource.gallery);
    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
  });

  testWidgets('a broken file asks for another photo', (tester) async {
    app.photos.enqueue(Uint8List.fromList('not a photo'.codeUnits));
    await app.pump(tester);

    await app.tap(tester, find.text('Pilih dari Galeri'));

    expect(find.text('Foto tidak bisa dibuka'), findsOneWidget);
    await app.preview(tester, 'pesan-foto-rusak');
  });

  testWidgets('a model failure can be retried', (tester) async {
    app.detection = detectionWith(BrokenRunner());
    app.photos.enqueue(samplePhoto('sehat'));
    await app.pump(tester);

    await app.tap(tester, find.text('Foto Daun'));

    expect(find.text('Pemeriksaan gagal'), findsOneWidget);
    await app.preview(tester, 'pesan-gagal');
    await app.tap(tester, find.text('Kembali ke Beranda'));
    expect(find.text('Periksa daun kopi Anda'), findsOneWidget);
  });
}
