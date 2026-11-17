import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/photo_picker.dart';
import '../../../../domain/models/history_entry.dart';
import '../../../core/format/id_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/check_tile.dart';
import '../../../core/widgets/message_view.dart';
import '../../../navigation.dart';
import '../view_models/history_view_model.dart';

/// Riwayat: the week in three numbers, then every saved check by day.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.history});

  final HistoryViewModel history;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final days = history.days;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.gutter,
                20,
                AppMetrics.gutter,
                0,
              ),
              child: Semantics(
                header: true,
                child: Text('Riwayat', style: AppText.pageTitle),
              ),
            ),
            Expanded(
              child: !history.loaded
                  ? const SizedBox()
                  : days.isEmpty
                  ? MessageView(
                      icon: LucideIcons.clock,
                      title: 'Belum ada pemeriksaan',
                      body:
                          'Setiap daun yang Anda periksa akan tersimpan di '
                          'sini, di HP ini saja.',
                      primaryLabel: 'Foto Daun',
                      onPrimary: () => openScan(context, PhotoSource.camera),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        _Summary(summary: history.summary),
                        for (final day in days) ...[
                          _DayHeading(
                            label: formatDay(day.date, now: history.now),
                          ),
                          for (final (index, entry) in day.entries.indexed) ...[
                            if (index > 0)
                              const Divider(
                                indent: AppMetrics.gutter,
                                endIndent: AppMetrics.gutter,
                              ),
                            _tile(context, entry),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    ),
  );

  Widget _tile(BuildContext context, HistoryEntry entry) {
    final block = entry.block;
    final time = formatClock(entry.createdAt);
    return CheckTile(
      image: FileImage(history.imageOf(entry)),
      disease: history.diseaseOf(entry),
      detail: block == null ? time : '$time, $block',
      onTap: () => openResult(context, entry.id),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppMetrics.gutter,
      18,
      AppMetrics.gutter,
      0,
    ),
    child: Semantics(
      header: true,
      child: Text(label, style: AppText.captionStrong),
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppMetrics.gutter,
      16,
      AppMetrics.gutter,
      4,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${HistoryViewModel.summaryDays} hari terakhir',
          style: AppText.captionStrong,
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(AppMetrics.radius),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Count(value: summary.checked, label: 'daun diperiksa'),
                const VerticalDivider(width: 1, color: AppColors.hairline),
                _Count(
                  value: summary.dangerous,
                  label: 'berbahaya',
                  color: AppColors.danger,
                ),
                const VerticalDivider(width: 1, color: AppColors.hairline),
                _Count(
                  value: summary.needAttention,
                  label: 'perlu perhatian',
                  color: AppColors.attention,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.color});

  final int value;
  final String label;

  /// Status colour, used only when there is something to report.
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppText.pageTitle.copyWith(
              fontSize: 24,
              height: 30 / 24,
              letterSpacing: 0,
              color: value > 0 ? color : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.small),
        ],
      ),
    ),
  );
}
