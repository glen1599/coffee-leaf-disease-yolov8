import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/confidence.dart';
import '../../../core/format/id_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';

/// How sure the model is, in words first and as a number second.
class ConfidencePanel extends StatelessWidget {
  const ConfidencePanel({
    super.key,
    required this.level,
    required this.label,
    required this.percent,
  });

  final ConfidenceLevel level;
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.hairline),
      borderRadius: BorderRadius.circular(AppMetrics.radius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tingkat keyakinan', style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(label, style: AppText.barTitle),
                ],
              ),
            ),
            Text(
              formatPercent(percent),
              style: AppText.bodyMuted.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          label: 'Tingkat keyakinan ${level.bars} dari 3',
          child: Row(
            children: [
              for (var bar = 1; bar <= 3; bar++) ...[
                if (bar > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: bar <= level.bars
                          ? AppColors.green
                          : AppColors.hairline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (level == ConfidenceLevel.low) ...[
          const SizedBox(height: 10),
          Text(
            'Hasil ini belum pasti. Coba foto ulang dari jarak lebih dekat '
            'dan dengan cahaya yang terang.',
            style: AppText.caption,
          ),
        ],
      ],
    ),
  );
}
