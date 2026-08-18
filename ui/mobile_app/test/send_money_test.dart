import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/transactions/pages/add_recipient_page.dart';
import 'package:mobile_app/src/features/transactions/send_money_screen.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';
import 'package:mobile_app/src/features/transactions/widgets/recipient_selector.dart';
import 'package:mobile_app/src/features/transactions/widgets/send_money_amount_field.dart';
import 'package:mobile_app/src/features/transactions/widgets/transfer_result_view.dart';

const recipient = RecentRecipient(
  accountId: 'recipient-1',
  firstName: 'Alice',
  lastName: 'Recipient',
  accountNumber: 'BA-RECIPIENT',
);

const source = Account(
  id: 'source-1',
  accountNumber: 'BA-SOURCE',
  balance: 500,
  currency: 'EUR',
);

final sourceCard = BankCardModel(
  id: 'card-1',
  accountId: source.id,
  accountNumber: source.accountNumber,
  cardNumber: '',
  maskedCardNumber: '**** **** **** 0675',
  cardholderName: 'Test Customer',
  cvv: '',
  expiryDate: DateTime.utc(2030),
  brand: 'Mastercard',
  status: 'Active',
  balance: source.balance,
  currency: source.currency,
);

void main() {
  testWidgets('recipient selector always renders Add and supports selection', (
    tester,
  ) async {
    RecentRecipient? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipientSelector(
            recipients: const [recipient],
            selected: null,
            onAdd: () {},
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('recipient-recipient-1')));
    expect(selected, recipient);
  });

  testWidgets('empty and failed recipient list keep Add available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipientSelector(
            recipients: const [],
            selected: null,
            onAdd: () {},
            onSelected: (_) {},
            hasError: true,
          ),
        ),
      ),
    );
    expect(find.text('Add'), findsOneWidget);
    expect(find.textContaining('still add one'), findsOneWidget);
  });

  testWidgets('new recipient rejects the source account', (tester) async {
    final service = _FakeTransactionService();
    await tester.pumpWidget(
      MaterialApp(
        home: AddRecipientPage(
          session: _session(),
          service: service,
          sourceAccountNumber: source.accountNumber,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('recipient-account')),
      source.accountNumber,
    );
    await tester.tap(find.byKey(const ValueKey('verify-recipient')));
    await tester.pump();
    expect(
      find.text('You cannot send money to the source account.'),
      findsOneWidget,
    );
    expect(service.lookupCalls, 0);
  });

  testWidgets('new recipient lookup fills backend verified names', (
    tester,
  ) async {
    final service = _FakeTransactionService();
    await tester.pumpWidget(
      MaterialApp(
        home: AddRecipientPage(
          session: _session(),
          service: service,
          sourceAccountNumber: source.accountNumber,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('recipient-account')),
      recipient.accountNumber,
    );
    await tester.tap(find.byKey(const ValueKey('verify-recipient')));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Recipient'), findsOneWidget);
    expect(find.text('Use Recipient'), findsOneWidget);
  });

  testWidgets('recent load error does not block Add recipient flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SendMoneyScreen(
          session: _session(),
          sourceAccount: source,
          transactionService: _FakeTransactionService(loadError: true),
          initialCards: [sourceCard],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('still add one'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(AddRecipientPage), findsOneWidget);
  });

  testWidgets('amount field validates invalid amount', (tester) async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController(text: '0');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: SendMoneyAmountField(
              currency: 'EUR',
              controller: controller,
              availableBalance: 500,
              onChangeCurrency: () {},
            ),
          ),
        ),
      ),
    );
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Amount must be greater than zero.'), findsOneWidget);
  });

  testWidgets('pending transfer has a distinct review result', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransferResultView(
          result: const MoneyTransferResult(
            referenceNumber: 'REF-PENDING',
            status: '1',
            amount: 12000,
            currency: 'EUR',
          ),
          recipient: recipient,
          onDone: () {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('pending-result')), findsOneWidget);
    expect(find.textContaining('administrative approval'), findsOneWidget);
    expect(find.text('Money sent successfully'), findsNothing);
  });

  testWidgets('currency selector requests and renders a backend quote', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SendMoneyScreen(
          session: _session(),
          sourceAccount: source,
          transactionService: _FakeTransactionService(),
          initialCards: [sourceCard],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('recipient-recipient-1')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('recipient-recipient-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('change-currency')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('change-currency')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('currency-USD')), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-EUR')), findsOneWidget);
    expect(find.byKey(const ValueKey('currency-BAM')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('currency-USD')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('send-amount')), '10');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('10.00 USD'), findsOneWidget);
    expect(find.text('Debited'), findsOneWidget);
  });

  testWidgets(
    'recent recipient fills destination and submit is single-flight',
    (tester) async {
      final completion = Completer<MoneyTransferResult>();
      final service = _FakeTransactionService(sendCompletion: completion);
      await tester.pumpWidget(
        MaterialApp(
          home: SendMoneyScreen(
            session: _session(),
            sourceAccount: source,
            transactionService: service,
            initialCards: [sourceCard],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('send-description')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('recipient-recipient-1')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('recipient-recipient-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('send-description')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('send-amount')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const ValueKey('send-amount')), '25');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('send-money-submit'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Review payment'), findsOneWidget);
      final confirm = find.byKey(const ValueKey('confirm-transfer'));
      await tester.tap(confirm);
      await tester.pump();
      await tester.tap(confirm);
      expect(service.sendCalls, 1);
      expect(service.lastSourceAccountId, sourceCard.accountId);
      expect(service.lastCurrency, sourceCard.currency);
      expect(service.lastDestination, recipient.accountNumber);
      completion.complete(
        const MoneyTransferResult(
          referenceNumber: 'REF',
          status: '2',
          amount: 25,
          currency: 'EUR',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('completed-result')), findsOneWidget);
    },
  );
}

AuthSession _session() {
  final session = AuthSession(ApiClient());
  session
    ..token = 'token'
    ..user = const AuthUser(
      id: 'user-1',
      firstName: 'Demo',
      lastName: 'Customer',
      email: 'demo@example.com',
      role: 'Customer',
    );
  return session;
}

class _FakeTransactionService extends TransactionService {
  _FakeTransactionService({this.sendCompletion, this.loadError = false})
    : super(ApiClient());
  final Completer<MoneyTransferResult>? sendCompletion;
  final bool loadError;
  int lookupCalls = 0;
  int sendCalls = 0;
  String? lastDestination;
  String? lastSourceAccountId;
  String? lastCurrency;

  @override
  Future<List<RecentRecipient>> getRecentRecipients(String token) async {
    if (loadError) throw ApiException('offline', 503);
    return const [recipient];
  }

  @override
  Future<RecentRecipient> lookupRecipient({
    required String token,
    required String accountNumber,
  }) async {
    lookupCalls++;
    return recipient;
  }

  @override
  Future<MoneyTransferResult> sendMoney({
    required String token,
    required String sourceAccountId,
    required String destinationAccountNumber,
    required double amount,
    required String currency,
    String? description,
  }) {
    sendCalls++;
    lastSourceAccountId = sourceAccountId;
    lastCurrency = currency;
    lastDestination = destinationAccountNumber;
    return sendCompletion?.future ??
        Future.value(
          const MoneyTransferResult(
            referenceNumber: 'REF',
            status: '2',
            amount: 25,
            currency: 'EUR',
          ),
        );
  }

  @override
  Future<MoneyTransferQuote> getTransferQuote({
    required String token,
    required String sourceAccountId,
    required String destinationAccountNumber,
    required double amount,
    required String currency,
  }) async => MoneyTransferQuote(
    sourceCurrency: 'EUR',
    transferCurrency: currency,
    destinationCurrency: 'EUR',
    amount: amount,
    exchangeRate: currency == 'EUR' ? 1 : .92,
    debitAmount: currency == 'EUR' ? amount : amount * .92,
    destinationAmount: amount,
    requiresConversion: currency != 'EUR',
  );
}
