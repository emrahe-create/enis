import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../storage/token_storage.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isNetworkFailure => statusCode == null;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.tokenStorage,
    http.Client? httpClient,
    String? baseUrl,
  })  : baseUrl = _resolveBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client();

  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  final String baseUrl;
  final TokenStorage tokenStorage;
  final http.Client _httpClient;

  static String _resolveBaseUrl(String? explicitBaseUrl) {
    final explicit = explicitBaseUrl?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return _stripTrailingSlash(explicit);
    }

    final defined = _definedBaseUrl.trim();
    if (defined.isNotEmpty) {
      return _stripTrailingSlash(defined);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000';
    }

    return 'http://localhost:4000';
  }

  static String _stripTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<Map<String, dynamic>> getJson(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body}) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> patchJson(String path,
      {Map<String, dynamic>? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> deleteJson(String path) {
    return _send('DELETE', path);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await tokenStorage.readToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      response = await _request(method, uri, headers, body);
    } catch (_) {
      throw const ApiException('API kullanılamıyor');
    }

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'İstek tamamlanamadı',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic>? body,
  ) {
    final encodedBody = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return _httpClient.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers);
      default:
        throw UnsupportedError('Unsupported method $method');
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {'data': decoded};
  }
}
