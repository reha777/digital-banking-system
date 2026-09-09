import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/cards/admin_card_request_models.dart';
import 'package:desktop_app/src/features/cards/admin_card_request_service.dart';
import 'package:desktop_app/src/features/cards/widgets/issued_card_once_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('approval response carries the one-time issue result', () async {
    final service = AdminCardRequestService(
      ApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              ..._request,
              'issuedCard': {
                'cardId': 'card-1',
                'cardNumber': '4562112245957852',
                'expiryMonth': 9,
                'expiryYear': 2030,
                'oneTimeCvv': '4821',
                'warning':
                    'CVV is shown only once and cannot be retrieved later.',
              },
            }),
            200,
          ),
        ),
      ),
    );

    final approved = await service.approve(token: 'token', id: 'request-1');

    final issued = approved.issuedCard;
    expect(issued, isNotNull);
    expect(issued!.cardNumber, '4562112245957852');
    expect(issued.oneTimeCvv, '4821');
    expect(issued.formattedExpiry, '09/2030');
    expect(issued.warning, contains('only once'));
  });

  test('a request read back later carries no issue result and no CVV', () {
    final request = AdminCardRequest.fromJson(_request);

    expect(request.issuedCard, isNull);
    expect(jsonEncode(_request).toLowerCase(), isNot(contains('cvv')));
  });

  testWidgets('one-time dialog shows the CVV with an explicit warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IssuedCardOnceDialog(
            issued: CardIssueResult(
              cardId: 'card-1',
              cardNumber: '4562112245957852',
              expiryMonth: 9,
              expiryYear: 2030,
              oneTimeCvv: '4821',
              warning: 'CVV is shown only once and cannot be retrieved later.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Card issued'), findsOneWidget);
    expect(find.text('4562 1122 4595 7852'), findsOneWidget);
    expect(find.text('09/2030'), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    expect(
      find.text('CVV is shown only once and cannot be retrieved later.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

const _request = {
  'id': 'request-1',
  'customerName': 'Alpha Customer',
  'customerEmail': 'alpha@test.com',
  'cardholderName': 'Alpha Customer',
  'currency': 'BAM',
  'documentNumber': 'ID-1',
  'deliveryAddress': 'Street 1',
  'note': '',
  'status': 'Approved',
  'documents': <Map<String, dynamic>>[],
  'approvedAccountNumber': 'BA-123456-CHECKING',
  'approvedMaskedCardNumber': '**** **** **** 7852',
  'approvedCardExpiryDate': '2030-09-24T00:00:00Z',
  'approvedCardStatus': 'Active',
  'approvedCardBrand': 'Mastercard',
  'createdAtUtc': '2026-09-01T10:00:00Z',
  'reviewedAtUtc': '2026-09-02T10:00:00Z',
};
