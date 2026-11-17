import 'dart:typed_data';

/// Runs the detection model on one prepared input.
///
/// The interface keeps ONNX Runtime, a native plugin, out of everything that
/// has to be unit-tested on a development machine.
abstract interface class ModelRunner {
  /// Feed a `1 x 3 x 640 x 640` tensor, get the flattened `[8, 8400]` output.
  Future<List<double>> run(Float32List input);

  /// Release the native session.
  Future<void> close();
}

/// The model could not be loaded or failed while running.
class ModelRunnerException implements Exception {
  const ModelRunnerException(this.cause);

  final Object cause;

  @override
  String toString() => 'ModelRunnerException: $cause';
}
