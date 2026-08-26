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
    expect(find.text('Mobile Customer 1'), findsOneWidget);
    await tester.tap(find.text('Mobile Customer 1'));
    await tester.pumpAndSettle();
    expect(find.text('Mobile Customer 2'), findsOneWidget);
  });

  test('mobile demo forgot sends delivery email and selected account', () async {
    late Uri requestUri;
    final requestBodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      requestUri = request.url;
      requestBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'message':
              'If an account exists for this email, password reset instructions have been sent.',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = PasswordResetService(ApiClient(httpClient: client));
    await service.forgot(
      'professor@example.com',
      demoAccount: 'customer-primary',
    );
    await service.forgot(
      'professor@example.com',
      demoAccount: 'customer-secondary',
    );

    expect(requestUri.path, '/api/auth/demo/forgot-password');
    expect(requestBodies[0], {
      'email': 'professor@example.com',
      'demoAccount': 'customer-primary',
    });
    expect(requestBodies[1], {
      'email': 'professor@example.com',
      'demoAccount': 'customer-secondary',
    });
    expect(requestBodies.every((body) => !body.containsKey('userId')), isTrue);
  });
}
