import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness app;

  setUpAll(loadAppFonts);
  setUp(() => app = AppHarness());
  tearDown(() => app.dispose());

  testWidgets('Riwayat invites a first check when empty', (tester) async {
    await app.pump(tester);
    await app.tap(tester, find.text('Riwayat'));

    expect(find.text('Belum ada pemeriksaan'), findsOneWidget);
    await app.preview(tester, 'riwayat-kosong');
  });

  testWidgets('Riwayat sums up the week and groups checks by day', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await app.seed(
        'bercak_phoma',
        DateTime(2026, 11, 16, 10, 5),
        block: 'Blok C',
      );
      await app.seed(
        'pengorok_daun',
        DateTime(2026, 11, 16, 16, 30),
        block: 'Blok A',
      );
      await app.seed('sehat', DateTime(2026, 11, 17, 8, 47), block: 'Blok B');
      await app.seed(
        'karat_daun',
        DateTime(2026, 11, 17, 9, 12),
        block: 'Blok A',
      );
    });
    await app.pump(tester);
    await app.tap(tester, find.text('Riwayat'));

    expect(find.text('7 hari terakhir'), findsOneWidget);
    expect(find.text('daun diperiksa'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('09.12, Blok A'), findsOneWidget);
    expect(find.text('16.30, Blok A'), findsOneWidget);
    await app.preview(tester, 'riwayat');

    await app.tap(tester, find.text('Pengorok Daun'));
    expect(find.text('Hasil Pemeriksaan'), findsOneWidget);
  });

  testWidgets('Info Penyakit lists every condition, most urgent first', (
    tester,
  ) async {
    await app.pump(tester);
    await app.tap(tester, find.text('Info Penyakit'));

    expect(
      find.text('Empat kondisi daun yang bisa dikenali aplikasi ini.'),
      findsOneWidget,
    );
    final names = ['Bercak Phoma', 'Karat Daun', 'Pengorok Daun', 'Daun Sehat'];
    final tops = [
      for (final name in names) tester.getTopLeft(find.text(name)).dy,
    ];
    expect(tops[0] < tops[2] && tops[1] < tops[2] && tops[2] < tops[3], isTrue);
    expect(find.textContaining('presisi model 96,99%'), findsOneWidget);
    await app.preview(tester, 'info');

    await app.tap(tester, find.text('Karat Daun'));
    expect(find.text('Tentang penyakit ini'), findsOneWidget);
    expect(find.text('Yang harus dilakukan'), findsOneWidget);
    await app.preview(tester, 'info-detail');
  });

  testWidgets('the photo guide opens from Beranda', (tester) async {
    await app.pump(tester);
    await app.tap(tester, find.text('Lihat cara foto yang baik'));

    expect(find.text('Cara Foto yang Baik'), findsOneWidget);
    for (final tip in [
      'Satu daun saja',
      'Cahaya terang',
      'Gambar tajam',
      'Latar polos',
    ]) {
      expect(find.text(tip), findsOneWidget);
    }
    await app.preview(tester, 'panduan');
  });

  testWidgets('back on another tab returns to Beranda', (tester) async {
    await app.pump(tester);
    await app.tap(tester, find.text('Info Penyakit'));

    final handled = await tester.binding.handlePopRoute();
    await app.settle(tester);

    expect(handled, isTrue);
    expect(find.text('Periksa daun kopi Anda'), findsOneWidget);
  });
}
