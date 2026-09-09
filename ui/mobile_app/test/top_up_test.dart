import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';
import 'package:mobile_app/src/features/accounts/account_service.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/home/widgets/home_quick_actions.dart';
import 'package:mobile_app/src/features/transactions/top_up_screen.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';
import 'package:mobile_app/src/features/transactions/widgets/transaction_tile.dart';

void main() {
  testWidgets('Home exposes Top Up action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeQuickActions(onTopUp: () => tapped = true)),
      ),
    );

    await tester.tap(find.text('Top Up'));

    expect(tapped, isTrue);
  });

  testWidgets('Top Up validates amount and external card last four digits', (
    tester,
  ) async {
    final transactionService = _TopUpService();
    await tester.pumpWidget(_app(transactionService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm Top Up'));
    await tester.pump();

    expect(find.text('Enter a valid amount.'), findsOneWidget);
    expect(find.text('Enter exactly the last 4 digits.'), findsOneWidget);
    expect(transactionService.calls, 0);
  });

  testWidgets(
    'Valid Top Up submits selected account currency and shows success',
    (tester) async {
      final transactionService = _TopUpService();
      await tester.pumpWidget(_app(transactionService));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Last 4 digits'),
        '1234',
      );
      await tester.tap(find.text('Confirm Top Up'));
      await tester.pumpAndSettle();

      expect(transactionService.calls, 1);
      expect(transactionService.currency, 'USD');
      expect(transactionService.sourceDescription, '1234');
      expect(find.text('Top up completed'), findsOneWidget);
    },
  );

  testWidgets('TopUp response parses and renders as positive currency inflow', (
    tester,
  ) async {
    final transaction = BankTransaction.fromJson({
      'id': 'top-up-id',
      'accountId': 'account-id',
      'accountNumber': 'BA-0001',
      'referenceNumber': 'TOPUP-REFERENCE',
      'amount': 100,
      'currency': 'EUR',
      'type': 'TopUp',
      'description': 'Top up from External card ending 1234',
      'status': 'Completed',
      'isHighRiskReview': false,
      'createdAtUtc': '2026-09-09T10:00:00Z',
      'topUpSourceType': 'ExternalBankCard',
      'topUpSourceDescription': 'External card ending 1234',
    });

    expect(transaction.type, BankTransactionType.topUp);
    expect(transaction.topUpSourceDescription, 'External card ending 1234');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TransactionHistoryTile(transaction: transaction)),
      ),
    );
    expect(find.text('Top Up'), findsOneWidget);
    expect(find.text('+100.00 EUR'), findsOneWidget);
  });
}

Widget _app(_TopUpService transactionService) {
  final session = AuthSession(ApiClient())..token = 'customer-token';
  return MaterialApp(
    home: TopUpScreen(
      session: session,
      accountService: _AccountService(),
      transactionService: transactionService,
    ),
  );
}

class _AccountService extends AccountService {
  _AccountService() : super(ApiClient());

  @override
  Future<AccountBalanceSummary> getBalanceSummary(String token) async =>
      const AccountBalanceSummary(
        totals: [CurrencyBalance(currency: 'USD', balance: 1000)],
        accounts: [
          Account(
            id: 'account-id',
            accountNumber: 'BA-000001-CHECKING',
            balance: 1000,
            currency: 'USD',
          ),
        ],
      );
}

class _TopUpService extends TransactionService {
  _TopUpService() : super(ApiClient());
  int calls = 0;
  String? currency;
  String? sourceDescription;

  @override
  Future<BankTransaction> topUp({
    required String token,
    required String accountId,
    required double amount,
    required String currency,
    required String sourceType,
    required String sourceDescription,
    required String clientRequestId,
  }) async {
    calls++;
    this.currency = currency;
    this.sourceDescription = sourceDescription;
    return BankTransaction(
      id: 'top-up-id',
      accountId: accountId,
      accountNumber: 'BA-000001-CHECKING',
      referenceNumber: 'TOPUP-REFERENCE',
      amount: amount,
      currency: currency,
      type: BankTransactionType.topUp,
      description: 'Top up',
      status: 'Completed',
      statusValue: 2,
      isHighRiskReview: false,
      createdAtUtc: DateTime.utc(2026, 9, 9),
    );
  }
}
