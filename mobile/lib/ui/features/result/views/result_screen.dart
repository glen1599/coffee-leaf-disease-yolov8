import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/services/photo_picker.dart';
import '../../../../domain/models/disease.dart';
import '../../../../domain/models/history_entry.dart';
import '../../../app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/detection_photo.dart';
import '../../../core/widgets/disease_sections.dart';
import '../../../core/widgets/message_view.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../navigation.dart';
import '../view_models/result_view_model.dart';
import 'block_sheet.dart';
import 'confidence_panel.dart';
import 'reminder_panel.dart';
import 'treatment_checklist.dart';

/// The result of one check. The photo leads, then the verdict and what to
/// do; the explanation comes after.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.entryId,
    this.justSaved = false,
  });

  final String entryId;

  /// Opened straight after a check, as opposed to from Riwayat.
  final bool justSaved;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  ResultViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel != null) return;
    final dependencies = AppScope.of(context);
    _viewModel = ResultViewModel(
      entryId: widget.entryId,
      history: dependencies.history,
      content: dependencies.content,
      reminders: dependencies.reminders,
      sharer: dependencies.sharer,
      clock: dependencies.clock,
    );
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  Future<void> _editBlock(ResultViewModel viewModel) async {
    final name = await showBlockSheet(
      context,
      current: viewModel.entry?.block,
      suggestions: viewModel.knownBlocks,
    );
    if (name != null) await viewModel.setBlock(name);
  }

  Future<void> _confirmDelete(ResultViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pemeriksaan ini?'),
        content: const Text(
          'Foto, catatan, dan pengingatnya akan dihapus dari HP ini. '
          'Ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.text),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await viewModel.delete();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = _viewModel!;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final entry = viewModel.entry;
        final disease = viewModel.disease;
        final ready = entry != null && disease != null;
        return Scaffold(
          body: Column(
            children: [
              AppTopBar(
                title: 'Hasil Pemeriksaan',
                actions: [
                  if (ready)
                    IconButton(
                      onPressed: () => _confirmDelete(viewModel),
                      tooltip: 'Hapus pemeriksaan',
                      icon: const Icon(LucideIcons.trash2, size: 22),
                    ),
                ],
              ),
              Expanded(
                child: !viewModel.loaded
                    ? const SizedBox()
                    : ready
                    ? _Body(
                        viewModel: viewModel,
                        entry: entry,
                        disease: disease,
                        onEditBlock: () => _editBlock(viewModel),
                      )
                    : MessageView(
                        icon: LucideIcons.imageOff,
                        title: 'Pemeriksaan tidak ditemukan',
                        body: 'Pemeriksaan ini sudah dihapus dari HP ini.',
                        primaryLabel: 'Kembali',
                        onPrimary: () => Navigator.of(context).maybePop(),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: ready
              ? _Actions(viewModel: viewModel, justSaved: widget.justSaved)
              : null,
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.viewModel,
    required this.entry,
    required this.disease,
    required this.onEditBlock,
  });

  final ResultViewModel viewModel;
  final HistoryEntry entry;
  final Disease disease;
  final VoidCallback onEditBlock;

  String get _caption {
    final findings = viewModel.findingCount;
    return findings == 0
        ? 'Tidak ada tanda penyakit di foto ini. Cubit foto untuk '
              'memperbesar.'
        : 'Kotak merah menandai $findings bagian yang terkena. Cubit foto '
              'untuk memperbesar.';
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListView(
      padding: const EdgeInsets.only(bottom: 22),
      children: [
        DetectionPhoto(
          image: FileImage(viewModel.photo!),
          result: entry.result,
          severityOf: viewModel.severityOf,
          semanticLabel: viewModel.findingCount == 0
              ? 'Foto daun kopi yang diperiksa'
              : 'Foto daun kopi dengan ${viewModel.findingCount} bagian '
                    'yang ditandai kotak merah',
        ),
        ColoredBox(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.gutter,
              vertical: 10,
            ),
            child: Text(_caption, style: AppText.caption),
          ),
        ),
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
              const SizedBox(height: 18),
              ConfidencePanel(
                level: viewModel.confidenceLevel,
                label: viewModel.confidenceLabel,
                percent: viewModel.confidence,
              ),
              const SizedBox(height: 10),
              _BlockRow(block: entry.block, onTap: onEditBlock),
            ],
          ),
        ),
        const SectionBand(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            20,
            AppMetrics.gutter,
            22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TreatmentChecklist(
                disease: disease,
                completed: entry.completedSteps,
                onToggle: viewModel.toggleStep,
              ),
              const SizedBox(height: 12),
              ReminderPanel(
                options: ResultViewModel.reminderOptions,
                selectedDays: viewModel.reminderDays,
                reminderAt: viewModel.reminderAt,
                now: viewModel.now,
                blocked: viewModel.notificationsBlocked,
                onChoose: viewModel.chooseReminder,
                onOpenSettings: settings.openAppSettings,
              ),
            ],
          ),
        ),
        const SectionBand(),
        AboutSection(disease: disease),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
          child: NotePanel(text: viewModel.disclaimer),
        ),
      ],
    );
  }
}

/// Where in the garden the leaf came from; tap to note or change it.
class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.onTap});

  final String? block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final block = this.block;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  size: 22,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Lokasi di kebun', style: AppText.caption),
                      Text(
                        block ?? 'Belum dicatat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: block == null
                            ? AppText.itemTitle.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              )
                            : AppText.itemTitle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  block == null ? 'Catat' : 'Ubah',
                  style: AppText.note.copyWith(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Share, and the way on to the next leaf, fixed within reach of the thumb.
class _Actions extends StatelessWidget {
  const _Actions({required this.viewModel, required this.justSaved});

  final ResultViewModel viewModel;
  final bool justSaved;

  void _share(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject() as RenderBox?;
    viewModel.share(
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  @override
  Widget build(BuildContext context) => Material(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (justSaved) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.circleCheck,
                      size: 16,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hasil ini tersimpan di Riwayat',
                      style: AppText.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: Builder(
                      builder: (buttonContext) => SecondaryButton(
                        label: 'Bagikan',
                        icon: LucideIcons.share2,
                        height: AppMetrics.barButtonHeight,
                        onPressed: () => _share(buttonContext),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 16,
                    child: PrimaryButton(
                      label: 'Foto Daun Lain',
                      icon: LucideIcons.camera,
                      height: AppMetrics.barButtonHeight,
                      onPressed: () =>
                          openScan(context, PhotoSource.camera, replace: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
