import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../config/app_config.dart';
import '../../../../domain/models/content_bundle.dart';
import '../../../../domain/models/disease.dart';
import '../../../app_scope.dart';
import '../../../core/format/id_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/disease_sections.dart';
import '../../../core/widgets/photo_thumbnail.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../navigation.dart';

/// Example photo of a condition. A condition without a sample resolves to
/// an asset that does not exist, which the image widgets show as a
/// placeholder.
ImageProvider sampleImageOf(Disease disease) =>
    AssetImage(AppConfig.sampleAssets[disease.id] ?? 'assets/images/samples/');

/// Info Penyakit: everything the model can recognise, most urgent first.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static const _numerals = ['Satu', 'Dua', 'Tiga', 'Empat', 'Lima', 'Enam'];

  /// "Empat kondisi", spelled out the way a person would write it.
  static String _countOf(int count) =>
      count >= 1 && count <= _numerals.length ? _numerals[count - 1] : '$count';

  /// Most urgent first; within a level, the order of the knowledge base.
  static List<Disease> _ordered(ContentBundle content) => [
    for (final severity in Severity.values.reversed)
      ...content.diseases.where((disease) => disease.severity == severity),
  ];

  @override
  Widget build(BuildContext context) {
    final content = AppScope.of(context).content;
    final diseases = _ordered(content);
    final precision = content.metrics['precision'];
    final recall = content.metrics['recall'];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Info Penyakit', style: AppText.pageTitle),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_countOf(diseases.length)} kondisi daun yang bisa '
                  'dikenali aplikasi ini.',
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (final (index, disease) in diseases.indexed) ...[
            if (index > 0)
              const Divider(
                indent: AppMetrics.gutter,
                endIndent: AppMetrics.gutter,
              ),
            _DiseaseTile(
              disease: disease,
              onTap: () => openDisease(context, disease),
            ),
          ],
          if (precision != null && recall != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.gutter,
                14,
                AppMetrics.gutter,
                0,
              ),
              child: NotePanel(
                title: 'Seberapa tepat hasilnya?',
                text:
                    'Pada foto uji, presisi model '
                    '${formatPercent(precision, decimals: 2)} dan recall '
                    '${formatPercent(recall, decimals: 2)}. Hasil di kebun '
                    'bisa berbeda, terutama pada foto yang buram atau gelap.',
              ),
            ),
        ],
      ),
    );
  }
}

class _DiseaseTile extends StatelessWidget {
  const _DiseaseTile({required this.disease, required this.onTap});

  final Disease disease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.gutter,
        vertical: 12,
      ),
      child: Row(
        children: [
          PhotoThumbnail(
            image: sampleImageOf(disease),
            size: 72,
            radius: 10,
            semanticLabel: 'Contoh foto: ${disease.name}',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(disease.name, style: AppText.barTitle),
                if (disease.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    disease.symptoms.first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(height: 18 / 13),
                  ),
                ],
                const SizedBox(height: 6),
                StatusChip(
                  severity: disease.severity,
                  label: disease.severityLabel,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.icon),
        ],
      ),
    ),
  );
}
