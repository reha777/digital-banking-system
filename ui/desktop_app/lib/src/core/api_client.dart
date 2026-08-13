import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5026',
  );

  final http.Client _httpClient = http.Client();

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final headers = <String, String>{'Accept': 'application/json'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_extractErrorMessage(decoded), response.statusCode);
    }

    return decoded;
  }

  Future<Uint8List> getBytes(String path, {String? token}) async {
    final headers = <String, String>{'Accept': '*/*'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
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
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );

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
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
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
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.patch(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
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
    final headers = <String, String>{'Accept': 'application/json'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.delete(
      Uri.parse('$baseUrl$path'),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
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
