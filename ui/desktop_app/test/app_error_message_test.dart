import 'dart:async';
import 'dart:io';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/core/app_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps safe error categories without exposing technical details', () {
    expect(
      AppErrorMessage.from(ApiException('expired', 401)),
      contains('session'),
    );
    expect(AppErrorMessage.from(ApiException('Bad value', 400)), 'Bad value');
    expect(
      AppErrorMessage.from(ApiException('missing', 404)),
      contains('not be found'),
    );
    expect(
      AppErrorMessage.from(ApiException('SQL Exception at URL', 500)),
      isNot(contains('SQL')),
    );
    expect(
      AppErrorMessage.from(const SocketException('host https://secret')),
      'Unable to connect to the server.',
    );
    expect(
      AppErrorMessage.from(TimeoutException('stack')),
      'The server request timed out.',
    );
    expect(
      AppErrorMessage.from(Exception('https://secret')),
      isNot(contains('Exception')),
    );
    expect(
      AppErrorMessage.from(Exception('https://secret')),
      isNot(contains('https://')),
    );
  });
}
