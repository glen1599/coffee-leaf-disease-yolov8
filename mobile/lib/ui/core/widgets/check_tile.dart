import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/disease.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import 'photo_thumbnail.dart';
import 'status_chip.dart';

/// One saved check as a row: photo, verdict, when and where, status.
class CheckTile extends StatelessWidget {
  const CheckTile({
    super.key,
    required this.image,
    required this.disease,
    required this.detail,
    required this.onTap,
    this.thumbnailSize = 56,
  });

  final ImageProvider image;

  /// `null` when the saved class is unknown to this version of the app.
  final Disease? disease;

  /// Time and garden block, for example "09.12, Blok A".
  final String detail;
  final VoidCallback onTap;
  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    final disease = this.disease;
    final name = disease?.name ?? 'Tidak dikenali';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.gutter,
          vertical: 12,
        ),
        child: Row(
          children: [
            PhotoThumbnail(
              image: image,
              size: thumbnailSize,
              semanticLabel: 'Foto daun, hasil $name',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppText.itemTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppText.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (disease != null) ...[
              const SizedBox(width: 8),
              StatusChip(
                severity: disease.severity,
                label: disease.severityLabel,
              ),
            ],
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: AppColors.icon,
            ),
          ],
        ),
      ),
    );
  }
}
