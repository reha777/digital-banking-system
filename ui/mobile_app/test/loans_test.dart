import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/home/widgets/home_quick_actions.dart';
import 'package:mobile_app/src/features/loans/loan_service.dart';
import 'package:mobile_app/src/features/loans/models/loan_models.dart';
import 'package:mobile_app/src/features/loans/pages/loan_application_page.dart';
import 'package:mobile_app/src/features/loans/pages/loan_details_page.dart';
import 'package:mobile_app/src/features/loans/pages/loan_payment_page.dart';
import 'package:mobile_app/src/features/loans/pages/loans_page.dart';
import 'package:mobile_app/src/features/loans/widgets/loan_widgets.dart';

void main() {
  const product = LoanProductModel(
    id: 'product',
    name: 'API Personal Loan',
    description: 'Test',
    currency: 'EUR',
    minPrincipal: 500,
    maxPrincipal: 25000,
    annualInterestRate: 5.75,
    minTermMonths: 6,
    maxTermMonths: 18,
    termStepMonths: 6,
  );

  testWidgets('Home Loan quick action invokes navigation callback', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeQuickActions(onLoan: () => opened = true)),
      ),
    );
    await tester.tap(find.text('Loan'));
    expect(opened, isTrue);
  });

  testWidgets(
    'apply flow generates terms, filters accounts and displays API quote',
    (tester) async {
      final repository = _FakeRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: LoanApplicationPage(
            token: 'token',
            product: product,
            accounts: const [
              Account(
                id: 'eur',
                accountNumber: 'BA00001234',
                balance: 0,
                currency: 'EUR',
              ),
              Account(
                id: 'usd',
                accountNumber: 'BA00009999',
                balance: 0,
                currency: 'USD',
              ),
            ],
            repository: repository,
          ),
        ),
      );
      expect(find.text('6 months'), findsOneWidget);
      expect(find.text('12 months'), findsOneWidget);
      expect(find.text('18 months'), findsOneWidget);
      expect(find.text('Account **** 1234'), findsOneWidget);
      expect(find.text('Account **** 9999'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.pumpAndSettle();
      expect(find.text('123.45 EUR'), findsOneWidget);
      expect(repository.quoteCalls, 1);
    },
  );

  testWidgets('landing renders API products and pending state', (tester) async {
    final session = AuthSession(ApiClient())..token = 'token';
    final repository = _FakeRepository(products: const [product]);
    await tester.pumpWidget(
      MaterialApp(
        home: LoansPage(
          key: const ValueKey('pending'),
          session: session,
          repository: repository,
          accountsLoader: (_) async =>
              const AccountBalanceSummary(totals: [], accounts: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('API Personal Loan'), findsOneWidget);

    repository.current = _application(LoanApplicationStatus.pending);
    await tester.pumpWidget(
      MaterialApp(
        home: LoansPage(
          key: const ValueKey('approved'),
          session: session,
          repository: repository,
          accountsLoader: (_) async =>
              const AccountBalanceSummary(totals: [], accounts: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Apply Again'), findsNothing);
  });

  testWidgets('rejected landing supports Apply Again while approved does not', (
    tester,
  ) async {
    final session = AuthSession(ApiClient())..token = 'token';
    final repository = _FakeRepository(products: const [product])
      ..current = _application(
        LoanApplicationStatus.rejected,
        note: 'Try later.',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: LoansPage(
          key: const ValueKey('approved-landing'),
          session: session,
          repository: repository,
          accountsLoader: (_) async =>
              const AccountBalanceSummary(totals: [], accounts: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apply Again'), findsOneWidget);
    await tester.tap(find.text('Apply Again'));
    await tester.pump();
    expect(find.text('API Personal Loan'), findsWidgets);

    repository.current = _application(LoanApplicationStatus.approved);
    await tester.pumpWidget(
      MaterialApp(
        home: LoansPage(
          key: const ValueKey('approved-result'),
          session: session,
          repository: repository,
          accountsLoader: (_) async =>
              const AccountBalanceSummary(totals: [], accounts: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Apply Again'), findsNothing);
  });

  testWidgets('no matching account blocks submit with useful state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoanApplicationPage(
          token: 'token',
          product: product,
          accounts: const [
            Account(
              id: 'usd',
              accountNumber: '99',
              balance: 0,
              currency: 'USD',
            ),
          ],
          repository: _FakeRepository(),
        ),
      ),
    );
    expect(
      find.text('You need an EUR account to receive this loan.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'rejected status shows admin note and approved status is supported',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoanStatusCard(
              application: _application(
                LoanApplicationStatus.rejected,
                note: 'Income verification failed.',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Income verification failed.'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoanStatusCard(
              application: _application(LoanApplicationStatus.approved),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approved'), findsOneWidget);
    },
  );

  testWidgets('active loan landing shows API summary and actions', (
    tester,
  ) async {
    final session = AuthSession(ApiClient())..token = 'token';
    final repository = _FakeRepository()..currentLoan = _loan();
    await tester.pumpWidget(
      MaterialApp(
        home: LoansPage(
          session: session,
          repository: repository,
          accountsLoader: (_) async =>
              const AccountBalanceSummary(totals: [], accounts: []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active Loan'), findsOneWidget);
    expect(find.text('800.00 BAM'), findsOneWidget);
    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Pay Installment'), findsOneWidget);
  });

  testWidgets('loan details renders schedule and empty history', (
    tester,
  ) async {
    final repository = _FakeRepository()..details = _details();
    await tester.pumpWidget(
      MaterialApp(
        home: LoanDetailsPage(
          token: 'token',
          loanId: 'loan',
          accounts: const [],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Repayment Progress'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Installment #2'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Installment #2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('No payments yet.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No payments yet.'), findsOneWidget);
  });

  testWidgets(
    'active loan shows backend overdue warning and completed does not',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveLoanCard(
              loan: _loan(overdue: true),
              onDetails: () {},
              onPay: () {},
            ),
          ),
        ),
      );
      expect(find.text('Payment overdue'), findsOneWidget);
      expect(find.text('2 overdue installments'), findsOneWidget);
      expect(find.text('350.00 BAM overdue'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveLoanCard(
              loan: _loan(completed: true),
              onDetails: () {},
              onPay: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payment overdue'), findsNothing);
    },
  );

  testWidgets('details and payment quote render backend days overdue', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..details = _details(overdue: true)
      ..paymentQuote = _paymentQuote(overdue: true);
    await tester.pumpWidget(
      MaterialApp(
        home: LoanDetailsPage(
          token: 'token',
          loanId: 'loan',
          accounts: const [],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Overdue by 5 days'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Overdue by 5 days'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: LoanPaymentPage(
          token: 'token',
          loan: _loan(overdue: true),
          accounts: const [],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overdue installment · 5 days'), findsOneWidget);
  });

  testWidgets('payment filters currency and blocks insufficient balance', (
    tester,
  ) async {
    final repository = _FakeRepository()..paymentQuote = _paymentQuote();
    await tester.pumpWidget(
      MaterialApp(
        home: LoanPaymentPage(
          token: 'token',
          loan: _loan(),
          accounts: const [
            Account(
              id: 'bam',
              accountNumber: '1234',
              balance: 10,
              currency: 'BAM',
            ),
            Account(
              id: 'eur',
              accountNumber: '9999',
              balance: 500,
              currency: 'EUR',
            ),
          ],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('**** 1234'), findsOneWidget);
    expect(find.textContaining('**** 9999'), findsNothing);
    expect(find.text('Insufficient balance'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('continue-loan-payment')),
          )
          .onPressed,
      isNull,
    );
  });
}

LoanApplicationModel _application(
  LoanApplicationStatus status, {
  String? note,
}) => LoanApplicationModel(
  id: 'a',
  productId: 'p',
  productName: 'API Personal Loan',
  destinationAccountId: 'account',
  destinationAccountNumber: '**** 1234',
  principal: 1000,
  currency: 'EUR',
  annualInterestRate: 5.75,
  termMonths: 12,
  estimatedMonthlyPayment: 123.45,
  estimatedTotalInterest: 20,
  estimatedTotalRepayment: 1020,
  status: status,
  submittedAtUtc: DateTime.utc(2026),
  adminNote: note,
);

LoanModel _loan({bool overdue = false, bool completed = false}) => LoanModel(
  loanId: 'loan',
  applicationId: 'application',
  status: completed ? LoanStatus.completed : LoanStatus.active,
  productName: 'Personal Loan',
  originalPrincipal: 1000,
  outstandingPrincipal: 800,
  currency: 'BAM',
  annualInterestRate: 6.5,
  termMonths: 6,
  monthlyPayment: 175,
  totalRepayment: 1050,
  totalPaid: 175,
  startDateUtc: DateTime.utc(2026, 8),
  nextPaymentDateUtc: DateTime.utc(2026, 9),
  maturityDateUtc: DateTime.utc(2027, 2),
  paidInstallments: 1,
  remainingInstallments: 5,
  overdueInstallmentsCount: overdue ? 2 : 0,
  totalOverdueAmount: overdue ? 350 : 0,
  destinationAccountId: 'account',
  destinationAccountNumber: '**** 1234',
);

LoanDetailsModel _details({bool overdue = false}) => LoanDetailsModel(
  loan: _loan(overdue: overdue),
  installments: [
    LoanInstallmentModel(
      id: '2',
      installmentNumber: 2,
      dueDateUtc: DateTime.utc(2026, 9),
      scheduledAmount: 175,
      principalAmount: 162,
      interestAmount: 13,
      remainingPrincipalAfter: 638,
      status: LoanInstallmentStatus.pending,
      isOverdue: overdue,
      daysOverdue: overdue ? 5 : 0,
    ),
  ],
  payments: const [],
);

LoanPaymentQuoteModel _paymentQuote({bool overdue = false}) =>
    LoanPaymentQuoteModel(
      loanId: 'loan',
      installmentId: '2',
      installmentNumber: 2,
      dueDateUtc: DateTime.utc(2026, 9),
      amount: 175,
      principalAmount: 162,
      interestAmount: 13,
      currency: 'BAM',
      outstandingBefore: 800,
      outstandingAfter: 638,
      isFinalInstallment: false,
      isOverdue: overdue,
      daysOverdue: overdue ? 5 : 0,
    );

class _FakeRepository implements LoanRepository {
  _FakeRepository({this.products = const []});
  int quoteCalls = 0;
  final List<LoanProductModel> products;
  LoanApplicationModel? current;
  LoanModel? currentLoan;
  LoanModel? recentLoan;
  LoanDetailsModel? details;
  LoanPaymentQuoteModel? paymentQuote;
  @override
  Future<LoanModel?> getCurrentLoan(String token) async => currentLoan;
  @override
  Future<LoanModel?> getRecentLoan(String token) async => recentLoan;
  @override
  Future<LoanDetailsModel> getLoanDetails(String token, String loanId) =>
      Future.value(details!);
  @override
  Future<LoanPaymentQuoteModel> getPaymentQuote(String token, String loanId) =>
      Future.value(paymentQuote!);
  @override
  Future<LoanPaymentResultModel> payInstallment(
    String token,
    String loanId, {
    required String sourceAccountId,
    required String clientRequestId,
  }) => throw UnimplementedError();
  @override
  Future<LoanQuoteModel> getQuote(
    String token, {
    required String productId,
    required double principal,
    required int termMonths,
  }) async {
    quoteCalls++;
    return LoanQuoteModel(
      productId: productId,
      productName: 'API Personal Loan',
      currency: 'EUR',
      principal: principal,
      annualInterestRate: 5.75,
      termMonths: termMonths,
      monthlyPayment: 123.45,
      totalInterest: 20,
      totalRepayment: 1020,
      schedule: const [],
    );
  }

  @override
  Future<LoanApplicationModel?> getCurrentApplication(String token) async =>
      current;
  @override
  Future<List<LoanProductModel>> getProducts(String token) async => products;
  @override
  Future<LoanApplicationModel> submitApplication(
    String token, {
    required String productId,
    required String destinationAccountId,
    required double principal,
    required int termMonths,
    required String clientRequestId,
  }) async => _application(LoanApplicationStatus.pending);
}
