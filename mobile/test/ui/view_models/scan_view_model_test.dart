import 'dart:io';
import 'dart:typed_data';

import 'package:cek_daun_kopi/data/repositories/detection_repository.dart';
import 'package:cek_daun_kopi/data/repositories/history_repository.dart';
import 'package:cek_daun_kopi/data/services/photo_picker.dart';
import 'package:cek_daun_kopi/ui/features/scan/view_models/scan_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late Directory directory;
  late HistoryRepository history;
  late FakePhotoPicker photos;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('scan_vm_test');
    history = HistoryRepository(Directory('${directory.path}/history'));
    photos = FakePhotoPicker();
  });

  tearDown(() => directory.deleteSync(recursive: true));

  ScanViewModel model(DetectionRepository detection) =>
      ScanViewModel(photos: photos, detection: detection, history: history);

  test('a photo with a diseased leaf is analysed and saved', () async {
    photos.enqueue(samplePhoto('karat_daun'));
    final viewModel = model(replayDetection('karat_daun'));
    final states = <ScanState>[];
    viewModel.addListener(() => states.add(viewModel.state));

    await viewModel.start(PhotoSource.camera);

    expect(photos.requests, [PhotoSource.camera]);
    expect(states.map((state) => state.runtimeType), [
      ScanPicking,
      ScanAnalysing,
      ScanSaved,
    ]);
    final saved = (viewModel.state as ScanSaved).entry;
    expect(saved.result.dominantClassId, 'karat_daun');
    expect(await history.all(), hasLength(1));
    expect(history.imageOf(saved).existsSync(), isTrue);
  });

  test('backing out of the camera changes nothing', () async {
    photos.enqueue(null);
    final viewModel = model(replayDetection('karat_daun'));

    await viewModel.start(PhotoSource.gallery);

    expect(viewModel.state, isA<ScanCancelled>());
    expect(await history.all(), isEmpty);
  });

  test('a refused camera is reported as such', () async {
    photos.enqueue(const CameraAccessDeniedException());
    final viewModel = model(replayDetection('karat_daun'));

    await viewModel.start(PhotoSource.camera);

    expect(
      viewModel.state,
      isA<ScanFailed>().having(
        (state) => state.reason,
        'reason',
        ScanFailure.cameraDenied,
      ),
    );
  });

  test(
    'a picker that fails for another reason is a technical failure',
    () async {
      photos.enqueue(const PhotoPickerException('no camera app'));
      final viewModel = model(replayDetection('karat_daun'));

      await viewModel.start(PhotoSource.camera);

      expect((viewModel.state as ScanFailed).reason, ScanFailure.technical);
    },
  );

  test('a file that is not a photo is not saved', () async {
    photos.enqueue(Uint8List.fromList('not a photo'.codeUnits));
    final viewModel = model(replayDetection('karat_daun'));

    await viewModel.start(PhotoSource.gallery);

    expect((viewModel.state as ScanFailed).reason, ScanFailure.unreadablePhoto);
    expect(await history.all(), isEmpty);
  });

  test('a photo without a coffee leaf is not saved', () async {
    photos.enqueue(samplePhoto('sehat'));
    final viewModel = model(detectionWith(ReplayRunner.blind()));

    await viewModel.start(PhotoSource.camera);

    expect((viewModel.state as ScanFailed).reason, ScanFailure.noLeaf);
    expect(await history.all(), isEmpty);
  });

  test('a model that breaks is a technical failure', () async {
    photos.enqueue(samplePhoto('sehat'));
    final viewModel = model(detectionWith(BrokenRunner()));

    await viewModel.start(PhotoSource.camera);

    expect((viewModel.state as ScanFailed).reason, ScanFailure.technical);
    expect(await history.all(), isEmpty);
  });

  test('a second attempt after a failure can succeed', () async {
    photos
      ..enqueue(const CameraAccessDeniedException())
      ..enqueue(samplePhoto('sehat'));
    final viewModel = model(replayDetection('sehat'));

    await viewModel.start(PhotoSource.camera);
    await viewModel.start(PhotoSource.gallery);

    expect(photos.requests, [PhotoSource.camera, PhotoSource.gallery]);
    expect(
      (viewModel.state as ScanSaved).entry.result.dominantClassId,
      'sehat',
    );
  });
}
