import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/photo_picker.dart';
import '../../../core/format/id_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/check_tile.dart';
import '../../../core/widgets/viewfinder_corners.dart';
import '../../../navigation.dart';
import '../../history/view_models/history_view_model.dart';

/// Beranda: one job, checking a leaf, and two ways to start it.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.history});

  final HistoryViewModel history;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Brand(),
                const SizedBox(height: 28),
                Text('Periksa daun kopi Anda', style: AppText.pageTitle),
                const SizedBox(height: 8),
                Text(
                  'Foto satu daun, lalu lihat penyakitnya dan cara '
                  'menanganinya. Bisa dipakai tanpa internet.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: 22),
                const _LeafFrame(),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Foto Daun',
                  icon: LucideIcons.camera,
                  onPressed: () => openScan(context, PhotoSource.camera),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Pilih dari Galeri',
                  icon: LucideIcons.image,
                  onPressed: () => openScan(context, PhotoSource.gallery),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: history,
            builder: (context, _) => _LatestCheck(history: history),
          ),
        ],
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(LucideIcons.leaf, size: 20, color: AppColors.green),
      ),
      const SizedBox(width: 10),
      Text(
        'Cek Daun Kopi',
        style: AppText.itemTitle.copyWith(letterSpacing: -0.1),
      ),
    ],
  );
}

/// The viewfinder panel: shows where the leaf goes and links to the guide.
class _LeafFrame extends StatelessWidget {
  const _LeafFrame();

  @override
  Widget build(BuildContext context) => ViewfinderCorners(
    child: Container(
      constraints: const BoxConstraints(minHeight: 214),
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons300.leaf, size: 64, color: AppColors.icon),
          const SizedBox(height: 12),
          Text(
            'Satu daun, cahaya terang, jarak dekat',
            textAlign: TextAlign.center,
            style: AppText.note.copyWith(fontWeight: FontWeight.w600),
          ),
          TextButton(
            onPressed: () => openPhotoGuide(context),
            style: TextButton.styleFrom(
              textStyle: AppText.note.copyWith(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.green,
              ),
            ),
            child: const Text('Lihat cara foto yang baik'),
          ),
        ],
      ),
    ),
  );
}

class _LatestCheck extends StatelessWidget {
  const _LatestCheck({required this.history});

  final HistoryViewModel history;

  @override
  Widget build(BuildContext context) {
    final latest = history.latest;
    if (latest == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            22,
            AppMetrics.gutter,
            0,
          ),
          child: Text(
            'Pemeriksaan terakhir',
            style: AppText.captionStrong.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        CheckTile(
          image: FileImage(history.imageOf(latest)),
          disease: history.diseaseOf(latest),
          detail: formatDayAndClock(latest.createdAt, now: history.now),
          thumbnailSize: 48,
          onTap: () => openResult(context, latest.id),
        ),
      ],
    );
  }
}
