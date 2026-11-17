import 'dart:io';
import 'dart:typed_data';

import 'package:cek_daun_kopi/data/repositories/history_repository.dart';
import 'package:cek_daun_kopi/domain/models/detection.dart';
import 'package:cek_daun_kopi/domain/models/scan_result.dart';
import 'package:flutter_test/flutter_test.dart';

const _result = ScanResult(
  detections: [
    Detection(
      classId: 'karat_daun',
      confidence: 86.3,
      box: BoundingBox(x1: 469, y1: 593, x2: 566, y2: 701),
    ),
  ],
  imageWidth: 2048,
  imageHeight: 1024,
  inferenceMs: 41.5,
);

final _photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

void main() {
  late Directory directory;
  late DateTime now;

  HistoryRepository open() => HistoryRepository(
    Directory('${directory.path}/history'),
    clock: () => now,
  );

  setUp(() {
    directory = Directory.systemTemp.createTempSync('history_test');
    now = DateTime(2026, 11, 17, 9, 12);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('starts empty', () async {
    expect(await open().all(), isEmpty);
  });

  test(
    'saves a check with its photo and reads it back after a restart',
    () async {
      final saved = await open().add(
        imageBytes: _photo,
        result: _result,
        block: '  Blok A ',
      );

      final reopened = open();
      final entries = await reopened.all();
      expect(entries, hasLength(1));

      final entry = entries.single;
      expect(entry.id, saved.id);
      expect(entry.createdAt, now);
      expect(entry.block, 'Blok A');
      expect(entry.completedSteps, isEmpty);
      expect(entry.reminderAt, isNull);
      expect(entry.result.dominantClassId, 'karat_daun');
      expect(entry.result.topConfidence, 86.3);
      expect(entry.result.detections.single.box, _result.detections.single.box);
      expect(reopened.imageOf(entry).readAsBytesSync(), _photo);
    },
  );

  test('lists the newest check first', () async {
    final repository = open();
    final first = await repository.add(imageBytes: _photo, result: _result);
    now = now.add(const Duration(hours: 3));
    final second = await repository.add(imageBytes: _photo, result: _result);

    expect((await open().all()).map((entry) => entry.id), [
      second.id,
      first.id,
    ]);
  });

  test('gives two checks saved in the same instant different ids', () async {
    final repository = open();
    final first = await repository.add(imageBytes: _photo, result: _result);
    final second = await repository.add(imageBytes: _photo, result: _result);
    expect(first.id, isNot(second.id));
    expect(await repository.all(), hasLength(2));
  });

  test('remembers ticked steps, the block and the reminder', () async {
    final repository = open();
    final saved = await repository.add(imageBytes: _photo, result: _result);
    final reminder = DateTime(2026, 11, 24, 7);

    await repository.update(
      saved.copyWith(
        completedSteps: {0, 2},
        block: () => 'Blok C',
        reminderAt: () => reminder,
      ),
    );

    final entry = (await open().find(saved.id))!;
    expect(entry.completedSteps, {0, 2});
    expect(entry.block, 'Blok C');
    expect(entry.reminderAt, reminder);

    await repository.update(entry.copyWith(reminderAt: () => null));
    expect((await open().find(saved.id))!.reminderAt, isNull);
    expect((await open().find(saved.id))!.block, 'Blok C');
  });

  test('refuses to update a check that was never saved', () async {
    final repository = open();
    final saved = await repository.add(imageBytes: _photo, result: _result);
    await repository.remove(saved.id);
    expect(() => repository.update(saved), throwsStateError);
  });

  test('removes a check together with its photo', () async {
    final repository = open();
    final saved = await repository.add(imageBytes: _photo, result: _result);
    final image = repository.imageOf(saved);
    expect(image.existsSync(), isTrue);

    await repository.remove(saved.id);

    expect(await open().all(), isEmpty);
    expect(image.existsSync(), isFalse);
    await repository.remove('missing'); // no error
  });

  test('lists the block names used so far, most recent first', () async {
    final repository = open();
    await repository.add(imageBytes: _photo, result: _result, block: 'Blok A');
    now = now.add(const Duration(minutes: 1));
    await repository.add(imageBytes: _photo, result: _result, block: '');
    now = now.add(const Duration(minutes: 1));
    await repository.add(imageBytes: _photo, result: _result, block: 'Blok B');
    now = now.add(const Duration(minutes: 1));
    await repository.add(imageBytes: _photo, result: _result, block: 'Blok A');

    expect(await repository.knownBlocks(), ['Blok A', 'Blok B']);
  });

  test('survives a corrupted index instead of crashing on launch', () async {
    final folder = Directory('${directory.path}/history')..createSync();
    File('${folder.path}/history.json').writeAsStringSync('{ not json');

    final repository = open();
    expect(await repository.all(), isEmpty);
    await repository.add(imageBytes: _photo, result: _result);
    expect(await open().all(), hasLength(1));
  });
}
