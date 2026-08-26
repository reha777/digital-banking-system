import 'dart:async';
import 'dart:io';

import 'api_client.dart';

abstract final class AppErrorMessage {
  static String from(Object error, {String? fallback}) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 || 403 => 'Your session has expired. Please sign in again.',
        404 => 'The requested information could not be found.',
        >= 400 && < 500 =>
          _safeBusinessMessage(error.message) ??
              'Invalid value. Please check the form.',
        >= 500 => fallback ?? 'The server could not complete the request.',
        _ => fallback ?? 'The request could not be completed.',
      };
    }
    if (error is TimeoutException) return 'The server request timed out.';
    if (error is SocketException || error is HttpException) {
      return 'Unable to connect to the server.';
    }
    return fallback ?? 'Something went wrong. Please try again.';
  }

  static String? _safeBusinessMessage(String value) {
    final message = value.trim();
    if (message.isEmpty ||
        message.length > 300 ||
        message.contains('http://') ||
        message.contains('https://') ||
        message.contains('Exception') ||
        message.contains(' at ')) {
      return null;
    }
    return message;
  }
}
