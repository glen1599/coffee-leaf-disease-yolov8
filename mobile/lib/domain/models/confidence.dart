/// A detection score expressed the way a person would say it.
enum ConfidenceLevel {
  high,
  medium,
  low;

  static ConfidenceLevel fromKey(String key) =>
      ConfidenceLevel.values.firstWhere((value) => value.name == key);

  /// How many of the three bars of the confidence meter are filled.
  int get bars => switch (this) {
    ConfidenceLevel.high => 3,
    ConfidenceLevel.medium => 2,
    ConfidenceLevel.low => 1,
  };
}

/// Where a score (in percent) stops being "low" and starts being "high".
///
/// These are presentation thresholds, not calibrated probabilities; the
/// values come from the server configuration so both sides agree.
class ConfidenceBands {
  const ConfidenceBands({required this.highFrom, required this.mediumFrom});

  final double highFrom;
  final double mediumFrom;

  ConfidenceLevel levelFor(double percent) {
    if (percent >= highFrom) return ConfidenceLevel.high;
    if (percent >= mediumFrom) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}
