import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const CekDaunKopiApp());
}

/// Application shell. The screens arrive in the next stage; for now this
/// only proves the project builds and the foundation underneath is wired.
class CekDaunKopiApp extends StatelessWidget {
  const CekDaunKopiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cek Daun Kopi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7F3A)),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      ),
      home: const Scaffold(body: Center(child: Text('Cek Daun Kopi'))),
    );
  }
}
