import 'dart:io';
import 'dart:typed_data';

import 'package:cek_daun_kopi/data/repositories/detection_repository.dart';
import 'package:cek_daun_kopi/data/services/image_preparer.dart';
import 'package:cek_daun_kopi/data/services/model_runner.dart';
import 'package:cek_daun_kopi/domain/detection/model_spec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

/// Stands in for ONNX Runtime: replays an output recorded from the real model.
class _ReplayRunner implements ModelRunner {
  _ReplayRunner(this.output);

  final List<double> output;
  Float32List? lastInput;

  @override
  Future<List<double>> run(Float32List input) async {
    lastInput = input;
    return output;
  }

  @override
  Future<void> close() async {}
}

class _BrokenRunner implements ModelRunner {
  @override
  Future<List<double>> run(Float32List input) async =>
      throw const ModelRunnerException('session lost');

  @override
  Future<void> close() async {}
}

Uint8List _samplePhoto(String key) =>
    File('assets/images/samples/${expectedSample(key)['file']}')
        .readAsBytesSync();

void main() {
  test(
    'turns a real photo and a recorded output into the server verdict',
    () async {
      final sample = expectedSample('karat_daun');
      final runner = _ReplayRunner(loadRawOutput('karat_daun'));
      final repository = DetectionRepository(
        runner: runner,
        preparer: (bytes) async => prepareImageSync(bytes),
      );

      final result = await repository.detect(_samplePhoto('karat_daun'));

      expect(
        runner.lastInput,
        hasLength(3 * ModelSpec.inputSize * ModelSpec.inputSize),
      );
      expect(result.imageWidth, sample['width']);
      expect(result.imageHeight, sample['height']);
      expect(result.detected, isTrue);
      expect(result.dominantClassId, 'karat_daun');
      expect(
        result.detections,
        hasLength((sample['detections'] as List).length),
      );
      expect(
        result.topConfidence,
        closeTo(
          ((sample['detections'] as List).first as Map)['confidence'] as num,
          0.011,
        ),
      );
      expect(result.inferenceMs, greaterThan(0));
    },
  );

  test('reports a photo with no leaf as not detected', () async {
    final repository = DetectionRepository(
      runner: _ReplayRunner(Float32List(ModelSpec.outputLength)),
      preparer: (bytes) async => prepareImageSync(bytes),
    );

    final result = await repository.detect(_samplePhoto('sehat'));

    expect(result.detected, isFalse);
    expect(result.dominantClassId, isNull);
    expect(result.topConfidence, isNull);
  });

  test('decodes on a background isolate by default', () async {
    final repository = DetectionRepository(
      runner: _ReplayRunner(loadRawOutput('sehat')),
    );
    final result = await repository.detect(_samplePhoto('sehat'));
    expect(result.dominantClassId, 'sehat');
    expect(result.imageWidth, 640);
  });

  test('refuses bytes that are not a photo', () async {
    final repository = DetectionRepository(
      runner: _ReplayRunner(loadRawOutput('sehat')),
      preparer: (bytes) async => prepareImageSync(bytes),
    );
    expect(
      () => repository.detect(Uint8List.fromList('not an image'.codeUnits)),
      throwsA(isA<ImageDecodeException>()),
    );
  });

  test('lets a model failure surface to the caller', () async {
    final repository = DetectionRepository(
      runner: _BrokenRunner(),
      preparer: (bytes) async => prepareImageSync(bytes),
    );
    expect(
      () => repository.detect(_samplePhoto('sehat')),
      throwsA(isA<ModelRunnerException>()),
    );
  });
}
