import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/history_repository.dart';
import '../../../../domain/models/content_bundle.dart';
import '../../../../domain/models/disease.dart';
import '../../../../domain/models/history_entry.dart';
import '../../../core/format/id_format.dart';

/// What the last seven days looked like, in three numbers.
class WeekSummary {
  const WeekSummary({
    required this.checked,
    required this.dangerous,
    required this.needAttention,
  });

  final int checked;
  final int dangerous;
  final int needAttention;
}

/// The checks of one calendar day.
class HistoryDay {
  const HistoryDay({required this.date, required this.entries});

  final DateTime date;
  final List<HistoryEntry> entries;
}

/// The saved checks, kept in step with the repository.
///
/// Beranda (latest check) and Riwayat (everything) share one instance.
class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel({
    required this._history,
    required this._content,
    this._clock = DateTime.now,
  }) {
    _history.changes.addListener(reload);
    reload();
  }

  static const summaryDays = 7;

  final HistoryRepository _history;
  final ContentBundle _content;
  final DateTime Function() _clock;

  bool _disposed = false;

  bool _loaded = false;
  bool get loaded => _loaded;

  List<HistoryEntry> _entries = const [];
  List<HistoryEntry> get entries => _entries;

  HistoryEntry? get latest => _entries.isEmpty ? null : _entries.first;

  DateTime get now => _clock();

  Disease? diseaseOf(HistoryEntry entry) =>
      _content.diseaseFor(entry.result.dominantClassId);

  File imageOf(HistoryEntry entry) => _history.imageOf(entry);

  /// Counts for today and the six days before it.
  WeekSummary get summary {
    final today = now;
    var checked = 0;
    var dangerous = 0;
    var needAttention = 0;
    for (final entry in _entries) {
      final age = calendarDaysBetween(entry.createdAt, today);
      if (age < 0 || age >= summaryDays) continue;
      checked++;
      switch (diseaseOf(entry)?.severity) {
        case Severity.high:
          dangerous++;
        case Severity.moderate:
          needAttention++;
        case Severity.none || null:
          break;
      }
    }
    return WeekSummary(
      checked: checked,
      dangerous: dangerous,
      needAttention: needAttention,
    );
  }

  /// Entries grouped by day, newest day first.
  List<HistoryDay> get days {
    final days = <HistoryDay>[];
    for (final entry in _entries) {
      final at = entry.createdAt;
      final date = DateTime(at.year, at.month, at.day);
      if (days.isNotEmpty && days.last.date == date) {
        days.last.entries.add(entry);
      } else {
        days.add(HistoryDay(date: date, entries: [entry]));
      }
    }
    return days;
  }

  Future<void> reload() async {
    final entries = await _history.all();
    if (_disposed) return;
    _entries = entries;
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _history.changes.removeListener(reload);
    super.dispose();
  }
}
