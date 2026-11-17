import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_text.dart';

/// Back arrow and a title, for the screens that sit on top of the tabs.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.closes = false,
  });

  final String title;
  final List<Widget> actions;

  /// Show a cross instead of an arrow: the screen is a detour, not a step.
  final bool closes;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: closes ? 'Tutup' : 'Kembali',
            icon: Icon(
              closes ? LucideIcons.x : LucideIcons.arrowLeft,
              size: 24,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              style: AppText.barTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    ),
  );
}
