import 'detection.dart';

/// Everything the model found on one photograph.
class ScanResult {
  const ScanResult({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    required this.inferenceMs,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    detections: [
      for (final item in json['detections'] as List<dynamic>)
        Detection.fromJson(item as Map<String, dynamic>),
    ],
    imageWidth: (json['image_width'] as num).toInt(),
    imageHeight: (json['image_height'] as num).toInt(),
    inferenceMs: (json['inference_ms'] as num).toDouble(),
  );

  /// Detections ordered from the most to the least confident.
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;
  final double inferenceMs;

  /// `false` when the model saw no coffee leaf at all.
  bool get detected => detections.isNotEmpty;

  /// The verdict: the class of the single most confident detection, the same
  /// rule the server applies.
  String? get dominantClassId => detected ? detections.first.classId : null;

  /// Score of the verdict in percent, or `null` when nothing was found.
  double? get topConfidence => detected ? detections.first.confidence : null;

  Map<String, dynamic> toJson() => {
    'detections': [for (final item in detections) item.toJson()],
    'image_width': imageWidth,
    'image_height': imageHeight,
    'inference_ms': inferenceMs,
  };
}
