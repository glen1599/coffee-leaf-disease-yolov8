import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/disease.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/disease_sections.dart';
import '../../../core/widgets/status_chip.dart';
import 'info_screen.dart';

/// One entry of the knowledge base, read at leisure: what it looks like,
/// what it is and what to do about it.
class DiseaseScreen extends StatelessWidget {
  const DiseaseScreen({super.key, required this.disease});

  final Disease disease;

  @override
  Widget build(BuildContext context) {
    final disclaimer = AppScope.of(context).content.disclaimer;
    return Scaffold(
      body: Column(
        children: [
          const AppTopBar(title: 'Info Penyakit'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    8,
                    AppMetrics.gutter,
                    0,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppMetrics.radius),
                    child: AspectRatio(
                      aspectRatio: 2,
                      child: ColoredBox(
                        color: AppColors.surface,
                        child: Image(
                          image: sampleImageOf(disease),
                          fit: BoxFit.cover,
                          semanticLabel: 'Contoh foto: ${disease.name}',
                          errorBuilder: (_, _, _) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    18,
                    AppMetrics.gutter,
                    22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        severity: disease.severity,
                        label: disease.severityLabel,
                        prominent: true,
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(disease.name, style: AppText.verdict),
                      ),
                      const SizedBox(height: 2),
                      CauseLine(disease: disease),
                    ],
                  ),
                ),
                const SectionBand(),
                AboutSection(disease: disease),
                const SectionBand(),
                Padding(
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
                        treatmentTitle(disease),
                        style: AppText.sectionTitle,
                      ),
                      const SizedBox(height: 16),
                      for (final (index, step) in disease.treatment.indexed)
                        Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StepNumber(index + 1),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(step, style: AppText.body),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppMetrics.gutter,
                  ),
                  child: NotePanel(text: disclaimer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
