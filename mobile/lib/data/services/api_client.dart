import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models/disease.dart';

/// The server answered with an error in the `/api/v1` format.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;

  /// Stable machine-readable code, for example `rate_limited`.
  final String code;

  /// Human-readable text, already in the requested language.
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// The server could not be reached at all (no signal, timeout, DNS).
class NetworkException implements Exception {
  const NetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'NetworkException: $cause';
}

/// What `GET /api/v1/diseases` returns.
class DiseaseCatalog {
  const DiseaseCatalog({
    required this.language,
    required this.diseases,
    required this.metrics,
    required this.disclaimer,
  });

  final String language;
  final List<Disease> diseases;
  final Map<String, double> metrics;
  final String disclaimer;
}

/// Thin wrapper around the Flask `/api/v1` endpoints.
///
/// Detection itself runs on the phone; this client only refreshes the
/// knowledge base when a connection is available.
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _http = httpClient ?? http.Client();

  final Uri _base;
  final http.Client _http;
  final Duration timeout;

  /// `true` when the server is up and serving the trained model.
  Future<bool> isHealthy() async {
    final body = await _get('api/v1/health');
    final model = body['model'] as Map<String, dynamic>? ?? const {};
    return body['status'] == 'ok' && model['using_fallback_weights'] != true;
  }

  Future<DiseaseCatalog> fetchDiseases({String language = 'id'}) async {
    final body = await _get('api/v1/diseases', {'lang': language});
    return DiseaseCatalog(
      language: body['language'] as String,
      diseases: [
        for (final item in body['diseases'] as List<dynamic>)
          Disease.fromJson(item as Map<String, dynamic>),
      ],
      metrics: {
        for (final entry in (body['metrics'] as Map<String, dynamic>).entries)
          entry.key: (entry.value as num).toDouble(),
      },
      disclaimer: body['disclaimer'] as String,
    );
  }

  void close() => _http.close();

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = _base.resolve(path).replace(queryParameters: query);
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw NetworkException(error);
    } on SocketException catch (error) {
      throw NetworkException(error);
    } on http.ClientException catch (error) {
      throw NetworkException(error);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      // A proxy or a sleeping host answered with HTML instead of the API.
      throw ApiException(
        statusCode: response.statusCode,
        code: 'invalid_response',
        message: 'The server did not answer with JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'invalid_response',
        message: 'The server answered with an unexpected JSON shape.',
      );
    }
    if (response.statusCode >= 400) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        throw ApiException(
          statusCode: response.statusCode,
          code: error['code'] as String? ?? 'unknown',
          message: error['message'] as String? ?? '',
        );
      }
      throw ApiException(
        statusCode: response.statusCode,
        code: 'unknown',
        message: error?.toString() ?? '',
      );
    }
    return decoded;
  }
}
