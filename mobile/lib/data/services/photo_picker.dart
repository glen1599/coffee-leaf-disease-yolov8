import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// The phone refused the camera because the user has not allowed it.
class CameraAccessDeniedException implements Exception {
  const CameraAccessDeniedException();
}

/// The camera or the gallery could not be opened at all.
class PhotoPickerException implements Exception {
  const PhotoPickerException(this.cause);

  final Object cause;

  @override
  String toString() => 'PhotoPickerException: $cause';
}

/// Gets one photo from the user.
abstract interface class PhotoPicker {
  /// The bytes of the chosen photo, or `null` when the user backed out.
  Future<Uint8List?> pick(PhotoSource source);
}

/// The system camera and the system photo picker.
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Longest side kept from a photo. The model looks at 640 px, so a
  /// 12-megapixel original only costs time and storage.
  static const maxSide = 1600.0;

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.gallery => ImageSource.gallery,
        },
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: 90,
      );
      return await file?.readAsBytes();
    } on PlatformException catch (error) {
      if (error.code == 'camera_access_denied') {
        throw const CameraAccessDeniedException();
      }
      throw PhotoPickerException(error);
    }
  }
}
