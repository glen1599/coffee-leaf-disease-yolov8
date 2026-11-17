import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../domain/detection/letterbox.dart';
import '../../domain/detection/preprocess.dart';

/// A photo decoded and laid out the way the model wants it.
class PreparedImage {
  const PreparedImage({required this.geometry, required this.tensor});

  /// Size of the upright photo and how it was fitted into the model input.
  final LetterboxGeometry geometry;

  /// `1 x 3 x 640 x 640` float input, see [preprocess].
  final Float32List tensor;
}

/// The bytes are not a photo this app can read.
class ImageDecodeException implements Exception {
  const ImageDecodeException();

  @override
  String toString() => 'ImageDecodeException: not a decodable image';
}

/// Decode [bytes] and build the model input on the calling isolate.
///
/// Phone cameras store a sideways photo plus an EXIF "rotate me" flag; the
/// rotation is applied here so boxes land where the user sees the leaf.
PreparedImage prepareImageSync(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    throw const ImageDecodeException();
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    throw const ImageDecodeException();
  }

  final upright = img.bakeOrientation(decoded);
  final rgb = upright.convert(format: img.Format.uint8, numChannels: 3);
  final geometry = LetterboxGeometry.forImage(rgb.width, rgb.height);
  return PreparedImage(
    geometry: geometry,
    tensor: preprocess(rgb.toUint8List(), geometry),
  );
}

/// Same as [prepareImageSync], off the UI thread.
///
/// Decoding a camera photo in pure Dart takes long enough to drop frames, so
/// it runs on a short-lived background isolate.
Future<PreparedImage> prepareImage(Uint8List bytes) =>
    Isolate.run(() => prepareImageSync(bytes));
