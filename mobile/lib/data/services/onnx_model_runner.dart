import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../../config/app_config.dart';
import '../../domain/detection/model_spec.dart';
import 'model_runner.dart';

/// Runs `best.onnx` with ONNX Runtime, the same engine the server uses.
///
/// The session is created once and reused: loading the model is the slow
/// part, a single run is not.
class OnnxModelRunner implements ModelRunner {
  OnnxModelRunner._(this._session);

  /// Load the model bundled with the app.
  static Future<OnnxModelRunner> load({
    String asset = AppConfig.modelAsset,
  }) async {
    try {
      final session = await OnnxRuntime().createSessionFromAsset(asset);
      return OnnxModelRunner._(session);
    } on Object catch (error) {
      throw ModelRunnerException(error);
    }
  }

  final OrtSession _session;

  @override
  Future<List<double>> run(Float32List input) async {
    OrtValue? tensor;
    Map<String, OrtValue>? outputs;
    try {
      tensor = await OrtValue.fromList(input, ModelSpec.inputShape);
      outputs = await _session.run({ModelSpec.inputName: tensor});
      final output = outputs[ModelSpec.outputName];
      if (output == null) {
        throw StateError(
          'The model returned ${outputs.keys}, not "${ModelSpec.outputName}"',
        );
      }
      final values = await output.asFlattenedList();
      return values is List<double> ? values : values.cast<double>();
    } on Object catch (error) {
      throw ModelRunnerException(error);
    } finally {
      // Tensors live on the native side and are not garbage collected.
      await tensor?.dispose();
      for (final value in outputs?.values ?? const <OrtValue>[]) {
        await value.dispose();
      }
    }
  }

  @override
  Future<void> close() => _session.close();
}
