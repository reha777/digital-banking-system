import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/cards/card_service.dart';
import 'package:mobile_app/src/features/cards/widgets/bank_card.dart';
import 'package:mobile_app/src/features/cards/widgets/card_requests_panel.dart';
import 'package:mobile_app/src/features/cards/widgets/card_carousel.dart';

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

    expect(find.textContaining('••••'), findsOneWidget);
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

  testWidgets('carousel changes selected card', (tester) async {
    var selected = 0;
    final cards = [_card('card-1', 'Active'), _card('card-2', 'Blocked')];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardCarousel(
            cards: cards,
            onCardChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1200);
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(cards[1].canTransfer, isFalse);
  });

  testWidgets('rejected reason and submitted document state are visible', (
    tester,
  ) async {
    final rejected = CardRequestModel(
      id: 'r1',
      status: 'Rejected',
      statusValue: 3,
      currency: 'EUR',
      documentsRequestNote: null,
      documents: const [],
      createdAtUtc: DateTime.utc(2026),
      adminNote: 'Invalid document.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardRequestsPanel(
            requests: [rejected],
            token: 'token',
            cardService: CardService(ApiClient()),
            onDocumentUploaded: () {},
          ),
        ),
      ),
    );
    expect(find.text('Reason: Invalid document.'), findsOneWidget);
  });
}

BankCardModel _card(String id, String status) => BankCardModel(
  id: id,
  accountId: 'account-$id',
  accountNumber: 'BA-$id',
  cardNumber: '',
  maskedCardNumber: '**** **** **** 0675',
  cardholderName: 'Customer',
  cvv: '',
  expiryDate: DateTime.utc(2030),
  brand: 'Mastercard',
  status: status,
  balance: 100,
  currency: 'EUR',
);
