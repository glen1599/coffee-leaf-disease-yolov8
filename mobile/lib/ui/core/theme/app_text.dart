import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Type scale. One family, Plus Jakarta Sans, bundled with the app.
///
/// Nothing is smaller than 12 px, and running text is 15 px: the app is read
/// outdoors, at arm's length.
abstract final class AppText {
  static const family = 'PlusJakartaSans';

  static const _base = TextStyle(
    fontFamily: family,
    color: AppColors.text,
    fontWeight: FontWeight.w400,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    double spacing = 0,
    Color color = AppColors.text,
  }) => _base.copyWith(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color,
  );

  /// The name of the finding on the result screen.
  static final verdict = _style(32, 38, FontWeight.w800, spacing: -0.6);
  static final pageTitle = _style(28, 34, FontWeight.w800, spacing: -0.5);
  static final messageTitle = _style(22, 28, FontWeight.w800, spacing: -0.3);
  static final sectionTitle = _style(19, 26, FontWeight.w800, spacing: -0.2);
  static final barTitle = _style(17, 24, FontWeight.w700);
  static final button = _style(17, 22, FontWeight.w700);
  static final itemTitle = _style(16, 22, FontWeight.w700);

  static final body = _style(15, 22, FontWeight.w400);
  static final bodyStrong = _style(15, 22, FontWeight.w700);
  static final bodyMuted = _style(
    15,
    22,
    FontWeight.w400,
    color: AppColors.textMuted,
  );

  static final note = _style(14, 20, FontWeight.w400);
  static final noteMuted = _style(
    14,
    20,
    FontWeight.w400,
    color: AppColors.textMuted,
  );

  static final caption = _style(
    13,
    19,
    FontWeight.w400,
    color: AppColors.textMuted,
  );
  static final captionStrong = _style(
    13,
    19,
    FontWeight.w700,
    color: AppColors.textMuted,
  );

  static final chip = _style(12, 16, FontWeight.w700);
  static final small = _style(
    12,
    16,
    FontWeight.w400,
    color: AppColors.textMuted,
  );
}
