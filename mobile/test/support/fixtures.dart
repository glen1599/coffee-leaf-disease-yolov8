import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Fixtures written by `scripts/export_mobile_fixtures.py`.
///
/// `flutter test` runs with the package root as the working directory.
const fixturesDirectory = 'test/fixtures';

Map<String, dynamic> loadExpected() =>
    jsonDecode(File('$fixturesDirectory/expected.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> expectedSample(String key) =>
    (loadExpected()['samples'] as Map<String, dynamic>)[key]
        as Map<String, dynamic>;

/// The raw `[8, 8400]` model output recorded for one sample photo.
Float32List loadRawOutput(String key) {
  final compressed = File('$fixturesDirectory/$key.output.bin.gz')
      .readAsBytesSync();
  final bytes = Uint8List.fromList(gzip.decode(compressed));
  return bytes.buffer.asFloat32List();
}
