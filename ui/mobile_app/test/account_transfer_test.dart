import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/account_transfer/pages/account_transfer_page.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';

void main() {
  testWidgets('shows dedicated empty state when customer has no accounts', (
    tester,
  ) async {
    await _pump(tester, accounts: const []);
    expect(find.text('No accounts available'), findsOneWidget);
  });

  testWidgets('requires a second account', (tester) async {
    await _pump(tester, accounts: const [_usd]);
    expect(find.text('Another account is required'), findsOneWidget);
  });

  testWidgets('account without a card can be selected as source', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Account •••• 1111'), findsOneWidget);
    expect(find.text('Account •••• 2222'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('BAM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('change-source-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account •••• 2222').last);
    await tester.pumpAndSettle();
    expect(find.text('Account •••• 2222'), findsOneWidget);
    expect(find.text('Account •••• 1111'), findsOneWidget);
  });

  testWidgets('destination list excludes selected source', (tester) async {
    await _pump(tester);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Account •••• 1111'), findsOneWidget);
    expect(find.text('Account •••• 2222'), findsOneWidget);
    expect(find.text('Other accounts'), findsNothing);
  });

  testWidgets('insufficient balance blocks quote and continue', (tester) async {
    final service = _FakeTransactionService();
    await _pump(tester, service: service);
    await tester.enterText(
      find.byKey(const ValueKey('transfer-amount')),
      '101',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Insufficient balance.'), findsOneWidget);
    expect(service.quoteCalls, 0);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('continue-transfer')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('same-currency backend quote enables confirmation', (
    tester,
  ) async {
    final service = _FakeTransactionService();
    await _pump(tester, service: service);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '25');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('internal-transfer-quote')),
      findsOneWidget,
    );
    expect(find.text('Recipient gets'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('continue-transfer')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('cross-currency quote displays conversion and exchange rate', (
    tester,
  ) async {
    final service = _FakeTransactionService(converted: true);
    await _pump(tester, service: service, accounts: const [_usd, _eur]);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '10');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Exchange rate'), findsOneWidget);
    expect(find.textContaining('EUR 9.20'), findsOneWidget);
  });

  testWidgets('quote loading disables Continue until backend responds', (
    tester,
  ) async {
    final completer = Completer<MoneyTransferQuote>();
    final service = _FakeTransactionService(quoteCompleter: completer);
    await _pump(tester, service: service);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '10');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('quote-loading')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('continue-transfer')),
          )
          .onPressed,
      isNull,
    );
    completer.complete(service.quoteFor(10));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('internal-transfer-quote')),
      findsOneWidget,
    );
  });

  testWidgets('quote error is displayed and blocks confirmation', (
    tester,
  ) async {
    final service = _FakeTransactionService(quoteError: true);
    await _pump(tester, service: service);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '10');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('FX quote unavailable'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('continue-transfer')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('swap invalidates and requests a quote for reversed accounts', (
    tester,
  ) async {
    final service = _FakeTransactionService();
    await _pump(tester, service: service);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '10');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('swap-accounts')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(service.lastSource, _bam.id);
    expect(service.lastDestination, _usd.id);
  });

  testWidgets('confirmed transfer shows success state', (tester) async {
    final service = _FakeTransactionService();
    await _pump(tester, service: service);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '25');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('continue-transfer')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm transfer'), findsOneWidget);
    expect(find.text('From  •••• 1111'), findsOneWidget);
    expect(find.text('To      •••• 2222'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-transfer')));
    await tester.pumpAndSettle();
    expect(find.text('Transfer successful'), findsOneWidget);
    expect(service.transferCalls, 1);
  });

  testWidgets('backend transfer error is shown and success is not displayed', (
    tester,
  ) async {
    final service = _FakeTransactionService(transferError: true);
    await _pump(tester, service: service);
    await tester.enterText(find.byKey(const ValueKey('transfer-amount')), '25');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('continue-transfer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-transfer')));
    await tester.pumpAndSettle();
    expect(find.text('Transfer was rejected'), findsOneWidget);
    expect(find.text('Transfer successful'), findsNothing);
  });
}

const _usd = Account(
  id: 'account-usd',
  accountNumber: 'BA391111',
  balance: 100,
  currency: 'USD',
  accountType: 'Checking',
);
const _bam = Account(
  id: 'account-bam',
  accountNumber: 'BA392222',
  balance: 200,
  currency: 'BAM',
  accountType: 'Savings',
);
const _eur = Account(
  id: 'account-eur',
  accountNumber: 'BA393333',
  balance: 300,
  currency: 'EUR',
  accountType: 'Savings',
);

Future<void> _pump(
  WidgetTester tester, {
  List<Account> accounts = const [_usd, _bam],
  _FakeTransactionService? service,
}) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AccountTransferPage(
        session: _session(),
        transactionService: service ?? _FakeTransactionService(),
        initialSummary: AccountBalanceSummary(
          totals: const [],
          accounts: accounts,
        ),
        initialCards: const [],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AuthSession _session() {
  final session = AuthSession(ApiClient());
  session
    ..token = 'token'
    ..user = const AuthUser(
      id: 'user',
      firstName: 'Test',
      lastName: 'Customer',
      email: 'test@example.com',
      role: 'Customer',
    );
  return session;
}

class _FakeTransactionService extends TransactionService {
  _FakeTransactionService({
    this.converted = false,
    this.transferError = false,
    this.quoteError = false,
    this.quoteCompleter,
  }) : super(ApiClient());

  final bool converted;
  final bool transferError;
  final bool quoteError;
  final Completer<MoneyTransferQuote>? quoteCompleter;
  int quoteCalls = 0;
  int transferCalls = 0;
  String? lastSource;
  String? lastDestination;

  @override
  Future<MoneyTransferQuote> getInternalTransferQuote({
    required String token,
    required String sourceAccountId,
    required String destinationAccountId,
    required double amount,
  }) {
    quoteCalls++;
    lastSource = sourceAccountId;
    lastDestination = destinationAccountId;
    if (quoteError) throw ApiException('FX quote unavailable', 503);
    return quoteCompleter?.future ?? Future.value(quoteFor(amount));
  }

  MoneyTransferQuote quoteFor(double amount) => MoneyTransferQuote(
    sourceCurrency: lastSource == _bam.id ? 'BAM' : 'USD',
    transferCurrency: lastSource == _bam.id ? 'BAM' : 'USD',
    destinationCurrency: converted
        ? 'EUR'
        : lastSource == _bam.id
        ? 'USD'
        : 'BAM',
    amount: amount,
    exchangeRate: converted ? .92 : 1,
    debitAmount: amount,
    destinationAmount: converted ? amount * .92 : amount,
    requiresConversion: converted,
  );

  @override
  Future<MoneyTransferResult> internalTransfer({
    required String token,
    required String sourceAccountId,
    required String destinationAccountId,
    required double amount,
    String? description,
  }) async {
    transferCalls++;
    if (transferError) throw ApiException('Transfer was rejected', 400);
    return MoneyTransferResult(
      referenceNumber: 'INT-REF',
      status: 'Completed',
      amount: amount,
      currency: sourceAccountId == _bam.id ? 'BAM' : 'USD',
    );
  }
}
