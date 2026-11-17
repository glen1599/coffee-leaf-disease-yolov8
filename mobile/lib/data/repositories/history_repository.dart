import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../domain/models/history_entry.dart';
import '../../domain/models/scan_result.dart';

/// Past checks, stored as plain files inside one folder on the phone:
/// `history.json` with the records and one `<id>.jpg` per photo.
///
/// Nothing here leaves the device.
class HistoryRepository {
  HistoryRepository(this._directory, {this._clock = DateTime.now});

  static const _indexName = 'history.json';

  final Directory _directory;
  final DateTime Function() _clock;
  final _changes = _Changes();
  List<HistoryEntry>? _cache;

  /// Fires after a check was added, changed or deleted.
  Listenable get changes => _changes;

  File get _index => File('${_directory.path}/$_indexName');

  /// The saved photo of [entry].
  File imageOf(HistoryEntry entry) =>
      File('${_directory.path}/${entry.imageFile}');

  /// Every saved check, newest first.
  Future<List<HistoryEntry>> all() async => List.unmodifiable(await _load());

  Future<HistoryEntry?> find(String id) async {
    for (final entry in await _load()) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Save a new check together with its photo.
  Future<HistoryEntry> add({
    required Uint8List imageBytes,
    required ScanResult result,
    String? block,
  }) async {
    final entries = await _load();
    final now = _clock();
    var id = now.microsecondsSinceEpoch.toString();
    while (entries.any((entry) => entry.id == id)) {
      id = '${id}_';
    }
    final entry = HistoryEntry(
      id: id,
      createdAt: now,
      imageFile: '$id.jpg',
      result: result,
      block: _clean(block),
    );

    await _directory.create(recursive: true);
    await imageOf(entry).writeAsBytes(imageBytes, flush: true);
    entries.insert(0, entry);
    // Normally a no-op; keeps "newest first" true even if the phone's clock
    // was set back between two checks.
    entries.sort(_newestFirst);
    await _save(entries);
    return entry;
  }

  /// Replace the stored record that has the same id as [entry].
  Future<void> update(HistoryEntry entry) async {
    final entries = await _load();
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      throw StateError('No history entry with id ${entry.id}');
    }
    entries[index] = entry;
    await _save(entries);
  }

  /// Delete one check and its photo.
  Future<void> remove(String id) async {
    final entries = await _load();
    final index = entries.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final removed = entries.removeAt(index);
    await _save(entries);
    final image = imageOf(removed);
    if (image.existsSync()) await image.delete();
  }

  /// Block names used so far, most recent first, for quick re-use.
  Future<List<String>> knownBlocks() async {
    final seen = <String>{};
    for (final entry in await _load()) {
      final block = entry.block;
      if (block != null) seen.add(block);
    }
    return seen.toList();
  }

  Future<List<HistoryEntry>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final entries = <HistoryEntry>[];
    if (_index.existsSync()) {
      try {
        final decoded = jsonDecode(await _index.readAsString());
        for (final item in decoded as List<dynamic>) {
          entries.add(HistoryEntry.fromJson(item as Map<String, dynamic>));
        }
      } on FormatException {
        // A half-written or foreign file: start clean instead of crashing
        // on launch. The photos stay on disk.
        entries.clear();
      }
    }
    entries.sort(_newestFirst);
    return _cache = entries;
  }

  Future<void> _save(List<HistoryEntry> entries) async {
    await _directory.create(recursive: true);
    // Write next to the index and rename: a crash mid-write then leaves the
    // previous file intact.
    final temporary = File('${_index.path}.tmp');
    await temporary.writeAsString(
      jsonEncode([for (final entry in entries) entry.toJson()]),
      flush: true,
    );
    await temporary.rename(_index.path);
    _cache = entries;
    _changes.fire();
  }

  static int _newestFirst(HistoryEntry a, HistoryEntry b) =>
      b.createdAt.compareTo(a.createdAt);

  static String? _clean(String? block) {
    final trimmed = block?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _Changes extends ChangeNotifier {
  void fire() => notifyListeners();
}
