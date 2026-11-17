import 'package:flutter/foundation.dart';

import '../../../../data/repositories/detection_repository.dart';
import '../../../../data/repositories/history_repository.dart';
import '../../../../data/services/image_preparer.dart';
import '../../../../data/services/photo_picker.dart';
import '../../../../domain/models/history_entry.dart';

/// Why a check produced no result.
enum ScanFailure {
  /// The model found no coffee leaf on the photo.
  noLeaf,

  /// The user has not allowed the camera.
  cameraDenied,

  /// The file is damaged or is not a photo.
  unreadablePhoto,

  /// The camera, the gallery, the model or the storage failed.
  technical,
}

sealed class ScanState {
  const ScanState();
}

/// The camera or the gallery is open on top of the app.
class ScanPicking extends ScanState {
  const ScanPicking();
}

/// The user closed the camera or the gallery without choosing a photo.
class ScanCancelled extends ScanState {
  const ScanCancelled();
}

class ScanAnalysing extends ScanState {
  const ScanAnalysing(this.photo);

  final Uint8List photo;
}

/// The check is done and already stored in the history.
class ScanSaved extends ScanState {
  const ScanSaved(this.entry);

  final HistoryEntry entry;
}

class ScanFailed extends ScanState {
  const ScanFailed(this.reason);

  final ScanFailure reason;
}

/// One check from start to finish: get a photo, run the model, save it.
class ScanViewModel extends ChangeNotifier {
  ScanViewModel({
    required this._photos,
    required this._detection,
    required this._history,
  });

  final PhotoPicker _photos;
  final DetectionRepository _detection;
  final HistoryRepository _history;

  ScanState _state = const ScanPicking();
  ScanState get state => _state;

  bool _busy = false;
  bool _disposed = false;

  Future<void> start(PhotoSource source) async {
    if (_busy) return;
    _busy = true;
    try {
      _emit(const ScanPicking());
      _emit(await _run(source));
    } finally {
      _busy = false;
    }
  }

  Future<ScanState> _run(PhotoSource source) async {
    final Uint8List? photo;
    try {
      photo = await _photos.pick(source);
    } on CameraAccessDeniedException {
      return const ScanFailed(ScanFailure.cameraDenied);
    } on Object {
      return const ScanFailed(ScanFailure.technical);
    }
    if (photo == null) return const ScanCancelled();

    _emit(ScanAnalysing(photo));
    try {
      final result = await _detection.detect(photo);
      // A photo without a leaf is not a check worth keeping.
      if (!result.detected) return const ScanFailed(ScanFailure.noLeaf);
      return ScanSaved(await _history.add(imageBytes: photo, result: result));
    } on ImageDecodeException {
      return const ScanFailed(ScanFailure.unreadablePhoto);
    } on Object {
      return const ScanFailed(ScanFailure.technical);
    }
  }

  void _emit(ScanState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
