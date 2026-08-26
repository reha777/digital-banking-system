import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/theme_controller.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';
import 'package:mobile_app/src/features/home/widgets/home_balance_card.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/home/widgets/recent_transactions.dart';
import 'package:mobile_app/src/features/settings/pages/settings_page.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows balance data and quick actions', (tester) async {
    var transferTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeBalanceCard(
              firstName: 'Test',
              lastName: 'Customer',
              summary: const AccountBalanceSummary(
                totals: [CurrencyBalance(currency: 'USD', balance: 1234.5)],
                accounts: [
                  Account(
                    id: 'account-1',
                    accountNumber: '4562112245957852',
                    balance: 1234.5,
                    currency: 'USD',
                  ),
                ],
              ),
              cards: [testCard],
              onSendMoney: (_) {},
              onTransfer: () => transferTapped = true,
              onCardTap: (_) {},
              onActiveCardChanged: (_) {},
              hasProfilePhoto: false,
              accessToken: null,
              onProfileTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Test Customer'), findsNWidgets(2));
    expect(find.text('USD 1,234.50'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Loan'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    await tester.ensureVisible(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    expect(transferTapped, isTrue);
  });

  testWidgets('recent transactions reuse the transaction tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentTransactions(
            transactions: [
              BankTransaction(
                id: 'transaction-1',
                accountId: 'account-1',
                accountNumber: 'BA-1',
                referenceNumber: 'REF-1',
                amount: -25,
                description: 'Grocery shopping',
                status: 'Completed',
                statusValue: 2,
                isHighRiskReview: false,
                createdAtUtc: DateTime.utc(2026),
              ),
            ],
            onSeeAll: () {},
          ),
        ),
      ),
    );

    expect(find.text('Recent transactions'), findsOneWidget);
    expect(find.text('Grocery shopping'), findsOneWidget);
    expect(find.text(r'- $25.00'), findsOneWidget);
    expect(find.text('See All'), findsOneWidget);
  });

  testWidgets('home card swipe reports the active card account', (
    tester,
  ) async {
    String? accountId;
    final second = BankCardModel(
      id: 'card-2',
      accountId: 'account-2',
      accountNumber: 'BA-2',
      cardNumber: '',
      maskedCardNumber: '**** **** **** 2222',
      cardholderName: 'Test Customer',
      cvv: '',
      expiryDate: DateTime.utc(2030, 7),
      brand: 'Mastercard',
      status: 'Blocked',
      balance: 240,
      currency: 'EUR',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeBalanceCard(
            firstName: 'Test',
            lastName: 'Customer',
            summary: const AccountBalanceSummary(totals: [], accounts: []),
            cards: [testCard, second],
            onSendMoney: (_) {},
            onCardTap: (_) {},
            onActiveCardChanged: (card) => accountId = card.accountId,
            hasProfilePhoto: false,
            accessToken: null,
            onProfileTap: () {},
          ),
        ),
      ),
    );

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1200);
    await tester.pumpAndSettle();
    expect(accountId, 'account-2');
    expect(find.text('EUR 240.00'), findsOneWidget);
  });

  testWidgets('recent transactions has isolated empty and error states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentTransactions(transactions: const [], onSeeAll: () {}),
        ),
      ),
    );
    expect(find.text('No transactions yet'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecentTransactions(
            transactions: const [],
            error: 'failed',
            onRetry: () async {},
            onSeeAll: () {},
          ),
        ),
      ),
    );
    expect(find.text('Transactions could not be loaded.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('settings keeps theme control', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = ThemeController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(themeController: controller)),
      ),
    );

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });
}

final testCard = BankCardModel(
  id: 'card-1',
  accountId: 'account-1',
  accountNumber: 'BA-1',
  cardNumber: '',
  maskedCardNumber: '**** **** **** 7852',
  cardholderName: 'Test Customer',
  cvv: '',
  expiryDate: DateTime.utc(2030, 7),
  brand: 'Mastercard',
  status: 'Active',
  balance: 1234.5,
  currency: 'USD',
);
