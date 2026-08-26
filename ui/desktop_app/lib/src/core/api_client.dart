import 'dart:convert';
import 'dart:typed_data';

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

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5026',
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

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }

    return decoded;
  }

  Future<List<dynamic>> getJsonList(String path, {String? token}) async {
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Unable to load reference data.', response.statusCode);
    }
    return response.body.isEmpty
        ? const []
        : jsonDecode(response.body) as List<dynamic>;
  }

  Future<Uint8List> getBytes(String path, {String? token}) async {
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.get(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken, accept: '*/*'),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }

    return response.bodyBytes;
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

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }

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

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }

    return decoded;
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final encodedBody = jsonEncode(body);
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken, json: true),
        body: encodedBody,
      ),
    );

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }

    return decoded;
  }

  Future<void> delete(String path, {String? token}) async {
    final response = await _sendWithAuthRetry(
      token: token,
      send: (currentToken) => _httpClient.delete(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token: currentToken),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }
  }

  Future<Map<String, dynamic>> postMultipart(
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
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }
    return decoded;
  }

  Future<http.Response> _sendWithAuthRetry({
    required String? token,
    required Future<http.Response> Function(String? token) send,
  }) async {
    final initialToken = _tokenProvider?.call() ?? token;
    final response = await send(initialToken);
    final refresh = _refreshCallback;
    if (response.statusCode != 401 || initialToken == null || refresh == null) {
      return response;
    }
    final currentToken = _tokenProvider?.call();
    if (currentToken != null && currentToken != initialToken) {
      return send(currentToken);
    }
    await refresh();
    final refreshedToken = _tokenProvider?.call();
    if (refreshedToken == null) return response;
    return send(refreshedToken);
  }

  Map<String, String> _headers({
    String? token,
    bool json = false,
    String accept = 'application/json',
  }) {
    final headers = <String, String>{'Accept': accept};
    if (json) headers['Content-Type'] = 'application/json';
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
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

    return decoded['title']?.toString() ?? 'Zahtjev nije uspjesno obradjen.';
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
