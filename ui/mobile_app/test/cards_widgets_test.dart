import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/cards/card_service.dart';
import 'package:mobile_app/src/features/cards/widgets/bank_card.dart';
import 'package:mobile_app/src/features/cards/widgets/card_requests_panel.dart';

void main() {
  testWidgets('renders the existing Visa card details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 335,
            child: BankCard(
              card: BankCardModel(
                id: 'card-1',
                accountId: 'account-1',
                accountNumber: 'BA-000001',
                cardNumber: '4562112245957852',
                maskedCardNumber: '**** 7852',
                cardholderName: 'Test Customer',
                cvv: '123',
                expiryDate: DateTime.utc(2030, 7),
                brand: 'Visa',
                status: 'Active',
                balance: 100,
                currency: 'USD',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('4562  1122  4595  7852'), findsOneWidget);
    expect(find.text('Test Customer'), findsOneWidget);
    expect(find.text('07/2030'), findsOneWidget);
    expect(find.text('VISA'), findsOneWidget);
  });

  testWidgets('shows requested documents, admin note and upload action', (
    tester,
  ) async {
    final request = CardRequestModel(
      id: 'request-1',
      status: 'Documents requested',
      statusValue: 4,
      currency: 'USD',
      documentsRequestNote: 'Upload proof of address.',
      documents: [
        CardRequestDocumentModel(
          id: 'document-1',
          fileName: 'proof.pdf',
          uploadedAtUtc: DateTime.utc(2026),
        ),
      ],
      createdAtUtc: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardRequestsPanel(
            requests: [request],
            token: 'token',
            cardService: CardService(ApiClient()),
            onDocumentUploaded: () {},
          ),
        ),
      ),
    );

    expect(request.requiresDocuments, isTrue);
    expect(find.text('USD card request'), findsOneWidget);
    expect(find.text('Documents requested'), findsOneWidget);
    expect(find.text('Upload proof of address.'), findsOneWidget);
    expect(find.text('proof.pdf'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Upload'), findsOneWidget);
  });
}
