import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';

/// Ask where in the garden the leaf came from.
///
/// Resolves to the new name, to an empty string when the note was removed,
/// or to `null` when the sheet was dismissed.
Future<String?> showBlockSheet(
  BuildContext context, {
  required String? current,
  required List<String> suggestions,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _BlockSheet(current: current, suggestions: suggestions),
);

class _BlockSheet extends StatefulWidget {
  const _BlockSheet({required this.current, required this.suggestions});

  final String? current;
  final List<String> suggestions;

  @override
  State<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends State<_BlockSheet> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save([String? value]) =>
      Navigator.of(context).pop((value ?? _controller.text).trim());

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      for (final name in widget.suggestions)
        if (name != widget.current) name,
    ];
    return Padding(
      // Keep the field and the button above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            0,
            AppMetrics.gutter,
            16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Lokasi di kebun', style: AppText.sectionTitle),
              const SizedBox(height: 4),
              Text(
                'Catat dari bagian kebun mana daun ini, supaya mudah '
                'dicari lagi.',
                style: AppText.noteMuted,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: AppText.body,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Blok A',
                  counterText: '',
                ),
                onSubmitted: _save,
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in suggestions.take(6))
                      OutlinedButton(
                        onPressed: () => _save(name),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: AppText.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(name),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              PrimaryButton(label: 'Simpan', onPressed: _save, height: 56),
              if (widget.current != null)
                TextButton(
                  onPressed: () => _save(''),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Hapus lokasi'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
