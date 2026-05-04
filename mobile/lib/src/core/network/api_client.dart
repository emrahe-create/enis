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
  static const productionBaseUrl = 'https://api.enisapp.com';

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

    return productionBaseUrl;
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
    _log('API_REQUEST $method $uri');
    final token = await tokenStorage.readToken();
    final tokenExists = token != null && token.isNotEmpty;
    final isChatMessage = path == '/api/chat/message';
    if (isChatMessage) {
      _log('CHAT_API_URL $uri');
      _log('CHAT_TOKEN_EXISTS $tokenExists');
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (tokenExists) 'Authorization': 'Bearer $token',
    };

    late http.Response response;
    try {
      response = await _request(method, uri, headers, body);
    } catch (error) {
      _log('API_NETWORK_ERROR $method $uri $error');
      throw const ApiException('API kullanılamıyor');
    }

    _log('API_RESPONSE $method $uri statusCode=${response.statusCode}');
    if (isChatMessage) {
      _log('CHAT_RESPONSE_STATUS ${response.statusCode}');
      _log('CHAT_RESPONSE_BODY ${response.body}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log('API_ERROR_BODY $method $uri ${response.body}');
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
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    } catch (_) {
      return {'raw': body};
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  void logDebug(String message) => _log(message);
}
