import 'dart:convert';
import 'dart:io';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5026',
  );

  final HttpClient _httpClient = HttpClient();

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final request = await _httpClient.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    final decoded = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

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
