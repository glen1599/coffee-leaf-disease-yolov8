import 'dart:typed_data';

import 'model_runner.dart';

/// Loads the real runner the first time it is needed, and only once.
///
/// Creating an ONNX Runtime session reads a 12 MB model; doing that lazily
/// keeps the first screen instant. Call [warmUp] once the app is idle so the
/// first check does not pay for it either.
class LazyModelRunner implements ModelRunner {
  LazyModelRunner(this._load);

  final Future<ModelRunner> Function() _load;
  Future<ModelRunner>? _runner;

  Future<ModelRunner> _ensure() {
    final existing = _runner;
    if (existing != null) return existing;
    // A failed load is forgotten so the next check can try again.
    return _runner = _load().onError<Object>((error, stack) {
      _runner = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  /// Start loading in the background; failures surface on the next [run].
  void warmUp() => _ensure().ignore();

  @override
  Future<List<double>> run(Float32List input) async =>
      (await _ensure()).run(input);

  @override
  Future<void> close() async {
    final runner = _runner;
    _runner = null;
    if (runner != null) await (await runner).close();
  }
}
