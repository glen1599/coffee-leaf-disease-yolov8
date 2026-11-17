/// Constants of the exported YOLOv8n model (`models/best.onnx`).
///
/// They mirror `scripts/export_mobile_fixtures.py`, the reference
/// implementation that is checked against the server. Change one side and
/// the fixture tests fail.
abstract final class ModelSpec {
  /// The model takes a square `inputSize` x `inputSize` RGB image.
  static const int inputSize = 640;

  /// Grey level used to pad the photo to a square (0-255).
  static const int padValue = 114;

  /// Detections scoring at or below this are dropped (0-1).
  static const double confidenceThreshold = 0.25;

  /// Two boxes of the same class overlapping more than this are one finding.
  static const double iouThreshold = 0.7;

  static const int maxDetections = 300;

  /// Boxes of different classes never suppress each other: each class is
  /// shifted this far apart before overlap is measured.
  static const double classOffset = 7680;

  /// Number of candidate boxes the model emits per image.
  static const int candidates = 8400;

  /// Class keys in the order the model emits their scores.
  static const List<String> classNames = [
    'bercak_phoma',
    'karat_daun',
    'pengorok_daun',
    'sehat',
  ];

  static const String inputName = 'images';
  static const String outputName = 'output0';

  static const List<int> inputShape = [1, 3, inputSize, inputSize];

  static int get outputLength => (4 + classNames.length) * candidates;
}
