import 'package:cek_daun_kopi/domain/detection/letterbox.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

void main() {
  group('roundHalfEven', () {
    test('sends ties to the even neighbour, like Python', () {
      expect(roundHalfEven(436.5), 436);
      expect(roundHalfEven(437.5), 438);
      expect(roundHalfEven(0.5), 0);
      expect(roundHalfEven(1.5), 2);
    });

    test('rounds everything else to the nearest integer', () {
      expect(roundHalfEven(159.4), 159);
      expect(roundHalfEven(159.6), 160);
      expect(roundHalfEven(320), 320);
    });
  });

  group('LetterboxGeometry', () {
    test('pads a wide photo above and below', () {
      final geometry = LetterboxGeometry.forImage(2048, 1024);
      expect(geometry.scale, 0.3125);
      expect(geometry.resizedWidth, 640);
      expect(geometry.resizedHeight, 320);
      expect(geometry.left, 0);
      expect(geometry.top, 160);
    });

    test('pads a tall photo left and right', () {
      final geometry = LetterboxGeometry.forImage(3000, 4000);
      expect(geometry.scale, 0.16);
      expect(geometry.resizedWidth, 480);
      expect(geometry.resizedHeight, 640);
      expect(geometry.left, 80);
      expect(geometry.top, 0);
    });

    test('leaves a square photo of the right size untouched', () {
      final geometry = LetterboxGeometry.forImage(640, 640);
      expect(geometry.scale, 1);
      expect(geometry.left, 0);
      expect(geometry.top, 0);
    });

    test('gives an odd leftover pixel to the far edge', () {
      // 873 x 1280 scales to 436.5 x 640: the tie rounds to 436, leaving 204
      // pixels of padding, 102 on each side.
      final even = LetterboxGeometry.forImage(873, 1280);
      expect(even.resizedWidth, 436);
      expect(even.left, 102);

      // 875 x 1280 scales to 437.5 -> 438, leaving 202 -> 101 each side.
      final other = LetterboxGeometry.forImage(875, 1280);
      expect(other.resizedWidth, 438);
      expect(other.left, 101);

      // 641 x 1280 scales to 320.5 -> 320 ... 877 x 1280 -> 438.5 -> 438;
      // an odd remainder: 870 x 1280 -> 435, leaving 205 -> 102 left, 103 right.
      final odd = LetterboxGeometry.forImage(870, 1280);
      expect(odd.resizedWidth, 435);
      expect(odd.left, 102);
    });

    test('maps model coordinates back onto the photo and clamps them', () {
      final geometry = LetterboxGeometry.forImage(2048, 1024);
      expect(geometry.toSourceX(320), 1024);
      expect(geometry.toSourceY(320), 512);
      expect(geometry.toSourceY(100), 0, reason: 'inside the top padding');
      expect(geometry.toSourceX(700), 2048, reason: 'past the right edge');
    });

    test('rejects an empty image', () {
      expect(() => LetterboxGeometry.forImage(0, 10), throwsArgumentError);
    });

    test('agrees with the Python reference for every sample photo', () {
      final samples = loadExpected()['samples'] as Map<String, dynamic>;
      expect(samples, isNotEmpty);
      for (final entry in samples.entries) {
        final sample = entry.value as Map<String, dynamic>;
        final expected = sample['letterbox'] as Map<String, dynamic>;
        final geometry = LetterboxGeometry.forImage(
          sample['width'] as int,
          sample['height'] as int,
        );
        expect(geometry.scale, expected['scale'], reason: entry.key);
        expect(geometry.left, expected['left'], reason: entry.key);
        expect(geometry.top, expected['top'], reason: entry.key);
      }
    });
  });
}
