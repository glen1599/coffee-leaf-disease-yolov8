import 'dart:convert';
import 'dart:io';

import 'package:cek_daun_kopi/config/app_config.dart';
import 'package:cek_daun_kopi/domain/detection/model_spec.dart';
import 'package:cek_daun_kopi/domain/models/confidence.dart';
import 'package:cek_daun_kopi/domain/models/content_bundle.dart';
import 'package:cek_daun_kopi/domain/models/disease.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _exported() =>
    jsonDecode(File(AppConfig.contentAsset).readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('the bundle exported from the server', () {
    test('describes every class the model can predict', () {
      final bundle = ContentBundle.fromJson(_exported());
      expect(
        bundle.diseases.map((disease) => disease.id).toSet(),
        ModelSpec.classNames.toSet(),
      );
    });

    test('is Indonesian by default', () {
      final bundle = ContentBundle.fromJson(_exported());
      expect(bundle.language, 'id');

      final rust = bundle.diseaseFor('karat_daun')!;
      expect(rust.name, 'Karat Daun');
      expect(rust.severity, Severity.high);
      expect(rust.severityLabel, 'Berbahaya');
      expect(rust.pathogen, contains('Hemileia vastatrix'));
      expect(rust.symptoms, hasLength(3));
      expect(rust.treatment, hasLength(4));

      expect(bundle.diseaseFor('sehat')!.severity, Severity.none);
      expect(bundle.diseaseFor('pengorok_daun')!.severity, Severity.moderate);
      expect(bundle.noLeafMessage, startsWith('Daun kopi tidak terlihat'));
      expect(bundle.disclaimer, contains('penyuluh'));
    });

    test('can also be read in English', () {
      final bundle = ContentBundle.fromJson(_exported(), language: 'en');
      expect(bundle.diseaseFor('karat_daun')!.name, 'Coffee Leaf Rust');
      expect(bundle.confidenceLabelFor(99), 'Very confident');
    });

    test('keeps both languages the same shape', () {
      final indonesian = ContentBundle.fromJson(_exported(), language: 'id');
      final english = ContentBundle.fromJson(_exported(), language: 'en');
      for (final disease in indonesian.diseases) {
        final other = english.diseaseFor(disease.id)!;
        expect(disease.severity, other.severity, reason: disease.id);
        expect(
          disease.symptoms.length,
          other.symptoms.length,
          reason: disease.id,
        );
        expect(
          disease.treatment.length,
          other.treatment.length,
          reason: disease.id,
        );
      }
    });

    test('carries the validation metrics of the model', () {
      final metrics = ContentBundle.fromJson(_exported()).metrics;
      expect(metrics.keys, containsAll(['precision', 'recall', 'map50']));
      for (final value in metrics.values) {
        expect(value, inInclusiveRange(0, 100));
      }
    });

    test('rejects a language it does not contain', () {
      expect(
        () => ContentBundle.fromJson(_exported(), language: 'fr'),
        throwsArgumentError,
      );
    });

    test('returns null for a class it does not know', () {
      final bundle = ContentBundle.fromJson(_exported());
      expect(bundle.diseaseFor('person'), isNull);
      expect(bundle.diseaseFor(null), isNull);
    });
  });

  group('confidence wording', () {
    test('follows the thresholds exported by the server', () {
      final bundle = ContentBundle.fromJson(_exported());
      final bands = bundle.confidenceBands;

      expect(bands.levelFor(bands.highFrom), ConfidenceLevel.high);
      expect(bands.levelFor(bands.highFrom - 0.01), ConfidenceLevel.medium);
      expect(bands.levelFor(bands.mediumFrom), ConfidenceLevel.medium);
      expect(bands.levelFor(bands.mediumFrom - 0.01), ConfidenceLevel.low);

      expect(bundle.confidenceLabelFor(96.16), 'Sangat yakin');
      expect(bundle.confidenceLabelFor(70), 'Cukup yakin');
      expect(bundle.confidenceLabelFor(30), 'Kurang yakin');
    });

    test('fills one meter bar per level', () {
      expect(ConfidenceLevel.high.bars, 3);
      expect(ConfidenceLevel.medium.bars, 2);
      expect(ConfidenceLevel.low.bars, 1);
    });
  });
}
