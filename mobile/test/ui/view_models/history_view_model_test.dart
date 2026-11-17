import 'dart:io';

import 'package:cek_daun_kopi/data/repositories/history_repository.dart';
import 'package:cek_daun_kopi/ui/features/history/view_models/history_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late Directory directory;
  late HistoryRepository history;
  late DateTime now;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('history_vm_test');
    now = DateTime(2026, 11, 17, 9, 12);
    history = HistoryRepository(
      Directory('${directory.path}/history'),
      clock: () => now,
    );
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> check(String sample, DateTime at) async {
    final previous = now;
    now = at;
    await history.add(
      imageBytes: samplePhoto(sample),
      result: sampleResult(sample),
    );
    now = previous;
  }

  Future<HistoryViewModel> open() async {
    final viewModel = HistoryViewModel(
      history: history,
      content: loadContent(),
      clock: () => now,
    );
    await viewModel.reload();
    return viewModel;
  }

  test('starts empty', () async {
    final viewModel = await open();

    expect(viewModel.loaded, isTrue);
    expect(viewModel.latest, isNull);
    expect(viewModel.days, isEmpty);
    expect(viewModel.summary.checked, 0);
  });

  test('the summary counts the last seven days by severity', () async {
    await check('karat_daun', DateTime(2026, 11, 17, 9, 12)); // dangerous
    await check('sehat', DateTime(2026, 11, 17, 8, 47)); // healthy
    await check('pengorok_daun', DateTime(2026, 11, 16, 16, 30)); // attention
    await check('bercak_phoma', DateTime(2026, 11, 11, 0, 5)); // day 7: counts
    await check('karat_daun', DateTime(2026, 11, 10, 23, 55)); // day 8: too old

    final summary = (await open()).summary;

    expect(summary.checked, 4);
    expect(summary.dangerous, 2);
    expect(summary.needAttention, 1);
  });

  test('checks are grouped by day, newest first', () async {
    await check('bercak_phoma', DateTime(2026, 11, 16, 10, 5));
    await check('karat_daun', DateTime(2026, 11, 17, 9, 12));
    await check('pengorok_daun', DateTime(2026, 11, 16, 16, 30));
    await check('sehat', DateTime(2026, 11, 17, 8, 47));

    final viewModel = await open();
    final days = viewModel.days;

    expect(days.map((day) => day.date), [
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 16),
    ]);
    expect(
      days.first.entries.map((entry) => viewModel.diseaseOf(entry)!.name),
      ['Karat Daun', 'Daun Sehat'],
    );
    expect(days.last.entries.map((entry) => viewModel.diseaseOf(entry)!.name), [
      'Pengorok Daun',
      'Bercak Phoma',
    ]);
    expect(viewModel.diseaseOf(viewModel.latest!)!.id, 'karat_daun');
  });

  test('follows the repository when a check is added or deleted', () async {
    final viewModel = await open();
    var notified = 0;
    viewModel.addListener(() => notified++);

    await check('sehat', now);
    await pumpEventQueue();
    expect(viewModel.entries, hasLength(1));
    expect(notified, greaterThan(0));

    await history.remove(viewModel.latest!.id);
    await pumpEventQueue();
    expect(viewModel.entries, isEmpty);
  });
}
