import 'dart:typed_data';

import 'letterbox.dart';
import 'model_spec.dart';

/// Turn a decoded photo into the tensor the model expects.
///
/// [rgb] holds `width * height * 3` bytes, row by row, red first. The result
/// is a `1 x 3 x 640 x 640` float tensor in the 0-1 range, channel planes one
/// after another (all reds, then all greens, then all blues).
///
/// The resize is bilinear with pixel centres aligned, which is what
/// `cv2.INTER_LINEAR` does on the server, so the phone feeds the model very
/// nearly the same numbers.
Float32List preprocess(Uint8List rgb, LetterboxGeometry geometry) {
  final width = geometry.sourceWidth;
  final height = geometry.sourceHeight;
  if (rgb.length != width * height * 3) {
    throw ArgumentError(
      'Expected ${width * height * 3} RGB bytes for $width x $height, '
      'got ${rgb.length}',
    );
  }

  const size = ModelSpec.inputSize;
  const plane = size * size;
  final tensor = Float32List(3 * plane)
    ..fillRange(0, 3 * plane, ModelSpec.padValue / 255);

  final outWidth = geometry.resizedWidth;
  final outHeight = geometry.resizedHeight;
  final stepX = width / outWidth;
  final stepY = height / outHeight;

  // Horizontal taps are the same for every row: compute them once.
  final x0s = Int32List(outWidth);
  final x1s = Int32List(outWidth);
  final weightsX = Float64List(outWidth);
  for (var x = 0; x < outWidth; x++) {
    final source = ((x + 0.5) * stepX - 0.5).clamp(0, width - 1).toDouble();
    final floor = source.floor();
    x0s[x] = floor * 3;
    x1s[x] = (floor + 1 < width ? floor + 1 : floor) * 3;
    weightsX[x] = source - floor;
  }

  for (var y = 0; y < outHeight; y++) {
    final source = ((y + 0.5) * stepY - 0.5).clamp(0, height - 1).toDouble();
    final floor = source.floor();
    final rowA = floor * width * 3;
    final rowB = (floor + 1 < height ? floor + 1 : floor) * width * 3;
    final weightY = source - floor;
    final target = (y + geometry.top) * size + geometry.left;

    for (var x = 0; x < outWidth; x++) {
      final a = x0s[x];
      final b = x1s[x];
      final weightX = weightsX[x];
      for (var channel = 0; channel < 3; channel++) {
        final upper =
            rgb[rowA + a + channel] +
            (rgb[rowA + b + channel] - rgb[rowA + a + channel]) * weightX;
        final lower =
            rgb[rowB + a + channel] +
            (rgb[rowB + b + channel] - rgb[rowB + a + channel]) * weightX;
        // Round to a whole grey level first, as an 8-bit resize would.
        final level = (upper + (lower - upper) * weightY).roundToDouble();
        tensor[channel * plane + target + x] = level / 255;
      }
    }
  }
  return tensor;
}
