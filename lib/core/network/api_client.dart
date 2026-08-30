import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:rogsheba_mobile/core/config/app_config.dart';
import 'package:rogsheba_mobile/core/l10n/bn_strings.dart';
import 'package:rogsheba_mobile/core/network/api_exception.dart';
import 'package:rogsheba_mobile/core/network/dio_error_mapper.dart';

/// Thin, envelope-aware wrapper around Dio.
///
/// - Decodes the raw UTF-8 body **explicitly** rather than trusting platform
///   defaults (all API payloads are Bangla).
/// - Turns transport failures and the API's `{success, error}` body into an
///   [ApiException] with the Bangla message intact, in one place.
class ApiClient {
  ApiClient(this._dio, this._config);

  final Dio _dio;
  final AppConfig _config;

  /// `/triage` is a slow-but-working request out of the box: the AI upstream
  /// takes 2–6s, so it is allowed up to 30s before giving up.
  Duration get triageTimeout => _config.triageTimeout;

  void _logRequest(String method, String path, Object? data) {
    if (!kDebugMode) return;
    final body = data is Map<String, dynamic> ? jsonEncode(data) : '$data';
    log('API → $method $path', name: 'ApiClient', error: body);
  }

  void _logResponse(String method, String path, int? statusCode, String body) {
    if (!kDebugMode) return;
    final truncated =
        body.length > 500 ? '${body.substring(0, 500)}… (truncated)' : body;
    log(
      'API ← $method $path [$statusCode]',
      name: 'ApiClient',
      error: truncated,
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Object? data, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _config.defaultTimeout;
    _logRequest('POST', path, data);
    try {
      final response = await _dio.post<Uint8List>(
        path,
        data: data,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: effectiveTimeout,
          sendTimeout: effectiveTimeout,
        ),
      );
      final decoded = _decode(response.data, effectiveTimeout);
      _logResponse('POST', path, response.statusCode, jsonEncode(decoded));
      return decoded;
    } on DioException catch (e) {
      _logResponse('POST', path, e.response?.statusCode, e.message ?? '');
      throw mapDioError(e);
    }
  }

  /// `GET` with optional query parameters. `/clinics` uses the default 10s
  /// timeout — it is not a slow-upstream endpoint like `/triage`.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _config.defaultTimeout;
    _logRequest('GET', path, queryParameters);
    try {
      final response = await _dio.get<Uint8List>(
        path,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: effectiveTimeout,
          sendTimeout: effectiveTimeout,
        ),
      );
      final decoded = _decode(response.data, effectiveTimeout);
      _logResponse('GET', path, response.statusCode, jsonEncode(decoded));
      return decoded;
    } on DioException catch (e) {
      _logResponse('GET', path, e.response?.statusCode, e.message ?? '');
      throw mapDioError(e);
    }
  }

  Map<String, dynamic> _decode(Uint8List? bytes, Duration timeout) {
    if (bytes == null) {
      throw const ApiException('empty_response', BnStrings.networkError);
    }
    final String decoded;
    try {
      decoded = utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const ApiException('bad_encoding', BnStrings.genericError);
    }
    return jsonDecode(decoded) as Map<String, dynamic>;
  }
}
