import 'dart:typed_data';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/photo_picker.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/message_view.dart';
import '../../../core/widgets/viewfinder_corners.dart';
import '../../../navigation.dart';
import '../view_models/scan_view_model.dart';

/// One check: opens the camera or the gallery, shows progress while the
/// model looks at the photo, then hands over to the result. When something
/// is in the way it says what, and what to do next.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.source});

  final PhotoSource source;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  ScanViewModel? _viewModel;
  late PhotoSource _source = widget.source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel != null) return;
    final dependencies = AppScope.of(context);
    _viewModel = ScanViewModel(
      photos: dependencies.photos,
      detection: dependencies.detection,
      history: dependencies.history,
    )..addListener(_onStateChanged);
    _start(_source);
  }

  @override
  void dispose() {
    _viewModel
      ?..removeListener(_onStateChanged)
      ..dispose();
    super.dispose();
  }

  void _start(PhotoSource source) {
    _source = source;
    _viewModel!.start(source);
  }

  void _onStateChanged() {
    if (!mounted) return;
    switch (_viewModel!.state) {
      case ScanCancelled():
        Navigator.of(context).maybePop();
      case ScanSaved(:final entry):
        openResult(context, entry.id, justSaved: true, replace: true);
      case ScanPicking() || ScanAnalysing() || ScanFailed():
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: _viewModel!,
      builder: (context, _) => switch (_viewModel!.state) {
        ScanAnalysing(:final photo) => _Analysing(photo: photo),
        ScanFailed(:final reason) => _failure(context, reason),
        // The camera or the gallery covers the app; nothing to show.
        ScanPicking() || ScanCancelled() || ScanSaved() => const SizedBox(),
      },
    ),
  );

  Widget _failure(BuildContext context, ScanFailure reason) {
    final dependencies = AppScope.of(context);
    final message = switch (reason) {
      ScanFailure.noLeaf => _noLeaf(
        context,
        dependencies.content.noLeafMessage,
      ),
      ScanFailure.cameraDenied => MessageView(
        icon: LucideIcons.cameraOff,
        title: 'Kamera belum diizinkan',
        body:
            'Aplikasi perlu izin kamera untuk memotret daun. Buka '
            'Pengaturan, lalu izinkan kamera.',
        primaryLabel: 'Buka Pengaturan',
        onPrimary: dependencies.settings.openAppSettings,
        secondaryLabel: 'Pilih dari Galeri',
        onSecondary: () => _start(PhotoSource.gallery),
      ),
      ScanFailure.unreadablePhoto => MessageView(
        icon: LucideIcons.imageOff,
        title: 'Foto tidak bisa dibuka',
        body: 'File ini rusak atau bukan foto. Pilih foto lain atau potret ulang.',
        primaryLabel: 'Foto Ulang',
        onPrimary: () => _start(PhotoSource.camera),
        secondaryLabel: 'Pilih dari Galeri',
        onSecondary: () => _start(PhotoSource.gallery),
      ),
      ScanFailure.technical => MessageView(
        icon: LucideIcons.triangleAlert,
        title: 'Pemeriksaan gagal',
        body:
            'Aplikasi tidak bisa memeriksa foto ini. Tutup aplikasi lain '
            'yang sedang terbuka, lalu coba lagi.',
        primaryLabel: 'Coba Lagi',
        onPrimary: () => _start(_source),
        secondaryLabel: 'Kembali ke Beranda',
        onSecondary: () => Navigator.of(context).maybePop(),
      ),
    };
    return Column(
      children: [
        const AppTopBar(title: '', closes: true),
        Expanded(child: message),
      ],
    );
  }

  /// The knowledge base words this as one paragraph, "Daun kopi tidak
  /// terlihat. Pastikan ...": its first sentence becomes the title.
  Widget _noLeaf(BuildContext context, String message) {
    final split = message.indexOf('. ');
    return MessageView(
      icon: LucideIcons.scanSearch,
      title: split < 0
          ? 'Daun kopi tidak terlihat'
          : message.substring(0, split),
      body: split < 0 ? message : message.substring(split + 2),
      primaryLabel: 'Foto Ulang',
      onPrimary: () => _start(_source),
      secondaryLabel: 'Lihat Cara Foto yang Baik',
      onSecondary: () => openPhotoGuide(context, replace: true),
    );
  }
}

class _Analysing extends StatelessWidget {
  const _Analysing({required this.photo});

  final Uint8List photo;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ViewfinderCorners(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: ColoredBox(
                  color: AppColors.surface,
                  child: Image.memory(
                    photo,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    // Shown small: no need to decode at camera resolution.
                    cacheWidth: 1080,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            liveRegion: true,
            child: Text(
              'Memeriksa daun…',
              style: AppText.messageTitle,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tunggu sebentar. Foto diperiksa di HP ini, tanpa internet.',
            style: AppText.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(minHeight: 6),
          ),
        ],
      ),
    ),
  );
}
