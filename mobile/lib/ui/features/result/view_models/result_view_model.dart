import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/history_repository.dart';
import '../../../../data/services/reminder_scheduler.dart';
import '../../../../data/services/result_sharer.dart';
import '../../../../domain/models/confidence.dart';
import '../../../../domain/models/content_bundle.dart';
import '../../../../domain/models/detection.dart';
import '../../../../domain/models/disease.dart';
import '../../../../domain/models/history_entry.dart';
import '../../../core/format/id_format.dart';
import 'share_text.dart';

/// One saved check, with everything the farmer can do to it: tick off the
/// treatment steps, note the garden block, set a reminder, share, delete.
class ResultViewModel extends ChangeNotifier {
  ResultViewModel({
    required this.entryId,
    required this._history,
    required this._content,
    required this._reminders,
    required this._sharer,
    this._clock = DateTime.now,
  }) {
    _load();
  }

  /// In how many days the farmer can ask to be reminded.
  static const reminderOptions = [3, 7, 14];

  final String entryId;
  final HistoryRepository _history;
  final ContentBundle _content;
  final ReminderScheduler _reminders;
  final ResultSharer _sharer;
  final DateTime Function() _clock;

  bool _disposed = false;

  bool _loaded = false;
  bool get loaded => _loaded;

  HistoryEntry? _entry;

  /// `null` while loading and after the check was deleted.
  HistoryEntry? get entry => _entry;

  List<String> _knownBlocks = const [];

  /// Block names used before, offered as shortcuts.
  List<String> get knownBlocks => _knownBlocks;

  bool _notificationsBlocked = false;

  /// The last reminder could not be set: notifications are not allowed.
  bool get notificationsBlocked => _notificationsBlocked;

  DateTime get now => _clock();

  Disease? get disease => _content.diseaseFor(_entry?.result.dominantClassId);

  String get disclaimer => _content.disclaimer;

  File? get photo {
    final entry = _entry;
    return entry == null ? null : _history.imageOf(entry);
  }

  double get confidence => _entry?.result.topConfidence ?? 0;

  ConfidenceLevel get confidenceLevel =>
      _content.confidenceBands.levelFor(confidence);

  String get confidenceLabel => _content.confidenceLabelFor(confidence);

  Severity severityOf(Detection detection) =>
      _content.diseaseFor(detection.classId)?.severity ?? Severity.high;

  /// How many marks on the photo point at a problem, not at a healthy leaf.
  int get findingCount {
    final detections = _entry?.result.detections ?? const <Detection>[];
    return detections
        .where((detection) => severityOf(detection) != Severity.none)
        .length;
  }

  int get completedSteps {
    final total = disease?.treatment.length ?? 0;
    return _entry?.completedSteps.where((step) => step < total).length ?? 0;
  }

  /// The reminder that is still ahead, if any.
  DateTime? get reminderAt {
    final at = _entry?.reminderAt;
    return at != null && at.isAfter(now) ? at : null;
  }

  /// Which of [reminderOptions] is active.
  int? get reminderDays => reminderAt == null ? null : _entry?.reminderDays;

  Future<void> _load() async {
    final entry = await _history.find(entryId);
    final blocks = await _history.knownBlocks();
    if (_disposed) return;
    _entry = entry;
    _knownBlocks = blocks;
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggleStep(int index) async {
    final entry = _entry;
    if (entry == null) return;
    final steps = {...entry.completedSteps};
    if (!steps.remove(index)) steps.add(index);
    await _store(entry.copyWith(completedSteps: steps));
  }

  Future<void> setBlock(String? name) async {
    final entry = _entry;
    if (entry == null) return;
    final trimmed = name?.trim() ?? '';
    await _store(entry.copyWith(block: () => trimmed.isEmpty ? null : trimmed));
    final blocks = await _history.knownBlocks();
    if (_disposed) return;
    _knownBlocks = blocks;
    notifyListeners();
  }

  /// Set a reminder [days] days from today; picking the active option again
  /// switches it off.
  Future<void> chooseReminder(int days) async {
    final entry = _entry;
    final disease = this.disease;
    if (entry == null || disease == null) return;
    final id = reminderIdFor(entry);

    if (reminderDays == days) {
      await _reminders.cancel(id);
      await _store(
        entry.copyWith(reminderAt: () => null, reminderDays: () => null),
      );
      return;
    }

    final at = reminderMoment(now, days);
    final block = entry.block;
    final allowed = await _reminders.schedule(
      id: id,
      at: at,
      title: 'Waktunya periksa daun kopi lagi',
      body: block == null
          ? 'Terakhir: ${disease.name}. Foto lagi daunnya untuk melihat '
                'perkembangannya.'
          : 'Terakhir di $block: ${disease.name}. Foto lagi daunnya untuk '
                'melihat perkembangannya.',
    );
    _notificationsBlocked = !allowed;
    if (!allowed) {
      if (!_disposed) notifyListeners();
      return;
    }
    await _store(
      entry.copyWith(reminderAt: () => at, reminderDays: () => days),
    );
  }

  Future<void> share({Rect? origin}) async {
    final entry = _entry;
    final disease = this.disease;
    if (entry == null || disease == null) return;
    await _sharer.share(
      text: buildShareText(
        entry: entry,
        disease: disease,
        content: _content,
        now: now,
      ),
      photo: _history.imageOf(entry),
      origin: origin,
    );
  }

  Future<void> delete() async {
    final entry = _entry;
    if (entry == null) return;
    if (entry.reminderAt != null) await _reminders.cancel(reminderIdFor(entry));
    await _history.remove(entry.id);
    if (_disposed) return;
    _entry = null;
    notifyListeners();
  }

  Future<void> _store(HistoryEntry updated) async {
    await _history.update(updated);
    if (_disposed) return;
    _entry = updated;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Notification id of the reminder that belongs to [entry].
///
/// Android wants a 32-bit integer; the creation time folds into one.
int reminderIdFor(HistoryEntry entry) =>
    entry.createdAt.microsecondsSinceEpoch % 0x7fffffff;
