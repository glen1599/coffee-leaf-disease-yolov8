import 'package:cek_daun_kopi/ui/features/result/view_models/result_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness app;

  setUpAll(loadAppFonts);
  setUp(() => app = AppHarness());
  tearDown(() => app.dispose());

  Future<void> openFromHome(WidgetTester tester, String name) async {
    await app.pump(tester);
    await app.tap(tester, find.text(name).first);
  }

  testWidgets('shows the verdict, the action and the explanation', (
    tester,
  ) async {
    await tester.runAsync(
      () => app.seed('karat_daun', testNow, block: 'Blok A'),
    );
    await openFromHome(tester, 'Karat Daun');

    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
    expect(find.text('Berbahaya'), findsOneWidget);
    expect(find.text('Karat Daun'), findsOneWidget);
    expect(find.text('Sangat yakin'), findsOneWidget);
    expect(find.text('86%'), findsOneWidget);
    expect(find.text('Blok A'), findsOneWidget);
    expect(find.text('Yang harus dilakukan'), findsOneWidget);
    expect(find.text('0 dari 4 selesai'), findsOneWidget);
    expect(
      find.textContaining('Kotak merah menandai 26 bagian'),
      findsOneWidget,
    );
    // Opened from Beranda, not straight after a check.
    expect(find.text('Hasil ini tersimpan di Riwayat'), findsNothing);
    await app.preview(tester, 'hasil-atas');

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await app.settle(tester);
    await app.preview(tester, 'hasil-tengah');
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await app.settle(tester);
    await app.preview(tester, 'hasil-bawah');
    expect(find.text('Tentang penyakit ini'), findsOneWidget);
  });

  testWidgets('ticking a step and setting a reminder are saved', (
    tester,
  ) async {
    await tester.runAsync(() => app.seed('karat_daun', testNow));
    await openFromHome(tester, 'Karat Daun');

    await app.tap(tester, find.textContaining('Semprot fungisida sistemik'));
    expect(find.text('1 dari 4 selesai'), findsOneWidget);

    await app.tap(tester, find.text('7 hari'));
    expect(find.textContaining('24 November, pukul 07.00'), findsOneWidget);
    expect(app.reminders.scheduled, hasLength(1));
    await app.preview(tester, 'hasil-centang-pengingat');

    final saved = (await tester.runAsync(app.history.all))!.single;
    expect(saved.completedSteps, {0});
    expect(saved.reminderDays, 7);
  });

  testWidgets('says so when notifications are not allowed', (tester) async {
    app.reminders.allowed = false;
    await tester.runAsync(() => app.seed('karat_daun', testNow));
    await openFromHome(tester, 'Karat Daun');

    await app.tap(tester, find.text('3 hari'));

    expect(find.textContaining('notifikasi belum diizinkan'), findsOneWidget);
    await app.tap(tester, find.text('Buka Pengaturan'));
    expect(app.settings.opened, 1);
  });

  testWidgets('notes the garden block', (tester) async {
    await tester.runAsync(() => app.seed('sehat', testNow, block: 'Blok B'));
    await tester.runAsync(
      () => app.seed('karat_daun', testNow.add(const Duration(minutes: 1))),
    );
    await openFromHome(tester, 'Karat Daun');
    expect(find.text('Belum dicatat'), findsOneWidget);

    await app.tap(tester, find.text('Catat'));
    expect(find.text('Blok B'), findsOneWidget); // offered as a shortcut
    await app.preview(tester, 'hasil-lokasi');
    await tester.enterText(find.byType(TextField), 'Blok C');
    await app.tap(tester, find.text('Simpan'));

    expect(find.text('Blok C'), findsOneWidget);
    expect(find.text('Ubah'), findsOneWidget);
  });

  testWidgets('shares the result', (tester) async {
    await tester.runAsync(() => app.seed('karat_daun', testNow));
    await openFromHome(tester, 'Karat Daun');

    await app.tap(tester, find.text('Bagikan'));

    expect(app.sharer.calls, 1);
    expect(app.sharer.text, contains('Karat Daun (Berbahaya)'));
  });

  testWidgets('deletes only after asking', (tester) async {
    await tester.runAsync(() => app.seed('karat_daun', testNow));
    await openFromHome(tester, 'Karat Daun');

    await app.tap(tester, find.byTooltip('Hapus pemeriksaan'));
    expect(find.text('Hapus pemeriksaan ini?'), findsOneWidget);
    await app.preview(tester, 'hasil-hapus');
    await app.tap(tester, find.text('Batal'));
    expect(await tester.runAsync(app.history.all), hasLength(1));

    await app.tap(tester, find.byTooltip('Hapus pemeriksaan'));
    await app.tap(tester, find.text('Hapus'));

    expect(await tester.runAsync(app.history.all), isEmpty);
    expect(find.text('Periksa daun kopi Anda'), findsOneWidget);
    expect(find.text('Pemeriksaan terakhir'), findsNothing);
  });

  testWidgets('a healthy leaf reads as good news', (tester) async {
    await tester.runAsync(() => app.seed('sehat', testNow));
    await openFromHome(tester, 'Daun Sehat');

    expect(find.text('Sehat'), findsOneWidget);
    expect(find.textContaining('Tidak ada tanda penyakit'), findsOneWidget);
    await app.preview(tester, 'hasil-sehat');
    await tester.scrollUntilVisible(find.text('Supaya tetap sehat'), 300);
    expect(find.text('Supaya tetap sehat'), findsOneWidget);
  });

  test('reminder ids fit the 32-bit integer Android expects', () {
    expect(ResultViewModel.reminderOptions, [3, 7, 14]);
  });
}
