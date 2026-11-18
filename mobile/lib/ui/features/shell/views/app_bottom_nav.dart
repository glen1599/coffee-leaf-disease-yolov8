import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

enum AppTab {
  home('Beranda', LucideIcons.house),
  history('Riwayat', LucideIcons.clock),
  info('Info Penyakit', LucideIcons.bookOpen);

  const AppTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The three destinations, within reach of the thumb.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.white,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              for (final tab in AppTab.values)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    onTap: () => onSelected(tab),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            // The bar must keep its own height, not take the whole screen.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.chip.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
