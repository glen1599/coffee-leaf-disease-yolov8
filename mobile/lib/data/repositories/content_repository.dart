import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../domain/models/content_bundle.dart';
import '../../domain/models/disease.dart';
import '../services/api_client.dart';

/// The knowledge base: shipped inside the app so it works offline, and
/// refreshed from the server whenever a connection happens to be there.
///
/// A refresh is stored and used from the next launch on. Changing the text
/// under a farmer who is reading it would be more confusing than helpful.
class ContentRepository {
  ContentRepository({AssetBundle? assets, this._cacheDirectory, this._api})
    : _assets = assets ?? rootBundle;

  static const _cacheName = 'diseases.json';

  final AssetBundle _assets;
  final Directory? _cacheDirectory;
  final ApiClient? _api;

  File? get _cache {
    final directory = _cacheDirectory;
    return directory == null ? null : File('${directory.path}/$_cacheName');
  }

  /// The bundled content, with the last downloaded text on top of it.
  Future<ContentBundle> load() async {
    final bundled = await _bundled();
    final cache = _cache;
    if (cache == null || !cache.existsSync()) return bundled;
    try {
      final json =
          jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
      if (json['language'] != bundled.language) return bundled;
      final diseases = [
        for (final item in json['diseases'] as List<dynamic>)
          Disease.fromJson(item as Map<String, dynamic>),
      ];
      if (!_sameClasses(bundled, diseases)) return bundled;
      return bundled.withText(
        diseases: diseases,
        metrics: {
          for (final entry in (json['metrics'] as Map<String, dynamic>).entries)
            entry.key: (entry.value as num).toDouble(),
        },
        disclaimer: json['disclaimer'] as String,
      );
    } on Object {
      // A damaged copy is never worse than the text inside the app.
      return bundled;
    }
  }

  /// Download the current text and keep it for the next launch.
  ///
  /// Returns `false` without a server, without a connection, or when the
  /// server describes other classes than the model inside this app.
  Future<bool> refresh() async {
    final api = _api;
    final cache = _cache;
    if (api == null || cache == null) return false;
    final bundled = await _bundled();
    final DiseaseCatalog catalog;
    try {
      catalog = await api.fetchDiseases(language: bundled.language);
    } on NetworkException {
      return false;
    } on ApiException {
      return false;
    }
    if (catalog.language != bundled.language ||
        !_sameClasses(bundled, catalog.diseases)) {
      return false;
    }
    await cache.parent.create(recursive: true);
    final temporary = File('${cache.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'language': catalog.language,
        'diseases': [for (final disease in catalog.diseases) disease.toJson()],
        'metrics': catalog.metrics,
        'disclaimer': catalog.disclaimer,
      }),
      flush: true,
    );
    await temporary.rename(cache.path);
    return true;
  }

  Future<ContentBundle> _bundled() async {
    final text = await _assets.loadString(AppConfig.contentAsset);
    return ContentBundle.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }

  /// The model inside the app decides which classes exist; text for any
  /// other set of classes does not belong to it.
  static bool _sameClasses(ContentBundle bundled, List<Disease> diseases) {
    final known = {for (final disease in bundled.diseases) disease.id};
    final offered = {for (final disease in diseases) disease.id};
    return offered.length == diseases.length &&
        known.length == offered.length &&
        known.containsAll(offered);
  }
}
