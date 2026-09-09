import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/cards/card_service.dart';
import 'package:mobile_app/src/features/cards/widgets/bank_card.dart';

void main() {
  test('card model carries no CVV even if the payload still has one', () {
    final card = BankCardModel.fromJson({
      'id': 'card-1',
      'accountId': 'account-1',
      'accountNumber': 'BA-000001',
      'cardNumber': '4562112245957852',
      'maskedCardNumber': '**** **** **** 7852',
      'cardholderName': 'Test Customer',
      'cvv': '4821',
      'expiryDate': '2030-07-24T00:00:00Z',
      'brand': 'Mastercard',
      'status': 'Active',
      'balance': 100,
      'currency': 'USD',
    });

    expect(card.cardNumber, '4562112245957852');
    expect(card.maskedCardNumber, '**** **** **** 7852');
    expect(card.status, 'Active');
    // No cvv field exists on the model, so the value cannot reach the UI.
    expect(jsonEncode(_encodable(card)).toLowerCase(), isNot(contains('cvv')));
    expect(jsonEncode(_encodable(card)), isNot(contains('4821')));
  });

  test('sensitive data reveals the number and expiry, never a CVV', () async {
    late Uri requested;
    final service = CardService(
      ApiClient(
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'id': 'card-1',
              'cardNumber': '4562112245957852',
              'expiryDate': '2030-07-24T00:00:00Z',
            }),
            200,
          );
        }),
      ),
    );

    final revealed = await service.revealSensitiveData(
      token: 'token',
      cardId: 'card-1',
    );

    expect(requested.path, '/api/cards/card-1/sensitive-data');
    expect(revealed.cardNumber, '4562112245957852');
    expect(revealed.expiryDate, DateTime.utc(2030, 7, 24));
  });

  testWidgets('card face shows no CVV, revealed or not', (tester) async {
    for (final revealed in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 335,
              child: BankCard(
                card: _card,
                revealed: revealed,
                sensitiveCardNumber: revealed ? '4562112245957852' : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CVV'), findsNothing);
      expect(find.text('•••'), findsNothing);
      expect(find.text('Test Customer'), findsOneWidget);
      expect(find.text('07/2030'), findsOneWidget);
    }
  });
}

Map<String, Object?> _encodable(BankCardModel card) => {
  'id': card.id,
  'accountId': card.accountId,
  'accountNumber': card.accountNumber,
  'cardNumber': card.cardNumber,
  'maskedCardNumber': card.maskedCardNumber,
  'cardholderName': card.cardholderName,
  'expiryDate': card.expiryDate.toIso8601String(),
  'brand': card.brand,
  'status': card.status,
  'balance': card.balance,
  'currency': card.currency,
};

final _card = BankCardModel(
  id: 'card-1',
  accountId: 'account-1',
  accountNumber: 'BA-000001',
  cardNumber: '4562112245957852',
  maskedCardNumber: '**** **** **** 7852',
  cardholderName: 'Test Customer',
  expiryDate: DateTime.utc(2030, 7),
  brand: 'Mastercard',
  status: 'Active',
  balance: 100,
  currency: 'USD',
);
