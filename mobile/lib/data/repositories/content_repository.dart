import 'dart:convert';

import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../domain/models/content_bundle.dart';

/// The knowledge base that ships inside the app, so it works offline.
class ContentRepository {
  ContentRepository({AssetBundle? assets}) : _assets = assets ?? rootBundle;

  final AssetBundle _assets;

  Future<ContentBundle> load() async {
    final text = await _assets.loadString(AppConfig.contentAsset);
    return ContentBundle.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}
