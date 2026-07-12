import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    return kIsWeb ? 'http://localhost:5026' : 'http://10.0.2.2:5026';
  }

  final http.Client _httpClient = http.Client();

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

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
      throw ApiException(
        _extractErrorMessage(decoded),
        response.statusCode,
      );
    }

    return decoded;
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    String? token,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await _httpClient.get(
      Uri.parse('$baseUrl$path'),
      headers: headers,
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

    if (decoded is List) {
      return decoded
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }

    return [];
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
      throw ApiException(
        _extractErrorMessage(decoded),
        response.statusCode,
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> postMultipartBytes(
    String path, {
    required String fieldName,
    required String fileName,
    required Uint8List bytes,
    String? token,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers['Accept'] = 'application/json';

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
      ),
    );

    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(decoded),
        response.statusCode,
      );
    }

    return decoded;
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
    if (title != null && title.isNotEmpty) {
      return title;
    }

    return 'Zahtjev nije uspjesno obradjen.';
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
