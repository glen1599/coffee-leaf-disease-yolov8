import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_buttons.dart';

/// A full-screen message for when something is in the way: what happened,
/// what to do about it, and the buttons that do it.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = this.primaryLabel;
    final secondaryLabel = this.secondaryLabel;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 32, color: AppColors.text),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        style: AppText.messageTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: AppText.bodyMuted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (primaryLabel != null)
              PrimaryButton(
                label: primaryLabel,
                onPressed: onPrimary,
                height: 56,
              ),
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              QuietButton(label: secondaryLabel, onPressed: onSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
