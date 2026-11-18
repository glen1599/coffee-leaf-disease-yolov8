/// How urgent a finding is. Drives the status colour in the interface.
enum Severity {
  none,
  moderate,
  high;

  static Severity fromKey(String key) => Severity.values.firstWhere(
    (value) => value.name == key,
    orElse: () => throw ArgumentError('Unknown severity "$key"'),
  );
}

/// One entry of the knowledge base: a leaf condition the model can recognise.
class Disease {
  const Disease({
    required this.id,
    required this.name,
    required this.status,
    required this.severity,
    required this.severityLabel,
    required this.pathogen,
    required this.summary,
    required this.symptoms,
    required this.treatment,
  });

  factory Disease.fromJson(Map<String, dynamic> json) => Disease(
    id: json['id'] as String,
    name: json['name'] as String,
    status: json['status'] as String,
    severity: Severity.fromKey(json['severity'] as String),
    severityLabel: json['severity_label'] as String,
    pathogen: json['pathogen'] as String,
    summary: json['summary'] as String,
    symptoms: List<String>.unmodifiable(json['symptoms'] as List<dynamic>),
    treatment: List<String>.unmodifiable(json['treatment'] as List<dynamic>),
  );

  /// Raw class key stored in the model, for example `karat_daun`.
  final String id;
  final String name;
  final String status;
  final Severity severity;
  final String severityLabel;
  final String pathogen;
  final String summary;
  final List<String> symptoms;

  /// What to do about it, in the order the knowledge base lists the steps.
  final List<String> treatment;

  /// Same keys as the API, so a stored copy reads back with [Disease.fromJson].
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status,
    'severity': severity.name,
    'severity_label': severityLabel,
    'pathogen': pathogen,
    'summary': summary,
    'symptoms': symptoms,
    'treatment': treatment,
  };
}
