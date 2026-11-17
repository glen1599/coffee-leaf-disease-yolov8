import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// A small square crop of a leaf photo.
class PhotoThumbnail extends StatelessWidget {
  const PhotoThumbnail({
    super.key,
    required this.image,
    required this.size,
    required this.semanticLabel,
    this.radius = 8,
  });

  final ImageProvider image;
  final double size;
  final double radius;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Decode at the size it is shown, not at camera resolution.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: ColoredBox(
          color: AppColors.surface,
          child: Image(
            image: ResizeImage(
              image,
              width: pixels,
              height: pixels,
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.cover,
            semanticLabel: semanticLabel,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Icon(
              LucideIcons.imageOff,
              size: size * 0.4,
              color: AppColors.icon,
            ),
          ),
        ),
      ),
    );
  }
}
