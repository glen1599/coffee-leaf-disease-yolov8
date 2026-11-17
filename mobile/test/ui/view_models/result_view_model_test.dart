import 'dart:io';

import 'package:cek_daun_kopi/data/repositories/history_repository.dart';
import 'package:cek_daun_kopi/domain/models/confidence.dart';
import 'package:cek_daun_kopi/domain/models/history_entry.dart';
import 'package:cek_daun_kopi/ui/features/result/view_models/result_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

void main() {
  late Directory directory;
  late DateTime now;
  late FakeReminderScheduler reminders;
  late FakeSharer sharer;

  HistoryRepository openHistory() => HistoryRepository(
    Directory('${directory.path}/history'),
    clock: () => now,
  );

  late HistoryRepository history;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('result_vm_test');
    now = DateTime(2026, 11, 17, 9, 12);
    reminders = FakeReminderScheduler();
    sharer = FakeSharer();
    history = openHistory();
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<HistoryEntry> saved(String sample, {String? block}) => history.add(
    imageBytes: samplePhoto(sample),
    result: sampleResult(sample),
    block: block,
  );

  Future<ResultViewModel> open(HistoryEntry entry) async {
    final viewModel = ResultViewModel(
      entryId: entry.id,
      history: history,
      content: loadContent(),
      reminders: reminders,
      sharer: sharer,
      clock: () => now,
    );
    await pumpEventQueue();
    return viewModel;
  }

  test('describes the saved check in plain words', () async {
    final viewModel = await open(await saved('karat_daun'));

    expect(viewModel.loaded, isTrue);
    expect(viewModel.disease!.name, 'Karat Daun');
    expect(viewModel.confidenceLevel, ConfidenceLevel.high);
    expect(viewModel.confidenceLabel, 'Sangat yakin');
    expect(viewModel.findingCount, 26);
    expect(viewModel.photo!.existsSync(), isTrue);
    expect(viewModel.completedSteps, 0);
    expect(viewModel.reminderAt, isNull);
  });

  test('a healthy leaf has no findings to point at', () async {
    final viewModel = await open(await saved('sehat'));

    expect(viewModel.disease!.id, 'sehat');
    expect(viewModel.findingCount, 0);
  });

  test('a check that no longer exists loads as nothing', () async {
    final entry = await saved('sehat');
    await history.remove(entry.id);

    final viewModel = await open(entry);

    expect(viewModel.loaded, isTrue);
    expect(viewModel.entry, isNull);
  });

  test('ticked steps survive closing the app', () async {
    final entry = await saved('karat_daun');
    final viewModel = await open(entry);

    await viewModel.toggleStep(0);
    await viewModel.toggleStep(2);
    await viewModel.toggleStep(0);

    expect(viewModel.completedSteps, 1);
    final reopened = await openHistory().find(entry.id);
    expect(reopened!.completedSteps, {2});
  });

  test('the garden block is trimmed, remembered and can be cleared', () async {
    await saved('sehat', block: 'Blok B');
    final entry = await saved('karat_daun');
    final viewModel = await open(entry);
    expect(viewModel.knownBlocks, ['Blok B']);

    await viewModel.setBlock('  Blok A ');
    expect(viewModel.entry!.block, 'Blok A');
    expect(viewModel.knownBlocks, containsAll(['Blok A', 'Blok B']));
    expect((await openHistory().find(entry.id))!.block, 'Blok A');

    await viewModel.setBlock('   ');
    expect(viewModel.entry!.block, isNull);
  });

  test('a reminder is set for seven in the morning, days later', () async {
    final entry = await saved('karat_daun', block: 'Blok A');
    final viewModel = await open(entry);

    await viewModel.chooseReminder(7);

    final at = DateTime(2026, 11, 24, 7);
    expect(viewModel.reminderDays, 7);
    expect(viewModel.reminderAt, at);
    expect(viewModel.notificationsBlocked, isFalse);
    final scheduled = reminders.scheduled[reminderIdFor(entry)]!;
    expect(scheduled.at, at);
    expect(scheduled.body, contains('Blok A'));
    expect(scheduled.body, contains('Karat Daun'));
    final reopened = await openHistory().find(entry.id);
    expect(reopened!.reminderAt, at);
    expect(reopened.reminderDays, 7);
  });

  test(
    'another option replaces the reminder, the same one removes it',
    () async {
      final entry = await saved('karat_daun');
      final viewModel = await open(entry);

      await viewModel.chooseReminder(3);
      await viewModel.chooseReminder(14);
      expect(viewModel.reminderDays, 14);
      expect(reminders.scheduled.values.single.at, DateTime(2026, 12, 1, 7));

      await viewModel.chooseReminder(14);
      expect(viewModel.reminderDays, isNull);
      expect(viewModel.reminderAt, isNull);
      expect(reminders.scheduled, isEmpty);
      expect((await openHistory().find(entry.id))!.reminderAt, isNull);
    },
  );

  test('nothing is promised when notifications are switched off', () async {
    reminders.allowed = false;
    final entry = await saved('karat_daun');
    final viewModel = await open(entry);

    await viewModel.chooseReminder(3);

    expect(viewModel.notificationsBlocked, isTrue);
    expect(viewModel.reminderAt, isNull);
    expect((await openHistory().find(entry.id))!.reminderAt, isNull);

    reminders.allowed = true;
    await viewModel.chooseReminder(3);
    expect(viewModel.notificationsBlocked, isFalse);
    expect(viewModel.reminderDays, 3);
  });

  test('a reminder that already fired is no longer shown as active', () async {
    final entry = await saved('karat_daun');
    final viewModel = await open(entry);
    await viewModel.chooseReminder(3);

    now = DateTime(2026, 11, 20, 7, 1);

    expect(viewModel.reminderAt, isNull);
    expect(viewModel.reminderDays, isNull);
  });

  test('sharing sends the words and the photo', () async {
    final entry = await saved('karat_daun', block: 'Blok A');
    final viewModel = await open(entry);

    await viewModel.share();

    expect(sharer.calls, 1);
    expect(sharer.photo!.path, history.imageOf(entry).path);
    expect(sharer.text, contains('Karat Daun (Berbahaya)'));
    expect(sharer.text, contains('Lokasi di kebun: Blok A'));
  });

  test('deleting removes the check, its photo and its reminder', () async {
    final entry = await saved('karat_daun');
    final viewModel = await open(entry);
    await viewModel.chooseReminder(7);
    final photo = history.imageOf(entry);

    await viewModel.delete();

    expect(viewModel.entry, isNull);
    expect(await history.all(), isEmpty);
    expect(photo.existsSync(), isFalse);
    expect(reminders.cancelled, [reminderIdFor(entry)]);
  });
}
