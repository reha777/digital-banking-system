import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef AccessTokenProvider = String? Function();
typedef SessionRefreshCallback = Future<void> Function();

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AccessTokenProvider? accessTokenProvider,
    SessionRefreshCallback? refreshSession,
  }) : _httpClient = httpClient ?? http.Client(),
       _accessTokenProvider = accessTokenProvider,
       _refreshSession = refreshSession;

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static AccessTokenProvider? _globalAccessTokenProvider;
  static SessionRefreshCallback? _globalRefreshSession;

  static void configureAuth({
    required AccessTokenProvider accessTokenProvider,
    required SessionRefreshCallback refreshSession,
  }) {
    _globalAccessTokenProvider = accessTokenProvider;
    _globalRefreshSession = refreshSession;
  }

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    return kIsWeb ? 'http://localhost:5026' : 'http://10.0.2.2:5026';
  }

  final http.Client _httpClient;
  final AccessTokenProvider? _accessTokenProvider;
  final SessionRefreshCallback? _refreshSession;

  AccessTokenProvider? get _tokenProvider =>
      _accessTokenProvider ?? _globalAccessTokenProvider;
  SessionRefreshCallback? get _refreshCallback =>
      _refreshSession ?? _globalRefreshSession;

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken),
      ),
    );
    final decoded = _decodeMap(response);
    _throwIfFailed(response, decoded);
    return decoded;
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    String? token,
  }) async {
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken),
      ),
    );
    final decoded = response.body.isEmpty ? [] : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded is Map<String, dynamic>
            ? _extractErrorMessage(decoded)
            : 'Zahtjev nije uspjesno obradjen.',
        response.statusCode,
      );
    }
    return decoded is List
        ? decoded.map((item) => item as Map<String, dynamic>).toList()
        : [];
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
    bool allowAuthRefresh = true,
  }) async {
    final encodedBody = jsonEncode(body);
    Future<http.Response> send(String? currentToken) => _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(token: currentToken, json: true),
      body: encodedBody,
    );
    final response = allowAuthRefresh
        ? await _sendWithAuthRetry(token: token, send: send)
        : await send(token);
    final decoded = _decodeMap(response);
    _throwIfFailed(response, decoded);
    return decoded;
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final encodedBody = jsonEncode(body);
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken, json: true),
        body: encodedBody,
      ),
    );
    final decoded = _decodeMap(response);
    _throwIfFailed(response, decoded);
    return decoded;
  }

  Future<Map<String, dynamic>> postMultipartBytes(
    String path, {
    required String fieldName,
    required String fileName,
    required Uint8List bytes,
    String? token,
  }) async {
    Future<http.Response> send(String? currentToken) async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      request.headers.addAll(_headers(token: currentToken));
      request.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
      );
      return http.Response.fromStream(await _httpClient.send(request));
    }

    final response = await _sendWithAuthRetry(token: token, send: send);
    final decoded = _decodeMap(response);
    _throwIfFailed(response, decoded);
    return decoded;
  }

  Future<http.Response> _sendWithAuthRetry({
    required String? token,
    required Future<http.Response> Function(String? token) send,
  }) async {
    final response = await send(token);
    final refresh = _refreshCallback;
    if (response.statusCode != 401 || token == null || refresh == null) {
      return response;
    }

    final currentToken = _tokenProvider?.call();
    if (currentToken != null && currentToken != token) {
      return send(currentToken);
    }

    await refresh();
    final refreshedToken = _tokenProvider?.call();
    if (refreshedToken == null) {
      return response;
    }
    return send(refreshedToken);
  }

  Map<String, String> _headers({String? token, bool json = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _throwIfFailed(http.Response response, Map<String, dynamic> decoded) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }
  }

  String _extractErrorMessage(Map<String, dynamic> decoded) {
    final message = decoded['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    final errors = decoded['errors'];
    if (errors is Map<String, dynamic>) {
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is List) {
          messages.addAll(value.map((item) => item.toString()));
        } else if (value != null) {
          messages.add(value.toString());
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }
    final title = decoded['title']?.toString();
    return title != null && title.isNotEmpty
        ? title
        : 'Zahtjev nije uspjesno obradjen.';
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
