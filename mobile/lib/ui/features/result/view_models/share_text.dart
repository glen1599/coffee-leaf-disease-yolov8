import '../../../../domain/models/content_bundle.dart';
import '../../../../domain/models/disease.dart';
import '../../../../domain/models/history_entry.dart';
import '../../../core/format/id_format.dart';

/// The message sent along with the photo when a result is shared, written
/// so an extension officer can read it without having the app.
String buildShareText({
  required HistoryEntry entry,
  required Disease disease,
  required ContentBundle content,
  required DateTime now,
}) {
  final confidence = entry.result.topConfidence ?? 0;
  final block = entry.block;
  final lines = <String>[
    'Hasil Cek Daun Kopi',
    '',
    '${disease.name} (${disease.severityLabel})',
    'Tingkat keyakinan: ${content.confidenceLabelFor(confidence)} '
        '(${formatPercent(confidence)})',
    if (block != null) 'Lokasi di kebun: $block',
    'Diperiksa: ${formatDate(entry.createdAt, now: now)}, '
        'pukul ${formatClock(entry.createdAt)}',
    '',
    'Saran penanganan:',
    for (final (index, step) in disease.treatment.indexed)
      '${index + 1}. $step',
    '',
    content.disclaimer,
  ];
  return lines.join('\n');
}
