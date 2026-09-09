import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/core/app_error_message.dart';
import 'package:desktop_app/src/features/cards/admin_card_request_service.dart';
import 'package:desktop_app/src/features/transactions/admin_transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Professor item 10: when approval is refused because the system state changed,
/// the admin must see the server's business reason, not a generic failure.
void main() {
  const messages = [
    'Source account is no longer active.',
    'Destination account is no longer active.',
    'Source customer is no longer active.',
    'Destination customer is no longer active.',
    'Account currencies no longer match the transaction.',
    'Source balance is no longer sufficient.',
    'Customer is no longer active, so the card request cannot be approved.',
    'Active CHECKING account type is not configured.',
  ];

  for (final message in messages) {
    test('"$message" reaches the admin unchanged', () {
      expect(AppErrorMessage.from(ApiException(message, 400)), message);
    });
  }

  test('a refused transaction approval surfaces the business reason', () async {
    final service = AdminTransactionService(
      ApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Source customer is no longer active.'}),
            400,
          ),
        ),
      ),
    );

    final error = await _capture(
      () => service.approveReview(token: 'token', id: 'transaction-1'),
    );

    expect(error, isA<ApiException>());
    expect(
      AppErrorMessage.from(error!),
      'Source customer is no longer active.',
    );
  });

  test('a refused card approval throws instead of issuing a card', () async {
    final service = AdminCardRequestService(
      ApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message':
                  'Customer is no longer active, so the card request cannot be approved.',
            }),
            400,
          ),
        ),
      ),
    );

    final error = await _capture(
      () => service.approve(token: 'token', id: 'request-1'),
    );

    // The caller never receives an issued card, so no one-time CVV can be shown.
    expect(error, isA<ApiException>());
    expect(
      AppErrorMessage.from(error!),
      'Customer is no longer active, so the card request cannot be approved.',
    );
  });
}

Future<Object?> _capture(Future<Object?> Function() action) async {
  try {
    await action();
    return null;
  } catch (error) {
    return error;
  }
}
