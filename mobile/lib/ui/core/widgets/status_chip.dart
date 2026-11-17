import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/disease.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// "Sehat", "Perlu perhatian" or "Berbahaya". The only place, together with
/// the marks on a photo, where the status colours are used.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.severity,
    required this.label,
    this.prominent = false,
  });

  final Severity severity;
  final String label;

  /// Larger, with an icon: for the verdict on the result screen. Colour is
  /// never the only signal there.
  final bool prominent;

  IconData get _icon => switch (severity) {
    Severity.none => LucideIcons.circleCheck,
    Severity.moderate => LucideIcons.circleAlert,
    Severity.high => LucideIcons.triangleAlert,
  };

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: (prominent ? AppText.captionStrong : AppText.chip).copyWith(
        color: severity.foreground,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: severity.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: prominent
            ? const EdgeInsets.fromLTRB(8, 5, 10, 5)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: prominent
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: 16, color: severity.foreground),
                  const SizedBox(width: 6),
                  text,
                ],
              )
            : text,
      ),
    );
  }
}
