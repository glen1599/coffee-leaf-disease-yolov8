import 'dart:typed_data';

import 'package:cek_daun_kopi/domain/detection/letterbox.dart';
import 'package:cek_daun_kopi/domain/detection/model_spec.dart';
import 'package:cek_daun_kopi/domain/detection/preprocess.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = ModelSpec.inputSize;
const _plane = _size * _size;

Uint8List _solid(int width, int height, int r, int g, int b) {
  final bytes = Uint8List(width * height * 3);
  for (var i = 0; i < bytes.length; i += 3) {
    bytes[i] = r;
    bytes[i + 1] = g;
    bytes[i + 2] = b;
  }
  return bytes;
}

double _at(Float32List tensor, int channel, int x, int y) =>
    tensor[channel * _plane + y * _size + x];

void main() {
  test('produces one 640 x 640 plane per colour channel', () {
    final geometry = LetterboxGeometry.forImage(8, 8);
    final tensor = preprocess(_solid(8, 8, 0, 0, 0), geometry);
    expect(tensor.length, 3 * _plane);
  });

  test('keeps red, green and blue in that order, scaled to 0-1', () {
    final geometry = LetterboxGeometry.forImage(20, 20);
    final tensor = preprocess(_solid(20, 20, 255, 51, 0), geometry);
    expect(_at(tensor, 0, 320, 320), closeTo(1, 1e-6));
    expect(_at(tensor, 1, 320, 320), closeTo(0.2, 1e-6));
    expect(_at(tensor, 2, 320, 320), closeTo(0, 1e-6));
  });

  test('pads a wide photo with grey above and below', () {
    final geometry = LetterboxGeometry.forImage(200, 100);
    final tensor = preprocess(_solid(200, 100, 10, 20, 30), geometry);
    const grey = ModelSpec.padValue / 255;

    for (final channel in [0, 1, 2]) {
      expect(_at(tensor, channel, 320, 0), closeTo(grey, 1e-6));
      expect(_at(tensor, channel, 320, 159), closeTo(grey, 1e-6));
      expect(_at(tensor, channel, 320, 480), closeTo(grey, 1e-6));
      expect(_at(tensor, channel, 320, 639), closeTo(grey, 1e-6));
    }
    expect(_at(tensor, 0, 0, 160), closeTo(10 / 255, 1e-6));
    expect(_at(tensor, 1, 639, 479), closeTo(20 / 255, 1e-6));
  });

  test('blends neighbouring pixels when it enlarges a photo', () {
    // Two pixels side by side, black then white, stretched to 640 wide: the
    // left edge stays black, the right edge white, the middle is mid-grey.
    final rgb = Uint8List.fromList([0, 0, 0, 255, 255, 255]);
    final geometry = LetterboxGeometry.forImage(2, 1);
    final tensor = preprocess(rgb, geometry);
    final row = geometry.top;

    expect(_at(tensor, 0, 0, row), closeTo(0, 1e-6));
    expect(_at(tensor, 0, 639, row), closeTo(1, 1e-6));
    expect(_at(tensor, 0, 320, row), closeTo(0.5, 0.01));
    expect(
      _at(tensor, 0, 200, row),
      lessThan(_at(tensor, 0, 440, row)),
      reason: 'brightness rises from left to right',
    );
  });

  test('rejects a buffer that does not match the stated size', () {
    final geometry = LetterboxGeometry.forImage(4, 4);
    expect(() => preprocess(Uint8List(10), geometry), throwsArgumentError);
  });
}
