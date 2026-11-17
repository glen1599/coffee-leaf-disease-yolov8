import 'dart:typed_data';

import '../../domain/detection/postprocess.dart';
import '../../domain/models/scan_result.dart';
import '../services/image_preparer.dart';
import '../services/model_runner.dart';

typedef ImagePreparer = Future<PreparedImage> Function(Uint8List bytes);

/// Finds disease on a leaf photo, entirely on the device.
///
/// Throws [ImageDecodeException] when the bytes are not a readable photo and
/// [ModelRunnerException] when the model itself fails.
class DetectionRepository {
  DetectionRepository({
    required this._runner,
    ImagePreparer preparer = prepareImage,
  }) : _prepare = preparer;

  final ModelRunner _runner;
  final ImagePreparer _prepare;

  Future<ScanResult> detect(Uint8List imageBytes) async {
    final stopwatch = Stopwatch()..start();
    final prepared = await _prepare(imageBytes);
    final output = await _runner.run(prepared.tensor);
    final detections = decodeDetections(output, prepared.geometry);
    stopwatch.stop();

    return ScanResult(
      detections: detections,
      imageWidth: prepared.geometry.sourceWidth,
      imageHeight: prepared.geometry.sourceHeight,
      inferenceMs: stopwatch.elapsedMicroseconds / 1000,
    );
  }
}
