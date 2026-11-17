import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cek_daun_kopi/data/repositories/detection_repository.dart';
import 'package:cek_daun_kopi/data/services/image_preparer.dart';
import 'package:cek_daun_kopi/data/services/model_runner.dart';
import 'package:cek_daun_kopi/data/services/photo_picker.dart';
import 'package:cek_daun_kopi/data/services/reminder_scheduler.dart';
import 'package:cek_daun_kopi/data/services/result_sharer.dart';
import 'package:cek_daun_kopi/data/services/settings_opener.dart';
import 'package:cek_daun_kopi/domain/detection/model_spec.dart';
import 'package:cek_daun_kopi/domain/models/content_bundle.dart';
import 'package:cek_daun_kopi/domain/models/detection.dart';
import 'package:cek_daun_kopi/domain/models/scan_result.dart';

import 'fixtures.dart';

/// The knowledge base exactly as the app ships it.
ContentBundle loadContent() => ContentBundle.fromJson(
  jsonDecode(File('assets/content/diseases.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// One of the four sample photos bundled with the app.
File sampleFile(String key) =>
    File('assets/images/samples/${expectedSample(key)['file']}');

Uint8List samplePhoto(String key) => sampleFile(key).readAsBytesSync();

/// What the real model found on a sample photo, from the recorded fixtures.
ScanResult sampleResult(String key) {
  final sample = expectedSample(key);
  return ScanResult(
    detections: [
      for (final item in sample['detections'] as List<dynamic>)
        Detection.fromJson(item as Map<String, dynamic>),
    ],
    imageWidth: sample['width'] as int,
    imageHeight: sample['height'] as int,
    inferenceMs: 180,
  );
}

/// Stands in for ONNX Runtime: replays an output recorded from the real model.
class ReplayRunner implements ModelRunner {
  ReplayRunner(this.output);

  /// A model that sees nothing on the photo.
  ReplayRunner.blind() : output = Float32List(ModelSpec.outputLength);

  final List<double> output;

  @override
  Future<List<double>> run(Float32List input) async => output;

  @override
  Future<void> close() async {}
}

class BrokenRunner implements ModelRunner {
  @override
  Future<List<double>> run(Float32List input) async =>
      throw const ModelRunnerException('session lost');

  @override
  Future<void> close() async {}
}

/// A detector that answers with the recorded output for sample [key].
DetectionRepository replayDetection(String key) => DetectionRepository(
  runner: ReplayRunner(loadRawOutput(key)),
  preparer: (bytes) async => prepareImageSync(bytes),
);

DetectionRepository detectionWith(ModelRunner runner) => DetectionRepository(
  runner: runner,
  preparer: (bytes) async => prepareImageSync(bytes),
);

/// Hands out the queued answers, one per call.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([List<Object?> answers = const []]) : _answers = [...answers];

  final List<Object?> _answers;
  final List<PhotoSource> requests = [];

  /// Queue a photo (`Uint8List`), a cancel (`null`) or an error to throw.
  void enqueue(Object? answer) => _answers.add(answer);

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    requests.add(source);
    final answer = _answers.isEmpty ? null : _answers.removeAt(0);
    if (answer is Exception) throw answer;
    return answer as Uint8List?;
  }
}

class ScheduledReminder {
  const ScheduledReminder(this.id, this.at, this.title, this.body);

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

class FakeReminderScheduler implements ReminderScheduler {
  /// Flip to `false` to behave like a phone with notifications switched off.
  bool allowed = true;

  final Map<int, ScheduledReminder> scheduled = {};
  final List<int> cancelled = [];

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!allowed) return false;
    scheduled[id] = ScheduledReminder(id, at, title, body);
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class FakeSharer implements ResultSharer {
  String? text;
  File? photo;
  int calls = 0;

  @override
  Future<void> share({required String text, File? photo, Rect? origin}) async {
    calls++;
    this.text = text;
    this.photo = photo;
  }
}

class FakeSettingsOpener implements SettingsOpener {
  int opened = 0;

  @override
  Future<void> openAppSettings() async => opened++;
}
