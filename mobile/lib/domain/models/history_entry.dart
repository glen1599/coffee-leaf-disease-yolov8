import 'scan_result.dart';

/// One past check, kept on the phone.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.imageFile,
    required this.result,
    this.block,
    this.completedSteps = const {},
    this.reminderAt,
    this.reminderDays,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    imageFile: json['image_file'] as String,
    result: ScanResult.fromJson(json['result'] as Map<String, dynamic>),
    block: json['block'] as String?,
    completedSteps: {
      for (final step in json['completed_steps'] as List<dynamic>? ?? const [])
        (step as num).toInt(),
    },
    reminderAt: json['reminder_at'] == null
        ? null
        : DateTime.parse(json['reminder_at'] as String),
    reminderDays: (json['reminder_days'] as num?)?.toInt(),
  );

  final String id;
  final DateTime createdAt;

  /// File name of the saved photo inside the history folder.
  final String imageFile;
  final ScanResult result;

  /// Where in the garden the leaf came from, as the farmer named it.
  final String? block;

  /// Indexes of the treatment steps the farmer has ticked off.
  final Set<int> completedSteps;

  /// When the phone should remind the farmer to check again, if asked.
  final DateTime? reminderAt;

  /// The option the farmer picked for [reminderAt]: in how many days.
  final int? reminderDays;

  HistoryEntry copyWith({
    String? Function()? block,
    Set<int>? completedSteps,
    DateTime? Function()? reminderAt,
    int? Function()? reminderDays,
  }) => HistoryEntry(
    id: id,
    createdAt: createdAt,
    imageFile: imageFile,
    result: result,
    block: block == null ? this.block : block(),
    completedSteps: completedSteps ?? this.completedSteps,
    reminderAt: reminderAt == null ? this.reminderAt : reminderAt(),
    reminderDays: reminderDays == null ? this.reminderDays : reminderDays(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'image_file': imageFile,
    'result': result.toJson(),
    'block': block,
    'completed_steps': completedSteps.toList()..sort(),
    'reminder_at': reminderAt?.toIso8601String(),
    'reminder_days': reminderDays,
  };
}
