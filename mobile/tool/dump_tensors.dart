// Writes the model input the app would build for each bundled sample photo,
// so the Python reference can run the real model on it:
//
//     dart run tool/dump_tensors.dart build/parity
//     python ../scripts/export_mobile_fixtures.py --tensors mobile/build/parity
//
// The only difference from the server is then who decoded and resized the
// JPEG, which is the one part the unit tests cannot pin down exactly.
import 'dart:convert';
import 'dart:io';

import 'package:cek_daun_kopi/data/services/image_preparer.dart';

const _samples = {
  'bercak_phoma': 'phoma_leaf_spot.jpg',
  'karat_daun': 'coffee_leaf_rust.jpg',
  'pengorok_daun': 'leaf_miner.jpg',
  'sehat': 'healthy_leaf.jpg',
};

void main(List<String> arguments) {
  final output = Directory(arguments.isEmpty ? 'build/parity' : arguments.first)
    ..createSync(recursive: true);

  for (final entry in _samples.entries) {
    final bytes = File('assets/images/samples/${entry.value}')
        .readAsBytesSync();
    final watch = Stopwatch()..start();
    final prepared = prepareImageSync(bytes);
    watch.stop();

    final geometry = prepared.geometry;
    File('${output.path}/${entry.key}.tensor.bin')
        .writeAsBytesSync(prepared.tensor.buffer.asUint8List());
    File('${output.path}/${entry.key}.json').writeAsStringSync(
      jsonEncode({
        'width': geometry.sourceWidth,
        'height': geometry.sourceHeight,
        'scale': geometry.scale,
        'left': geometry.left,
        'top': geometry.top,
      }),
    );
    stdout.writeln(
      '${entry.key}: ${geometry.sourceWidth}x${geometry.sourceHeight} '
      'prepared in ${watch.elapsedMilliseconds} ms',
    );
  }
}
