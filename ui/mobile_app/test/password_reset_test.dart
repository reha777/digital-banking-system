import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/core/theme_controller.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/auth/login_screen.dart';
import 'package:mobile_app/src/features/auth/password_reset_service.dart';

void main() {
  testWidgets('login exposes forgot and reset password flow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          session: AuthSession(ApiClient()),
          themeController: ThemeController(),
        ),
      ),
    );
    final loginFields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(loginFields[0].controller!.text, isEmpty);
    expect(loginFields[1].controller!.text, isEmpty);
    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Send reset instructions'), findsOneWidget);
  });

  test('mobile demo forgot sends delivery email and Customer context', () async {
    late Uri requestUri;
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      requestUri = request.url;
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'message':
              'If an account exists for this email, password reset instructions have been sent.',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await PasswordResetService(
      ApiClient(httpClient: client),
    ).forgot('professor@example.com', demoClientType: 'Customer');

    expect(requestUri.path, '/api/auth/demo/forgot-password');
    expect(requestBody, {
      'email': 'professor@example.com',
      'clientType': 'Customer',
    });
    expect(requestBody.containsKey('userId'), isFalse);
  });
}
