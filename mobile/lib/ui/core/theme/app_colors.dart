import 'dart:ui';

import '../../../domain/models/disease.dart';

/// The whole palette. White dominates; green is the only accent, and the
/// status colours appear on results and nowhere else.
abstract final class AppColors {
  static const green = Color(0xFF0B7F3A);
  static const greenPressed = Color(0xFF086530);
  static const greenSoft = Color(0xFFE8F5EC);

  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF3F5F4);
  static const hairline = Color(0xFFE1E6E3);
  static const border = Color(0xFFC9D1CD);

  static const text = Color(0xFF1B2420);
  static const textMuted = Color(0xFF5A655F);
  static const icon = Color(0xFF8A948F);

  static const attention = Color(0xFFA84B05);
  static const attentionSoft = Color(0xFFFFF1DF);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFFDECEA);

  /// Outline of a finding drawn on top of a photograph.
  static const findingStroke = Color(0xFFE0352B);
}

/// Foreground and background of a status, by how urgent the finding is.
extension SeverityColors on Severity {
  Color get foreground => switch (this) {
    Severity.none => AppColors.green,
    Severity.moderate => AppColors.attention,
    Severity.high => AppColors.danger,
  };

  Color get background => switch (this) {
    Severity.none => AppColors.greenSoft,
    Severity.moderate => AppColors.attentionSoft,
    Severity.high => AppColors.dangerSoft,
  };
}
