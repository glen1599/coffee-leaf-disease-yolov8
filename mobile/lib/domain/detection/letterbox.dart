import 'model_spec.dart';

/// How a photo is fitted into the square model input.
///
/// The photo keeps its aspect ratio: it is scaled until the longer side is
/// [ModelSpec.inputSize] and centred, and the remaining border is padded with
/// grey. The same numbers map a box found by the model back onto the photo.
class LetterboxGeometry {
  const LetterboxGeometry({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.scale,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.left,
    required this.top,
  });

  factory LetterboxGeometry.forImage(int width, int height) {
    if (width <= 0 || height <= 0) {
      throw ArgumentError('Image size must be positive, got $width x $height');
    }
    const size = ModelSpec.inputSize;
    final scale = size / width < size / height ? size / width : size / height;
    final resizedWidth = roundHalfEven(width * scale);
    final resizedHeight = roundHalfEven(height * scale);
    return LetterboxGeometry(
      sourceWidth: width,
      sourceHeight: height,
      scale: scale,
      resizedWidth: resizedWidth,
      resizedHeight: resizedHeight,
      // The -0.1 sends an odd leftover pixel to the right / bottom edge.
      left: roundHalfEven((size - resizedWidth) / 2 - 0.1),
      top: roundHalfEven((size - resizedHeight) / 2 - 0.1),
    );
  }

  final int sourceWidth;
  final int sourceHeight;

  /// Model pixels per photo pixel.
  final double scale;

  /// Size of the photo once scaled, before padding.
  final int resizedWidth;
  final int resizedHeight;

  /// Padding in front of the scaled photo.
  final int left;
  final int top;

  /// Map an x coordinate in model space back onto the photo.
  double toSourceX(double x) =>
      ((x - left) / scale).clamp(0, sourceWidth).toDouble();

  /// Map a y coordinate in model space back onto the photo.
  double toSourceY(double y) =>
      ((y - top) / scale).clamp(0, sourceHeight).toDouble();
}

/// Round to the nearest integer, ties going to the even neighbour.
///
/// This is what Python's `round()` does, and the reference pipeline is
/// written in Python; `num.round()` in Dart sends ties away from zero.
int roundHalfEven(double value) {
  final floor = value.floorToDouble();
  final fraction = value - floor;
  if (fraction < 0.5) return floor.toInt();
  if (fraction > 0.5) return floor.toInt() + 1;
  return floor.toInt().isEven ? floor.toInt() : floor.toInt() + 1;
}
