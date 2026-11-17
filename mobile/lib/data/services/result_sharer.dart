import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

/// Hands a result to the phone's own share sheet (WhatsApp, SMS, ...).
abstract interface class ResultSharer {
  /// [origin] is where the share button sits; tablets anchor the sheet there.
  Future<void> share({required String text, File? photo, Rect? origin});
}

class SystemResultSharer implements ResultSharer {
  const SystemResultSharer();

  @override
  Future<void> share({required String text, File? photo, Rect? origin}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: photo != null && photo.existsSync()
            ? [XFile(photo.path, mimeType: 'image/jpeg')]
            : null,
        sharePositionOrigin: origin,
      ),
    );
  }
}
