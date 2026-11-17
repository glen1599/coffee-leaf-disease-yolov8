import '../models/detection.dart';
import 'letterbox.dart';
import 'model_spec.dart';

/// Decode the raw model output into detections on the original photo.
///
/// [output] is the flattened `[8, 8400]` tensor: for every one of the 8400
/// candidate boxes the model gives a centre, a size and one score per class,
/// stored attribute by attribute (all centre-x values, then all centre-y
/// values, and so on).
///
/// Three steps, the same ones Ultralytics runs on the server:
/// 1. keep candidates whose best class score beats the threshold;
/// 2. non-maximum suppression, so one lesion is reported once;
/// 3. map the surviving boxes from model space back onto the photo.
///
/// The result is ordered from the most to the least confident.
List<Detection> decodeDetections(
  List<double> output,
  LetterboxGeometry geometry, {
  double confidenceThreshold = ModelSpec.confidenceThreshold,
  double iouThreshold = ModelSpec.iouThreshold,
  int maxDetections = ModelSpec.maxDetections,
  List<String> classNames = ModelSpec.classNames,
}) {
  final attributes = 4 + classNames.length;
  if (output.length % attributes != 0) {
    throw ArgumentError(
      'Output length ${output.length} is not a multiple of $attributes',
    );
  }
  final count = output.length ~/ attributes;

  final candidates = <_Candidate>[];
  for (var index = 0; index < count; index++) {
    var bestClass = 0;
    var bestScore = output[4 * count + index];
    for (var classIndex = 1; classIndex < classNames.length; classIndex++) {
      final score = output[(4 + classIndex) * count + index];
      if (score > bestScore) {
        bestScore = score;
        bestClass = classIndex;
      }
    }
    if (bestScore <= confidenceThreshold) continue;

    final centerX = output[index];
    final centerY = output[count + index];
    final halfWidth = output[2 * count + index] / 2;
    final halfHeight = output[3 * count + index] / 2;
    candidates.add(
      _Candidate(
        classIndex: bestClass,
        score: bestScore,
        x1: centerX - halfWidth,
        y1: centerY - halfHeight,
        x2: centerX + halfWidth,
        y2: centerY + halfHeight,
      ),
    );
  }
  candidates.sort((a, b) => b.score.compareTo(a.score));

  final kept = <_Candidate>[];
  for (final candidate in candidates) {
    if (kept.length >= maxDetections) break;
    final overlaps = kept.any(
      (other) => _overlap(other, candidate) > iouThreshold,
    );
    if (!overlaps) kept.add(candidate);
  }

  return [
    for (final item in kept)
      Detection(
        classId: classNames[item.classIndex],
        confidence: (item.score * 10000).round() / 100,
        box: BoundingBox(
          x1: roundHalfEven(geometry.toSourceX(item.x1)),
          y1: roundHalfEven(geometry.toSourceY(item.y1)),
          x2: roundHalfEven(geometry.toSourceX(item.x2)),
          y2: roundHalfEven(geometry.toSourceY(item.y2)),
        ),
      ),
  ];
}

class _Candidate {
  const _Candidate({
    required this.classIndex,
    required this.score,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final int classIndex;
  final double score;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
}

/// Intersection over union, treating boxes of different classes as far apart.
double _overlap(_Candidate a, _Candidate b) {
  final shiftA = a.classIndex * ModelSpec.classOffset;
  final shiftB = b.classIndex * ModelSpec.classOffset;
  final left = _max(a.x1 + shiftA, b.x1 + shiftB);
  final top = _max(a.y1 + shiftA, b.y1 + shiftB);
  final right = _min(a.x2 + shiftA, b.x2 + shiftB);
  final bottom = _min(a.y2 + shiftA, b.y2 + shiftB);

  final intersection = _max(right - left, 0) * _max(bottom - top, 0);
  final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
  final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
  return intersection / (areaA + areaB - intersection + 1e-7);
}

double _max(double a, double b) => a > b ? a : b;

double _min(double a, double b) => a < b ? a : b;
