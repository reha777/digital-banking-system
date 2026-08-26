import 'dart:convert';

import 'package:desktop_app/main.dart';
import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/auth/password_reset_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows admin login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const BankingDesktopApp());
    await tester.pumpAndSettle();

    expect(find.text('Admin Sign In'), findsOneWidget);
    final loginFields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(loginFields[0].controller!.text, isEmpty);
    expect(loginFields[1].controller!.text, isEmpty);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Send reset instructions'), findsOneWidget);
  });

  test('desktop demo forgot sends delivery email and Admin context', () async {
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
    ).forgot('professor@example.com', demoClientType: 'Admin');

    expect(requestUri.path, '/api/auth/demo/forgot-password');
    expect(requestBody, {
      'email': 'professor@example.com',
      'clientType': 'Admin',
    });
    expect(requestBody.containsKey('userId'), isFalse);
  });
}
