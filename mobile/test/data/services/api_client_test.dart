import 'dart:convert';
import 'dart:io';

import 'package:cek_daun_kopi/data/services/api_client.dart';
import 'package:cek_daun_kopi/domain/models/disease.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

const _rust = {
  'id': 'karat_daun',
  'name': 'Karat Daun',
  'status': 'Patogen terdeteksi',
  'severity': 'high',
  'severity_label': 'Berbahaya',
  'pathogen': 'Hemileia vastatrix (jamur)',
  'summary': 'Infeksi karat yang ganas.',
  'symptoms': ['Bintil bertepung kuning-jingga di sisi bawah daun'],
  'treatment': ['Jarangkan tajuk.'],
  'sample_image':
      'https://example.test/static/img/samples/coffee_leaf_rust.jpg',
};

void main() {
  test('fetches the knowledge base in the requested language', () async {
    late Uri requested;
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((request) async {
        requested = request.url;
        return _json({
          'language': 'id',
          'count': 1,
          'diseases': [_rust],
          'metrics': {'precision': 96.99, 'recall': 96.59},
          'disclaimer': 'Saran ini bersifat umum.',
        });
      }),
    );

    final catalog = await client.fetchDiseases();

    expect(
      requested.toString(),
      'https://example.test/api/v1/diseases?lang=id',
    );
    expect(catalog.language, 'id');
    expect(catalog.diseases.single.name, 'Karat Daun');
    expect(catalog.diseases.single.severity, Severity.high);
    expect(catalog.metrics['precision'], 96.99);
    expect(catalog.disclaimer, isNotEmpty);
  });

  test('keeps a path prefix in the base URL', () async {
    late Uri requested;
    final client = ApiClient(
      baseUrl: 'https://example.test/kopi',
      httpClient: MockClient((request) async {
        requested = request.url;
        return _json({
          'status': 'ok',
          'model': {'using_fallback_weights': false},
        });
      }),
    );
    await client.isHealthy();
    expect(requested.path, '/kopi/api/v1/health');
  });

  test('reports a server on fallback weights as unhealthy', () async {
    ApiClient withModel(Map<String, Object?> model) => ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => _json({'status': 'ok', 'model': model}),
      ),
    );

    expect(
      await withModel({'using_fallback_weights': false}).isHealthy(),
      isTrue,
    );
    expect(
      await withModel({'using_fallback_weights': true}).isHealthy(),
      isFalse,
    );
  });

  test('turns an API error body into an ApiException', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => _json({
          'error': {
            'code': 'rate_limited',
            'message':
                'Terlalu banyak permintaan. Tunggu sebentar, lalu coba lagi.',
          },
        }, 429),
      ),
    );

    expect(
      client.fetchDiseases,
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.code, 'code', 'rate_limited')
            .having((e) => e.message, 'message', startsWith('Terlalu banyak')),
      ),
    );
  });

  test('copes with the plain-string errors of the web routes', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((_) async => _json({'error': 'Not found.'}, 404)),
    );
    expect(
      client.fetchDiseases,
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'Not found.'),
      ),
    );
  });

  test('treats an HTML answer as an invalid response', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => http.Response('<html>Space is sleeping</html>', 503),
      ),
    );
    expect(
      client.isHealthy,
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_response'),
      ),
    );
  });

  test('reports an unreachable server as a network problem', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient(
        (_) async => throw const SocketException('Failed host lookup'),
      ),
    );
    expect(client.isHealthy, throwsA(isA<NetworkException>()));
  });

  test('gives up on a server that never answers', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test',
      timeout: const Duration(milliseconds: 20),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json({'status': 'ok'});
      }),
    );
    expect(client.isHealthy, throwsA(isA<NetworkException>()));
  });
}
