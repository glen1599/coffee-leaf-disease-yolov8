import 'dart:typed_data';

import 'package:cek_daun_kopi/domain/detection/letterbox.dart';
import 'package:cek_daun_kopi/domain/detection/model_spec.dart';
import 'package:cek_daun_kopi/domain/detection/postprocess.dart';
import 'package:cek_daun_kopi/domain/models/detection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Build a raw output holding [boxes], laid out like the real model output.
///
/// Each box is `[centerX, centerY, width, height, classIndex, score]`.
Float32List _output(List<List<double>> boxes, {int classes = 4}) {
  final count = boxes.length;
  final output = Float32List((4 + classes) * count);
  for (var index = 0; index < count; index++) {
    final box = boxes[index];
    for (var attribute = 0; attribute < 4; attribute++) {
      output[attribute * count + index] = box[attribute];
    }
    output[(4 + box[4].toInt()) * count + index] = box[5];
  }
  return output;
}

void main() {
  // A 640 x 640 photo needs no scaling, so model space is photo space.
  final identity = LetterboxGeometry.forImage(640, 640);

  group('decodeDetections on synthetic output', () {
    test('drops candidates at or below the confidence threshold', () {
      final detections = decodeDetections(
        _output([
          [100, 100, 40, 40, 1, 0.25],
          [300, 300, 40, 40, 1, 0.26],
        ]),
        identity,
      );
      expect(detections, hasLength(1));
      expect(
        detections.single.box,
        const BoundingBox(x1: 280, y1: 280, x2: 320, y2: 320),
      );
    });

    test('reports one lesion once when two boxes overlap heavily', () {
      final detections = decodeDetections(
        _output([
          [100, 100, 40, 40, 1, 0.60],
          [101, 100, 40, 40, 1, 0.90],
        ]),
        identity,
      );
      expect(detections, hasLength(1));
      expect(detections.single.confidence, 90);
    });

    test('keeps boxes of the same class that barely touch', () {
      final detections = decodeDetections(
        _output([
          [100, 100, 40, 40, 1, 0.60],
          [130, 100, 40, 40, 1, 0.90],
        ]),
        identity,
      );
      expect(detections, hasLength(2));
    });

    test('never lets one class suppress another', () {
      final detections = decodeDetections(
        _output([
          [100, 100, 40, 40, 1, 0.60],
          [100, 100, 40, 40, 2, 0.90],
        ]),
        identity,
      );
      expect(detections.map((d) => d.classId), ['pengorok_daun', 'karat_daun']);
    });

    test('orders the result from most to least confident', () {
      final detections = decodeDetections(
        _output([
          [100, 100, 20, 20, 0, 0.40],
          [300, 300, 20, 20, 3, 0.95],
          [500, 500, 20, 20, 1, 0.70],
        ]),
        identity,
      );
      expect(detections.map((d) => d.confidence), [95, 70, 40]);
      expect(detections.first.classId, 'sehat');
    });

    test('maps boxes back onto a photo larger than the model input', () {
      final geometry = LetterboxGeometry.forImage(2048, 1024);
      final detections = decodeDetections(
        _output([
          [320, 320, 64, 32, 1, 0.80],
        ]),
        geometry,
      );
      // Scale 0.3125 and 160 px of padding on top.
      expect(
        detections.single.box,
        const BoundingBox(x1: 922, y1: 461, x2: 1126, y2: 563),
      );
    });

    test('returns nothing for an output with no confident candidate', () {
      expect(decodeDetections(_output([]), identity), isEmpty);
      expect(
        decodeDetections(Float32List(ModelSpec.outputLength), identity),
        isEmpty,
      );
    });

    test('rejects an output of the wrong shape', () {
      expect(
        () => decodeDetections(Float32List(7), identity),
        throwsArgumentError,
      );
    });
  });

  group('decodeDetections on recorded model output', () {
    for (final key in ['karat_daun', 'sehat']) {
      test('reproduces the server detections for $key', () {
        final sample = expectedSample(key);
        final expected = [
          for (final item in sample['detections'] as List<dynamic>)
            Detection.fromJson(item as Map<String, dynamic>),
        ];
        final geometry = LetterboxGeometry.forImage(
          sample['width'] as int,
          sample['height'] as int,
        );

        final actual = decodeDetections(loadRawOutput(key), geometry);

        expect(actual, hasLength(expected.length));
        for (var index = 0; index < expected.length; index++) {
          final want = expected[index];
          final got = actual[index];
          final where = '$key #$index';
          expect(got.classId, want.classId, reason: where);
          expect(
            got.confidence,
            closeTo(want.confidence, 0.011),
            reason: where,
          );
          expect(got.box.x1, closeTo(want.box.x1, 1), reason: where);
          expect(got.box.y1, closeTo(want.box.y1, 1), reason: where);
          expect(got.box.x2, closeTo(want.box.x2, 1), reason: where);
          expect(got.box.y2, closeTo(want.box.y2, 1), reason: where);
        }
      });
    }

    test('the recorded output has the shape the model is declared to have', () {
      expect(loadRawOutput('karat_daun').length, ModelSpec.outputLength);
      final model = loadExpected()['model'] as Map<String, dynamic>;
      expect(model['class_names'], ModelSpec.classNames);
      expect(model['input_size'], ModelSpec.inputSize);
      expect(model['pad_value'], ModelSpec.padValue);
      expect(model['conf_threshold'], ModelSpec.confidenceThreshold);
      expect(model['iou_threshold'], ModelSpec.iouThreshold);
      expect(model['max_detections'], ModelSpec.maxDetections);
    });
  });
}
