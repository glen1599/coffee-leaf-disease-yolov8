import 'confidence.dart';
import 'disease.dart';

/// The knowledge base and wording the app ships offline, in one language.
///
/// The bundle is generated from the server code by
/// `scripts/export_mobile_content.py`, so the phone shows exactly what
/// `GET /api/v1/diseases` returns.
class ContentBundle {
  const ContentBundle({
    required this.language,
    required this.diseases,
    required this.confidenceBands,
    required this.confidenceLabels,
    required this.noLeafMessage,
    required this.disclaimer,
    required this.metrics,
  });

  /// Pick one language out of the exported bundle.
  factory ContentBundle.fromJson(
    Map<String, dynamic> json, {
    String? language,
  }) {
    final lang = language ?? json['default_language'] as String;
    final diseases = (json['diseases'] as Map<String, dynamic>)[lang];
    if (diseases == null) {
      throw ArgumentError('The content bundle has no language "$lang"');
    }
    final confidence = json['confidence'] as Map<String, dynamic>;
    final labels = confidence['labels'] as Map<String, dynamic>;
    final messages = json['messages'] as Map<String, dynamic>;

    return ContentBundle(
      language: lang,
      diseases: List.unmodifiable([
        for (final item in diseases as List<dynamic>)
          Disease.fromJson(item as Map<String, dynamic>),
      ]),
      confidenceBands: ConfidenceBands(
        highFrom: (confidence['high_from'] as num).toDouble(),
        mediumFrom: (confidence['medium_from'] as num).toDouble(),
      ),
      confidenceLabels: {
        for (final level in ConfidenceLevel.values)
          level: (labels[level.name] as Map<String, dynamic>)[lang] as String,
      },
      noLeafMessage:
          (messages['no_leaf_detected'] as Map<String, dynamic>)[lang]
              as String,
      disclaimer: (json['disclaimer'] as Map<String, dynamic>)[lang] as String,
      metrics: {
        for (final entry in (json['metrics'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as num).toDouble(),
      },
    );
  }

  final String language;

  /// Every condition the model recognises, in knowledge-base order.
  final List<Disease> diseases;
  final ConfidenceBands confidenceBands;
  final Map<ConfidenceLevel, String> confidenceLabels;

  /// Shown when a photo contains no coffee leaf.
  final String noLeafMessage;

  /// Reminder that the treatment text is generic advice.
  final String disclaimer;

  /// Validation metrics of the model, in percent.
  final Map<String, double> metrics;

  /// This bundle with newer knowledge-base text, for example from the API.
  ContentBundle withText({
    required List<Disease> diseases,
    required Map<String, double> metrics,
    required String disclaimer,
  }) => ContentBundle(
    language: language,
    diseases: List.unmodifiable(diseases),
    confidenceBands: confidenceBands,
    confidenceLabels: confidenceLabels,
    noLeafMessage: noLeafMessage,
    disclaimer: disclaimer,
    metrics: Map.unmodifiable(metrics),
  );

  /// The entry for a model class, or `null` for a class the bundle lacks.
  Disease? diseaseFor(String? classId) {
    for (final disease in diseases) {
      if (disease.id == classId) return disease;
    }
    return null;
  }

  /// Plain words for a score in percent, for example "Sangat yakin".
  String confidenceLabelFor(double percent) =>
      confidenceLabels[confidenceBands.levelFor(percent)]!;
}
