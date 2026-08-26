import 'dart:async';

import 'package:desktop_app/src/features/admin_shell/admin_section.dart';
import 'package:desktop_app/src/features/admin_shell/widgets/admin_sidebar.dart';
import 'package:desktop_app/src/features/loans/admin_loan_service.dart';
import 'package:desktop_app/src/features/loans/models/admin_loan_models.dart';
import 'package:desktop_app/src/features/loans/pages/loans_page.dart';
import 'package:desktop_app/src/features/loans/widgets/loan_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1440, 1000);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('Loans sidebar item invokes section navigation', (tester) async {
    AdminSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSidebar(
            userName: 'Admin',
            selectedSection: AdminSection.dashboard,
            onSectionSelected: (value) => selected = value,
            onLogout: () {},
            compact: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Loans'));
    expect(selected, AdminSection.loans);
  });

  testWidgets('Applications tab renders API table, statuses and pagination', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Amira Hadzic'), findsWidgets);
    expect(find.text('BAM Personal Loan'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Approved'), findsWidgets);
    expect(find.text('Rejected'), findsWidgets);
    expect(find.textContaining('applications'), findsWidgets);
  });

  testWidgets('search is debounced and status selection resets list query', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'amira');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repository.lastSearch, isNull);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pumpAndSettle();
    expect(repository.lastSearch, 'amira');
    await tester.tap(find.text('All statuses'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Rejected'));
    await tester.pumpAndSettle();
    expect(repository.lastStatus, 3);
  });

  testWidgets('pending details enable review and approve confirmation', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View / Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Loan Application Details'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    await tester.ensureVisible(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.text('Approve Loan Application?'), findsOneWidget);
    expect(find.text('10000.00 BAM'), findsWidgets);
    expect(find.text('**** 1234'), findsWidgets);
    await tester.tap(find.text('Approve Loan'));
    await tester.pumpAndSettle();
    expect(repository.reviewCalls, 1);
    expect(find.text('Loan application review saved.'), findsOneWidget);
  });

  testWidgets('reject confirmation requires reason', (tester) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View / Review').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    final reject = find.widgetWithText(FilledButton, 'Reject Application');
    expect(tester.widget<FilledButton>(reject).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'Income not verified');
    await tester.pump();
    expect(tester.widget<FilledButton>(reject).onPressed, isNotNull);
    await tester.tap(reject);
    await tester.pumpAndSettle();
    expect(repository.reviewCalls, 1);
  });

  testWidgets('approve is single flight and unknown errors are sanitized', (
    tester,
  ) async {
    final completer = Completer<AdminLoanApplicationDetails>();
    final repository = _FakeRepository(reviewCompleter: completer);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View / Review').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve Loan'));
    await tester.pump();
    expect(repository.reviewCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.completeError(Exception('Active loan already exists'));
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('Approve Loan Application?'), findsOneWidget);
  });

  testWidgets('reviewed details are read only and show admin note', (
    tester,
  ) async {
    final details = _details(
      AdminLoanStatus.rejected,
      note: 'Income verification failed.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoanApplicationDetailsDialog(
            details: details,
            dateFormatter: (_) => '20 Aug 2026',
          ),
        ),
      ),
    );
    expect(find.text('Income verification failed.'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('empty and error states are rendered', (tester) async {
    await tester.pumpWidget(_page(_FakeRepository(items: const [])));
    await tester.pumpAndSettle();
    expect(find.text('No loan applications found'), findsOneWidget);
    await tester.pumpWidget(
      _page(_FakeRepository(error: true), key: const ValueKey('error')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Active and Completed tabs render lifecycle loans and details', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Outstanding BAM'), findsOneWidget);
    expect(find.textContaining('1000.00 BAM'), findsWidgets);
    await tester.tap(find.byTooltip('View Loan').first);
    await tester.pumpAndSettle();
    expect(find.text('Loan Details'), findsOneWidget);
    expect(find.text('Installment Schedule'), findsOneWidget);
    expect(find.text('Payment History'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Completed Loans'), findsOneWidget);
  });

  testWidgets('Active loans show overdue summary filter and details state', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('Loans overdue'), findsOneWidget);
    expect(find.text('2 overdue'), findsOneWidget);

    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Up to date'));
    await tester.pumpAndSettle();
    expect(repository.lastOverdueOnly, isFalse);

    await tester.tap(find.text('Up to date'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Overdue'));
    await tester.pumpAndSettle();
    expect(repository.lastOverdueOnly, isTrue);
    await tester.tap(find.byTooltip('View Loan').first);
    await tester.pumpAndSettle();
    expect(find.text('Overdue amount'), findsOneWidget);
    expect(find.textContaining('5 days overdue'), findsOneWidget);
  });
}

Widget _page(AdminLoanRepository repository, {Key? key}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 1400,
      height: 900,
      child: LoansPage(
        key: key,
        token: 'token',
        defaultPageSize: 20,
        dateFormatter: (_) => '20 Aug 2026',
        repository: repository,
      ),
    ),
  ),
);

AdminLoanApplicationListItem _item(AdminLoanStatus status, String id) =>
    AdminLoanApplicationListItem(
      applicationId: id,
      customerId: 'customer',
      customerName: 'Amira Hadzic',
      customerEmail: 'amira@example.com',
      productName: 'BAM Personal Loan',
      principal: 10000,
      currency: 'BAM',
      termMonths: 36,
      annualInterestRate: 6.5,
      estimatedMonthlyPayment: 306.49,
      status: status,
      submittedAtUtc: DateTime.utc(2026, 8, 20),
    );
AdminLoanApplicationDetails _details(AdminLoanStatus status, {String? note}) =>
    AdminLoanApplicationDetails(
      id: '1',
      status: status,
      submittedAtUtc: DateTime.utc(2026, 8, 20),
      reviewedAtUtc: status == AdminLoanStatus.pending
          ? null
          : DateTime.utc(2026, 8, 21),
      adminNote: note,
      customer: const AdminLoanCustomer(
        id: 'customer',
        firstName: 'Amira',
        lastName: 'Hadzic',
        email: 'amira@example.com',
        status: 'Active',
      ),
      product: const AdminLoanProduct(
        id: 'product',
        name: 'BAM Personal Loan',
        currency: 'BAM',
      ),
      destinationAccount: const AdminLoanDestinationAccount(
        accountId: 'account',
        maskedAccountNumber: '**** 1234',
        accountType: 'Checking',
        currency: 'BAM',
        currentBalance: 2500,
      ),
      financials: const AdminLoanFinancials(
        principal: 10000,
        annualInterestRate: 6.5,
        termMonths: 36,
        estimatedMonthlyPayment: 306.49,
        estimatedTotalInterest: 1033.64,
        estimatedTotalRepayment: 11033.64,
      ),
    );

class _FakeRepository implements AdminLoanRepository {
  _FakeRepository({
    List<AdminLoanApplicationListItem>? items,
    this.error = false,
    this.reviewCompleter,
  }) : items =
           items ??
           [
             _item(AdminLoanStatus.pending, '1'),
             _item(AdminLoanStatus.approved, '2'),
             _item(AdminLoanStatus.rejected, '3'),
           ];
  final List<AdminLoanApplicationListItem> items;
  final bool error;
  final Completer<AdminLoanApplicationDetails>? reviewCompleter;
  String? lastSearch;
  int? lastStatus;
  int reviewCalls = 0;
  bool? lastOverdueOnly;
  @override
  Future<AdminLoanPage> getLoans({
    required String token,
    required int page,
    required int pageSize,
    required int status,
    String? search,
    DateTime? dateFromUtc,
    DateTime? dateToUtc,
    bool? overdueOnly,
  }) async {
    lastOverdueOnly = overdueOnly;
    return AdminLoanPage(
      items: [
        _lifecycle(
          status == 1
              ? AdminLoanLifecycleStatus.active
              : AdminLoanLifecycleStatus.completed,
        ),
      ],
      page: page,
      pageSize: pageSize,
      totalCount: 1,
    );
  }

  @override
  Future<AdminLoansOverview> getLoansOverview({required String token}) async =>
      const AdminLoansOverview(
        totalApplications: 3,
        pendingApplications: 1,
        activeLoans: 1,
        completedLoans: 1,
        loansWithOverduePayments: 1,
        currencies: [
          AdminLoanCurrencySummary(
            currency: 'BAM',
            outstanding: 1000,
            disbursed: 2000,
          ),
        ],
      );
  @override
  Future<AdminLoanDetails> getLoanDetails({
    required String token,
    required String id,
  }) async => _lifecycleDetails();
  @override
  Future<AdminLoanApplicationPage> getApplications({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
    DateTime? dateFromUtc,
    DateTime? dateToUtc,
  }) async {
    if (error) throw Exception('Loan API unavailable');
    lastSearch = search?.isEmpty == true ? null : search;
    lastStatus = status;
    return AdminLoanApplicationPage(
      items: items,
      page: page,
      pageSize: pageSize,
      totalCount: items.length,
    );
  }

  @override
  Future<AdminLoanApplicationDetails> getApplicationDetails({
    required String token,
    required String id,
  }) async =>
      _details(id == '1' ? AdminLoanStatus.pending : AdminLoanStatus.approved);
  @override
  Future<AdminLoanApplicationDetails> approveApplication({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    reviewCalls++;
    if (reviewCompleter != null) return reviewCompleter!.future;
    return _details(AdminLoanStatus.approved, note: adminNote);
  }

  @override
  Future<AdminLoanApplicationDetails> rejectApplication({
    required String token,
    required String id,
    required String adminNote,
  }) async {
    reviewCalls++;
    return _details(AdminLoanStatus.rejected, note: adminNote);
  }

  @override
  Future<AdminLoanSummary> getSummary({
    required String token,
    String? search,
    int? status,
    DateTime? dateFromUtc,
    DateTime? dateToUtc,
  }) async {
    if (error) throw Exception('Loan API unavailable');
    return const AdminLoanSummary(
      totalApplications: 3,
      pendingApplications: 1,
      approvedApplications: 1,
      rejectedApplications: 1,
    );
  }
}

AdminLoanListItem _lifecycle(
  AdminLoanLifecycleStatus status,
) => AdminLoanListItem(
  loanId: 'loan',
  applicationId: 'app',
  customerId: 'customer',
  customerName: 'Amira Hadzic',
  customerEmail: 'amira@example.com',
  productName: 'BAM Personal Loan',
  currency: 'BAM',
  originalPrincipal: 2000,
  outstandingPrincipal: status == AdminLoanLifecycleStatus.active ? 1000 : 0,
  monthlyPayment: 350,
  annualInterestRate: 6.5,
  termMonths: 6,
  totalPaid: status == AdminLoanLifecycleStatus.active ? 1000 : 2100,
  startDateUtc: DateTime.utc(2026, 1),
  nextPaymentDateUtc: status == AdminLoanLifecycleStatus.active
      ? DateTime.utc(2026, 9)
      : null,
  maturityDateUtc: DateTime.utc(2026, 12),
  completedAtUtc: status == AdminLoanLifecycleStatus.completed
      ? DateTime.utc(2026, 8)
      : null,
  status: status,
  paidInstallments: status == AdminLoanLifecycleStatus.active ? 3 : 6,
  remainingInstallments: status == AdminLoanLifecycleStatus.active ? 3 : 0,
  overdueInstallmentsCount: status == AdminLoanLifecycleStatus.active ? 2 : 0,
  totalOverdueAmount: status == AdminLoanLifecycleStatus.active ? 700 : 0,
);
AdminLoanDetails _lifecycleDetails() => AdminLoanDetails(
  loan: _lifecycle(AdminLoanLifecycleStatus.active),
  customerStatus: 'Active',
  totalRepayment: 2100,
  destinationAccount: const AdminLoanDestinationAccount(
    accountId: 'account',
    maskedAccountNumber: '**** 1234',
    accountType: 'Checking',
    currency: 'BAM',
    currentBalance: 2000,
  ),
  applicationSubmittedAtUtc: DateTime.utc(2025, 12),
  applicationReviewedAtUtc: DateTime.utc(2026, 1),
  applicationStatus: AdminLoanStatus.approved,
  applicationRequestedPrincipal: 2000,
  applicationRateSnapshot: 6.5,
  adminNote: 'Approved',
  installments: [
    AdminLoanInstallment(
      number: 1,
      due: DateTime.utc(2026, 2),
      total: 350,
      principal: 320,
      interest: 30,
      remaining: 1680,
      paid: true,
      isOverdue: false,
    ),
    AdminLoanInstallment(
      number: 2,
      due: DateTime.utc(2026, 8),
      total: 350,
      principal: 325,
      interest: 25,
      remaining: 1355,
      paid: false,
      isOverdue: true,
      daysOverdue: 5,
    ),
  ],
  payments: const [],
);
