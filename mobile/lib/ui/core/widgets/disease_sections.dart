import 'package:material_ui/material_ui.dart';

import '../../../domain/models/disease.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Pieces of a disease description shared by the result of a check and the
/// Info Penyakit pages.

/// A pale band that separates two sections without drawing a box.
class SectionBand extends StatelessWidget {
  const SectionBand({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.surface, child: SizedBox(height: 8));
}

/// "Disebabkan jamur Hemileia vastatrix", the scientific name in italics.
class CauseLine extends StatelessWidget {
  const CauseLine({super.key, required this.disease});

  final Disease disease;

  // The knowledge base writes "Hemileia vastatrix (jamur)".
  static final _pattern = RegExp(r'^(.+?)\s*\((.+)\)$');

  @override
  Widget build(BuildContext context) {
    if (disease.severity == Severity.none) return const SizedBox.shrink();
    final match = _pattern.firstMatch(disease.pathogen);
    if (match == null) {
      return Text('Penyebab: ${disease.pathogen}', style: AppText.noteMuted);
    }
    return Text.rich(
      TextSpan(
        text: 'Disebabkan ${match.group(2)} ',
        children: [
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      style: AppText.noteMuted,
    );
  }
}

/// What the condition is and how to recognise it.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.disease});

  final Disease disease;

  @override
  Widget build(BuildContext context) {
    final healthy = disease.severity == Severity.none;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        20,
        AppMetrics.gutter,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            healthy ? 'Tentang daun sehat' : 'Tentang penyakit ini',
            style: AppText.sectionTitle,
          ),
          const SizedBox(height: 10),
          Text(disease.summary, style: AppText.body),
          const SizedBox(height: 18),
          Text(
            healthy ? 'Ciri-cirinya' : 'Gejala yang terlihat',
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: 8),
          for (final (index, symptom) in disease.symptoms.indexed)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 6, right: 10, top: 9),
                    child: SizedBox.square(
                      dimension: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.text,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: Text(symptom, style: AppText.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The number in front of a treatment step.
class StepNumber extends StatelessWidget {
  const StepNumber(this.number, {super.key});

  final int number;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppColors.greenSoft,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$number',
      style: AppText.note.copyWith(
        color: AppColors.green,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// A quiet grey panel for a caveat or an explanation.
class NotePanel extends StatelessWidget {
  const NotePanel({super.key, required this.text, this.title});

  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: AppText.note.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
          ],
          Text(text, style: AppText.caption),
        ],
      ),
    );
  }
}

/// Label of the treatment section: a healthy leaf has nothing to cure.
String treatmentTitle(Disease disease) => disease.severity == Severity.none
    ? 'Supaya tetap sehat'
    : 'Yang harus dilakukan';
