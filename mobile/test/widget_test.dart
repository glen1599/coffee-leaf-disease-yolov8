import 'package:cek_daun_kopi/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app starts and shows its name', (tester) async {
    await tester.pumpWidget(const CekDaunKopiApp());
    expect(find.text('Cek Daun Kopi'), findsOneWidget);
  });
}
