import 'package:cek_daun_kopi/domain/models/history_entry.dart';
import 'package:cek_daun_kopi/ui/features/result/view_models/share_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  final content = loadContent();
  final now = DateTime(2026, 11, 17, 12);

  HistoryEntry entry(String sample, {String? block}) => HistoryEntry(
    id: '1',
    createdAt: DateTime(2026, 11, 17, 9, 12),
    imageFile: '1.jpg',
    result: sampleResult(sample),
    block: block,
  );

  test('reads as a complete message for someone without the app', () {
    final disease = content.diseaseFor('karat_daun')!;

    final text = buildShareText(
      entry: entry('karat_daun', block: 'Blok A'),
      disease: disease,
      content: content,
      now: now,
    );

    expect(text, startsWith('Hasil Cek Daun Kopi\n'));
    expect(text, contains('Karat Daun (Berbahaya)'));
    expect(text, contains('Tingkat keyakinan: Sangat yakin (86%)'));
    expect(text, contains('Lokasi di kebun: Blok A'));
    expect(text, contains('Diperiksa: 17 November, pukul 09.12'));
    for (final (index, step) in disease.treatment.indexed) {
      expect(text, contains('${index + 1}. $step'));
    }
    expect(text, endsWith(content.disclaimer));
  });

  test('leaves the garden block out when it was never noted', () {
    final text = buildShareText(
      entry: entry('sehat'),
      disease: content.diseaseFor('sehat')!,
      content: content,
      now: now,
    );

    expect(text, isNot(contains('Lokasi di kebun')));
    expect(text, contains('Daun Sehat (Sehat)'));
  });
}
