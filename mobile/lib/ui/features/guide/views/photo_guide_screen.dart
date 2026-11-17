import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../config/app_config.dart';
import '../../../../data/services/photo_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../navigation.dart';

/// Cara Foto yang Baik: four habits that decide whether a check works.
class PhotoGuideScreen extends StatelessWidget {
  const PhotoGuideScreen({super.key});

  static const _tips = [
    (
      icon: LucideIcons.leaf,
      title: 'Satu daun saja',
      text: 'Foto satu daun dari dekat, bukan seluruh pohon atau buahnya.',
    ),
    (
      icon: LucideIcons.sun,
      title: 'Cahaya terang',
      text:
          'Cari tempat yang terang. Hindari bayangan dan memotret saat gelap.',
    ),
    (
      icon: LucideIcons.focus,
      title: 'Gambar tajam',
      text: 'Tahan HP sebentar sampai gambarnya tidak buram.',
    ),
    (
      icon: LucideIcons.square,
      title: 'Latar polos',
      text: 'Kalau bisa, letakkan daun di atas kertas atau kain polos.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const AppTopBar(title: 'Cara Foto yang Baik'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.gutter,
              8,
              AppMetrics.gutter,
              24,
            ),
            children: [
              const _Example(),
              const SizedBox(height: 22),
              for (final (index, tip) in _tips.indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(tip.icon, size: 22, color: AppColors.green),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tip.title, style: AppText.itemTitle),
                            const SizedBox(height: 2),
                            Text(tip.text, style: AppText.noteMuted),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: Material(
      color: AppColors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppMetrics.gutter,
              12,
              AppMetrics.gutter,
              0,
            ),
            child: PrimaryButton(
              label: 'Foto Daun',
              icon: LucideIcons.camera,
              height: AppMetrics.barButtonHeight,
              onPressed: () =>
                  openScan(context, PhotoSource.camera, replace: true),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Example extends StatelessWidget {
  const _Example();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppMetrics.radius),
    child: AspectRatio(
      aspectRatio: 2,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppConfig.sampleAssets['karat_daun']!,
            fit: BoxFit.cover,
            semanticLabel:
                'Contoh foto yang baik: satu daun kopi di atas latar polos '
                'dengan cahaya terang',
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  'Contoh foto yang baik',
                  style: AppText.chip.copyWith(color: AppColors.text),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
