import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/id_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';

/// "Remind me to check again" in 3, 7 or 14 days.
class ReminderPanel extends StatelessWidget {
  const ReminderPanel({
    super.key,
    required this.options,
    required this.selectedDays,
    required this.reminderAt,
    required this.now,
    required this.blocked,
    required this.onChoose,
    required this.onOpenSettings,
  });

  final List<int> options;
  final int? selectedDays;
  final DateTime? reminderAt;
  final DateTime now;

  /// The phone does not let the app show notifications.
  final bool blocked;
  final ValueChanged<int> onChoose;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final reminderAt = this.reminderAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.bell,
                size: 22,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ingatkan saya periksa lagi',
                  style: AppText.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (index, days) in options.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Option(
                    label: '$days hari',
                    selected: days == selectedDays,
                    onTap: () => onChoose(days),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (blocked) ...[
            Text(
              'Pengingat belum bisa dipasang karena notifikasi belum '
              'diizinkan untuk aplikasi ini.',
              style: AppText.caption.copyWith(color: AppColors.attention),
            ),
            TextButton(
              onPressed: onOpenSettings,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: const Text('Buka Pengaturan'),
            ),
          ] else
            Text(
              reminderAt == null
                  ? 'Pilih kapan HP perlu mengingatkan Anda.'
                  : 'HP akan memberi tahu Anda pada '
                        '${formatDateAndClock(reminderAt, now: now)}. '
                        'Ketuk lagi untuk membatalkan.',
              style: AppText.caption,
            ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.greenSoft : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppColors.green : AppColors.border,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Text(
              label,
              style: AppText.body.copyWith(
                color: selected ? AppColors.green : AppColors.text,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
