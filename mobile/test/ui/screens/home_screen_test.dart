import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness app;

  setUpAll(loadAppFonts);
  setUp(() => app = AppHarness());
  tearDown(() => app.dispose());

  testWidgets('Beranda offers the two ways to check a leaf', (tester) async {
    await app.pump(tester);

    expect(find.text('Periksa daun kopi Anda'), findsOneWidget);
    expect(find.text('Foto Daun'), findsOneWidget);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
    expect(find.text('Pemeriksaan terakhir'), findsNothing);
    await app.preview(tester, 'beranda-kosong');
  });

  testWidgets('Beranda shows the latest check', (tester) async {
    await tester.runAsync(
      () => app.seed('karat_daun', testNow, block: 'Blok A'),
    );
    await app.pump(tester);

    expect(find.text('Pemeriksaan terakhir'), findsOneWidget);
    expect(find.text('Karat Daun'), findsOneWidget);
    expect(find.text('Hari ini, 09.12'), findsOneWidget);
    expect(find.text('Berbahaya'), findsOneWidget);
    await app.preview(tester, 'beranda');
  });
}
