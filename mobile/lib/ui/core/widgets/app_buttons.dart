import 'package:material_ui/material_ui.dart';

import '../theme/app_text.dart';
import '../theme/app_theme.dart';

class _Label extends StatelessWidget {
  const _Label({required this.label, this.icon, this.compact = false});

  final String label;
  final IconData? icon;

  /// Two buttons side by side in a bar: smaller icon and gap, so the words
  /// keep fitting.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final icon = this.icon;
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: compact ? 20 : 24),
        SizedBox(width: compact ? 8 : 10),
        Flexible(child: text),
      ],
    );
  }
}

/// The one thing the screen wants the user to do: solid green.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppMetrics.buttonHeight,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final compact = height < AppMetrics.buttonHeight;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        textStyle: compact ? AppText.button.copyWith(fontSize: 16) : null,
      ),
      child: _Label(label: label, icon: icon, compact: compact),
    );
  }
}

/// The alternative next to a [PrimaryButton]: white with an outline.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppMetrics.buttonHeight,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final compact = height < AppMetrics.buttonHeight;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        textStyle: compact ? AppText.button.copyWith(fontSize: 16) : null,
      ),
      child: _Label(label: label, icon: icon, compact: compact),
    );
  }
}

/// A way out that should not compete for attention: green words only.
class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      textStyle: AppText.bodyStrong,
    ),
    child: _Label(label: label),
  );
}
