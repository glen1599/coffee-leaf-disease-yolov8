import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Shared measurements.
abstract final class AppMetrics {
  /// Left and right margin of every screen.
  static const gutter = 20.0;

  /// Corner radius of buttons, panels and photos.
  static const radius = 12.0;

  /// Height of the main actions: easy to hit with a thumb.
  static const buttonHeight = 60.0;

  /// Height of the actions inside a bottom bar.
  static const barButtonHeight = 56.0;
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.green,
        onPrimary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.textMuted,
        outline: AppColors.border,
        outlineVariant: AppColors.hairline,
        error: AppColors.danger,
        surfaceTint: AppColors.white,
      );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppMetrics.radius),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppText.family,
    scaffoldBackgroundColor: AppColors.white,
    splashFactory: InkRipple.splashFactory,
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    textTheme: TextTheme(
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      titleLarge: AppText.sectionTitle,
      titleMedium: AppText.itemTitle,
      labelLarge: AppText.button,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.hairline,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size.fromHeight(AppMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: AppText.button,
        shape: shape,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(AppMetrics.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: AppText.button,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: AppText.bodyStrong,
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      hintStyle: AppText.bodyMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: AppText.sectionTitle,
      contentTextStyle: AppText.bodyMuted,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: AppText.note.copyWith(color: AppColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green,
      linearTrackColor: AppColors.hairline,
    ),
  );
}
