import 'package:lucide_icons_flutter/lucide_icons_600.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/disease.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/disease_sections.dart';

/// The treatment steps as a to-do list the farmer ticks off over the
/// following days.
class TreatmentChecklist extends StatelessWidget {
  const TreatmentChecklist({
    super.key,
    required this.disease,
    required this.completed,
    required this.onToggle,
  });

  final Disease disease;
  final Set<int> completed;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final steps = disease.treatment;
    final done = completed.where((index) => index < steps.length).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(treatmentTitle(disease), style: AppText.sectionTitle),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '$done dari ${steps.length} selesai',
                style: AppText.captionStrong.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Centang langkah yang sudah Anda kerjakan.',
          style: AppText.caption,
        ),
        const SizedBox(height: 8),
        for (final (index, step) in steps.indexed)
          _Step(
            number: index + 1,
            text: step,
            done: completed.contains(index),
            onTap: () => onToggle(index),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.text,
    required this.done,
    required this.onTap,
  });

  final int number;
  final String text;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: done,
    label: 'Langkah $number',
    child: InkWell(
      // The whole row toggles: a far bigger target than the box alone.
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepNumber(number),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  text,
                  style: done
                      ? AppText.bodyMuted.copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.icon,
                        )
                      : AppText.body,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _Box(done: done),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 120),
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: done ? AppColors.green : AppColors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: done ? AppColors.green : AppColors.icon,
        width: 1.5,
      ),
    ),
    child: done
        ? const Icon(LucideIcons600.check, size: 16, color: AppColors.white)
        : null,
  );
}
