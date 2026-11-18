import 'dart:convert';
import 'dart:io';

import 'package:cek_daun_kopi/data/repositories/content_repository.dart';
import 'package:cek_daun_kopi/data/services/api_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Serves the real bundled file, as the app would read it.
class _DiskAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

Map<String, dynamic> _bundledJson() =>
    jsonDecode(File('assets/content/diseases.json').readAsStringSync())
        as Map<String, dynamic>;

/// What `GET /api/v1/diseases` would answer, from the same content.
Map<String, dynamic> _serverAnswer({
  String Function(String name)? rename,
  bool dropOne = false,
}) {
  final json = _bundledJson();
  final diseases = [
    for (final item
        in (json['diseases'] as Map<String, dynamic>)['id'] as List<dynamic>)
      {
        ...item as Map<String, dynamic>,
        'name': rename == null ? item['name'] : rename(item['name'] as String),
      },
  ];
  return {
    'language': 'id',
    'count': diseases.length,
    'diseases': dropOne ? diseases.skip(1).toList() : diseases,
    'metrics': json['metrics'],
    'disclaimer': 'Teks penafian yang baru.',
  };
}

ApiClient _api(http.Response Function() answer) => ApiClient(
  baseUrl: 'https://example.test',
  httpClient: MockClient((request) async => answer()),
);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync('content_test'));
  tearDown(() => directory.deleteSync(recursive: true));

  ContentRepository repository([ApiClient? api]) => ContentRepository(
    assets: _DiskAssets(),
    cacheDirectory: directory,
    api: api,
  );

  test('without a server the bundled text is used', () async {
    final content = await repository().load();

    expect(content.diseaseFor('karat_daun')!.name, 'Karat Daun');
    expect(await repository().refresh(), isFalse);
  });

  test('a refresh is stored and used from the next launch on', () async {
    final api = _api(() => _json(_serverAnswer(rename: (name) => '$name*')));

    expect(await repository(api).refresh(), isTrue);
    final content = await repository().load();

    expect(content.diseaseFor('karat_daun')!.name, 'Karat Daun*');
    expect(content.disclaimer, 'Teks penafian yang baru.');
    // Wording that the API does not carry stays as bundled.
    expect(content.confidenceLabelFor(90), 'Sangat yakin');
  });

  test('no connection keeps whatever was there', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (request) async => throw const SocketException('offline'),
      ),
    );

    expect(await repository(api).refresh(), isFalse);
    expect(
      (await repository().load()).disclaimer,
      isNot('Teks penafian yang baru.'),
    );
  });

  test('a server error keeps whatever was there', () async {
    final api = _api(
      () => _json({
        'error': {'code': 'rate_limited', 'message': 'Tunggu sebentar.'},
      }, 429),
    );

    expect(await repository(api).refresh(), isFalse);
  });

  test('text for other classes than the model knows is refused', () async {
    final api = _api(() => _json(_serverAnswer(dropOne: true)));

    expect(await repository(api).refresh(), isFalse);
    expect(File('${directory.path}/diseases.json').existsSync(), isFalse);
  });

  test('a damaged stored copy falls back to the bundled text', () async {
    File('${directory.path}/diseases.json').writeAsStringSync('{"lang');

    final content = await repository().load();

    expect(content.diseaseFor('sehat')!.name, 'Daun Sehat');
  });
}
