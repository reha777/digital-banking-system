enum AdminLoanStatus { pending, approved, rejected }

int _integer(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
double _number(Object? value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
AdminLoanStatus _status(Object? value) =>
    switch (value?.toString().toLowerCase()) {
      '2' || 'approved' => AdminLoanStatus.approved,
      '3' || 'rejected' => AdminLoanStatus.rejected,
      _ => AdminLoanStatus.pending,
    };
String adminLoanStatusLabel(AdminLoanStatus value) => switch (value) {
  AdminLoanStatus.pending => 'Pending',
  AdminLoanStatus.approved => 'Approved',
  AdminLoanStatus.rejected => 'Rejected',
};

class AdminLoanApplicationPage {
  const AdminLoanApplicationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });
  factory AdminLoanApplicationPage.fromJson(Map<String, dynamic> json) =>
      AdminLoanApplicationPage(
        items: (json['items'] as List? ?? [])
            .map(
              (item) => AdminLoanApplicationListItem.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(),
        page: _integer(json['page']),
        pageSize: _integer(json['pageSize']),
        totalCount: _integer(json['totalCount']),
      );
  final List<AdminLoanApplicationListItem> items;
  final int page, pageSize, totalCount;
  int get totalPages =>
      totalCount == 0 ? 1 : ((totalCount + pageSize - 1) / pageSize).floor();
}

class AdminLoanApplicationListItem {
  const AdminLoanApplicationListItem({
    required this.applicationId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.productName,
    required this.principal,
    required this.currency,
    required this.termMonths,
    required this.annualInterestRate,
    required this.estimatedMonthlyPayment,
    required this.status,
    required this.submittedAtUtc,
  });
  factory AdminLoanApplicationListItem.fromJson(Map<String, dynamic> json) =>
      AdminLoanApplicationListItem(
        applicationId: json['applicationId']?.toString() ?? '',
        customerId: json['customerId']?.toString() ?? '',
        customerName: json['customerName']?.toString() ?? '',
        customerEmail: json['customerEmail']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        principal: _number(json['principal']),
        currency: json['currency']?.toString() ?? '',
        termMonths: _integer(json['termMonths']),
        annualInterestRate: _number(json['annualInterestRate']),
        estimatedMonthlyPayment: _number(json['estimatedMonthlyPayment']),
        status: _status(json['status']),
        submittedAtUtc:
            DateTime.tryParse(json['submittedAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
  final String applicationId,
      customerId,
      customerName,
      customerEmail,
      productName,
      currency;
  final double principal, annualInterestRate, estimatedMonthlyPayment;
  final int termMonths;
  final AdminLoanStatus status;
  final DateTime submittedAtUtc;
}

class AdminLoanSummary {
  const AdminLoanSummary({
    required this.totalApplications,
    required this.pendingApplications,
    required this.approvedApplications,
    required this.rejectedApplications,
  });
  factory AdminLoanSummary.fromJson(Map<String, dynamic> json) =>
      AdminLoanSummary(
        totalApplications: _integer(json['totalApplications']),
        pendingApplications: _integer(json['pendingApplications']),
        approvedApplications: _integer(json['approvedApplications']),
        rejectedApplications: _integer(json['rejectedApplications']),
      );
  final int totalApplications,
      pendingApplications,
      approvedApplications,
      rejectedApplications;
}

class AdminLoanApplicationDetails {
  const AdminLoanApplicationDetails({
    required this.id,
    required this.status,
    required this.submittedAtUtc,
    this.reviewedAtUtc,
    this.adminNote,
    required this.customer,
    required this.product,
    required this.destinationAccount,
    required this.financials,
  });
  factory AdminLoanApplicationDetails.fromJson(Map<String, dynamic> json) =>
      AdminLoanApplicationDetails(
        id: json['id']?.toString() ?? '',
        status: _status(json['status']),
        submittedAtUtc:
            DateTime.tryParse(json['submittedAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        reviewedAtUtc: DateTime.tryParse(
          json['reviewedAtUtc']?.toString() ?? '',
        ),
        adminNote: json['adminNote']?.toString(),
        customer: AdminLoanCustomer.fromJson(
          json['customer'] as Map<String, dynamic>? ?? {},
        ),
        product: AdminLoanProduct.fromJson(
          json['product'] as Map<String, dynamic>? ?? {},
        ),
        destinationAccount: AdminLoanDestinationAccount.fromJson(
          json['destinationAccount'] as Map<String, dynamic>? ?? {},
        ),
        financials: AdminLoanFinancials.fromJson(
          json['financials'] as Map<String, dynamic>? ?? {},
        ),
      );
  final String id;
  final AdminLoanStatus status;
  final DateTime submittedAtUtc;
  final DateTime? reviewedAtUtc;
  final String? adminNote;
  final AdminLoanCustomer customer;
  final AdminLoanProduct product;
  final AdminLoanDestinationAccount destinationAccount;
  final AdminLoanFinancials financials;
}

class AdminLoanCustomer {
  const AdminLoanCustomer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.status,
  });
  factory AdminLoanCustomer.fromJson(Map<String, dynamic> json) =>
      AdminLoanCustomer(
        id: json['id']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        status: switch (json['status']?.toString()) {
          '1' => 'Active',
          '2' => 'Inactive',
          '3' => 'Blocked',
          final value when value != null => value,
          _ => 'Unknown',
        },
      );
  final String id, firstName, lastName, email, status;
  String get fullName => '$firstName $lastName'.trim();
}

class AdminLoanProduct {
  const AdminLoanProduct({
    required this.id,
    required this.name,
    required this.currency,
  });
  factory AdminLoanProduct.fromJson(Map<String, dynamic> json) =>
      AdminLoanProduct(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        currency: json['currency']?.toString() ?? '',
      );
  final String id, name, currency;
}

class AdminLoanDestinationAccount {
  const AdminLoanDestinationAccount({
    required this.accountId,
    required this.maskedAccountNumber,
    required this.accountType,
    required this.currency,
    required this.currentBalance,
  });
  factory AdminLoanDestinationAccount.fromJson(Map<String, dynamic> json) =>
      AdminLoanDestinationAccount(
        accountId: json['accountId']?.toString() ?? '',
        maskedAccountNumber: json['maskedAccountNumber']?.toString() ?? '',
        accountType: switch (json['accountType']?.toString()) {
          '1' => 'Checking',
          '2' => 'Savings',
          final value when value != null => value,
          _ => 'Account',
        },
        currency: json['currency']?.toString() ?? '',
        currentBalance: _number(json['currentBalance']),
      );
  final String accountId, maskedAccountNumber, accountType, currency;
  final double currentBalance;
}

class AdminLoanFinancials {
  const AdminLoanFinancials({
    required this.principal,
    required this.annualInterestRate,
    required this.termMonths,
    required this.estimatedMonthlyPayment,
    required this.estimatedTotalInterest,
    required this.estimatedTotalRepayment,
  });
  factory AdminLoanFinancials.fromJson(Map<String, dynamic> json) =>
      AdminLoanFinancials(
        principal: _number(json['principal']),
        annualInterestRate: _number(json['annualInterestRate']),
        termMonths: _integer(json['termMonths']),
        estimatedMonthlyPayment: _number(json['estimatedMonthlyPayment']),
        estimatedTotalInterest: _number(json['estimatedTotalInterest']),
        estimatedTotalRepayment: _number(json['estimatedTotalRepayment']),
      );
  final double principal,
      annualInterestRate,
      estimatedMonthlyPayment,
      estimatedTotalInterest,
      estimatedTotalRepayment;
  final int termMonths;
}

enum AdminLoanLifecycleStatus { active, completed }

AdminLoanLifecycleStatus _lifecycleStatus(Object? value) =>
    value?.toString().toLowerCase() == 'completed' || value?.toString() == '2'
    ? AdminLoanLifecycleStatus.completed
    : AdminLoanLifecycleStatus.active;

class AdminLoanPage {
  const AdminLoanPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });
  factory AdminLoanPage.fromJson(Map<String, dynamic> json) => AdminLoanPage(
    items: (json['items'] as List? ?? [])
        .map((e) => AdminLoanListItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    page: _integer(json['page']),
    pageSize: _integer(json['pageSize']),
    totalCount: _integer(json['totalCount']),
  );
  final List<AdminLoanListItem> items;
  final int page, pageSize, totalCount;
  int get totalPages =>
      totalCount == 0 ? 1 : ((totalCount + pageSize - 1) / pageSize).floor();
}

class AdminLoanListItem {
  const AdminLoanListItem({
    required this.loanId,
    required this.applicationId,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.productName,
    required this.currency,
    required this.originalPrincipal,
    required this.outstandingPrincipal,
    required this.monthlyPayment,
    required this.annualInterestRate,
    required this.termMonths,
    required this.totalPaid,
    required this.startDateUtc,
    this.nextPaymentDateUtc,
    required this.maturityDateUtc,
    this.completedAtUtc,
    required this.status,
    required this.paidInstallments,
    required this.remainingInstallments,
  });
  factory AdminLoanListItem.fromJson(Map<String, dynamic> json) =>
      AdminLoanListItem(
        loanId: json['loanId']?.toString() ?? '',
        applicationId: json['applicationId']?.toString() ?? '',
        customerId: json['customerId']?.toString() ?? '',
        customerName: json['customerName']?.toString() ?? '',
        customerEmail: json['customerEmail']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        currency: json['currency']?.toString() ?? '',
        originalPrincipal: _number(json['originalPrincipal']),
        outstandingPrincipal: _number(json['outstandingPrincipal']),
        monthlyPayment: _number(json['monthlyPayment']),
        annualInterestRate: _number(json['annualInterestRate']),
        termMonths: _integer(json['termMonths']),
        totalPaid: _number(json['totalPaid']),
        startDateUtc:
            DateTime.tryParse(json['startDateUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        nextPaymentDateUtc: DateTime.tryParse(
          json['nextPaymentDateUtc']?.toString() ?? '',
        ),
        maturityDateUtc:
            DateTime.tryParse(json['maturityDateUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        completedAtUtc: DateTime.tryParse(
          json['completedAtUtc']?.toString() ?? '',
        ),
        status: _lifecycleStatus(json['status']),
        paidInstallments: _integer(json['paidInstallments']),
        remainingInstallments: _integer(json['remainingInstallments']),
      );
  final String loanId,
      applicationId,
      customerId,
      customerName,
      customerEmail,
      productName,
      currency;
  final double originalPrincipal,
      outstandingPrincipal,
      monthlyPayment,
      annualInterestRate,
      totalPaid;
  final int termMonths, paidInstallments, remainingInstallments;
  final DateTime startDateUtc, maturityDateUtc;
  final DateTime? nextPaymentDateUtc, completedAtUtc;
  final AdminLoanLifecycleStatus status;
}

class AdminLoanInstallment {
  const AdminLoanInstallment({
    required this.number,
    required this.due,
    required this.total,
    required this.principal,
    required this.interest,
    required this.remaining,
    required this.paid,
    this.paidAt,
  });
  factory AdminLoanInstallment.fromJson(Map<String, dynamic> j) =>
      AdminLoanInstallment(
        number: _integer(j['installmentNumber']),
        due:
            DateTime.tryParse(j['dueDateUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        total: _number(j['scheduledAmount']),
        principal: _number(j['principalAmount']),
        interest: _number(j['interestAmount']),
        remaining: _number(j['remainingPrincipalAfter']),
        paid:
            j['status']?.toString().toLowerCase() == 'paid' ||
            j['status']?.toString() == '2',
        paidAt: DateTime.tryParse(j['paidAtUtc']?.toString() ?? ''),
      );
  final int number;
  final DateTime due;
  final double total, principal, interest, remaining;
  final bool paid;
  final DateTime? paidAt;
}

class AdminLoanPayment {
  const AdminLoanPayment({
    required this.number,
    required this.amount,
    required this.principal,
    required this.interest,
    required this.paidAt,
    required this.account,
    required this.reference,
  });
  factory AdminLoanPayment.fromJson(Map<String, dynamic> j) => AdminLoanPayment(
    number: _integer(j['installmentNumber']),
    amount: _number(j['amount']),
    principal: _number(j['principalAmount']),
    interest: _number(j['interestAmount']),
    paidAt:
        DateTime.tryParse(j['paidAtUtc']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    account: j['sourceAccountNumber']?.toString() ?? '',
    reference: j['transactionReference']?.toString() ?? '',
  );
  final int number;
  final double amount, principal, interest;
  final DateTime paidAt;
  final String account, reference;
}

class AdminLoanDetails {
  const AdminLoanDetails({
    required this.loan,
    required this.customerStatus,
    required this.totalRepayment,
    required this.destinationAccount,
    required this.applicationSubmittedAtUtc,
    this.applicationReviewedAtUtc,
    required this.applicationStatus,
    required this.applicationRequestedPrincipal,
    required this.applicationRateSnapshot,
    this.adminNote,
    required this.installments,
    required this.payments,
  });
  factory AdminLoanDetails.fromJson(Map<String, dynamic> j) => AdminLoanDetails(
    loan: AdminLoanListItem.fromJson(j),
    customerStatus: j['customerStatus']?.toString() ?? '',
    totalRepayment: _number(j['totalRepayment']),
    destinationAccount: AdminLoanDestinationAccount.fromJson(
      j['destinationAccount'] as Map<String, dynamic>? ?? {},
    ),
    applicationSubmittedAtUtc:
        DateTime.tryParse(j['applicationSubmittedAtUtc']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    applicationReviewedAtUtc: DateTime.tryParse(
      j['applicationReviewedAtUtc']?.toString() ?? '',
    ),
    applicationStatus: _status(j['applicationStatus']),
    applicationRequestedPrincipal: _number(j['applicationRequestedPrincipal']),
    applicationRateSnapshot: _number(j['applicationRateSnapshot']),
    adminNote: j['adminNote']?.toString(),
    installments: (j['installments'] as List? ?? [])
        .map((e) => AdminLoanInstallment.fromJson(e as Map<String, dynamic>))
        .toList(),
    payments: (j['payments'] as List? ?? [])
        .map((e) => AdminLoanPayment.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  final AdminLoanListItem loan;
  final String customerStatus;
  final double totalRepayment,
      applicationRequestedPrincipal,
      applicationRateSnapshot;
  final AdminLoanDestinationAccount destinationAccount;
  final DateTime applicationSubmittedAtUtc;
  final DateTime? applicationReviewedAtUtc;
  final AdminLoanStatus applicationStatus;
  final String? adminNote;
  final List<AdminLoanInstallment> installments;
  final List<AdminLoanPayment> payments;
}

class AdminLoanCurrencySummary {
  const AdminLoanCurrencySummary({
    required this.currency,
    required this.outstanding,
    required this.disbursed,
  });
  factory AdminLoanCurrencySummary.fromJson(Map<String, dynamic> j) =>
      AdminLoanCurrencySummary(
        currency: j['currency']?.toString() ?? '',
        outstanding: _number(j['outstandingPrincipal']),
        disbursed: _number(j['totalDisbursed']),
      );
  final String currency;
  final double outstanding, disbursed;
}

class AdminLoansOverview {
  const AdminLoansOverview({
    required this.totalApplications,
    required this.pendingApplications,
    required this.activeLoans,
    required this.completedLoans,
    required this.currencies,
  });
  factory AdminLoansOverview.fromJson(Map<String, dynamic> j) =>
      AdminLoansOverview(
        totalApplications: _integer(j['totalApplications']),
        pendingApplications: _integer(j['pendingApplications']),
        activeLoans: _integer(j['activeLoans']),
        completedLoans: _integer(j['completedLoans']),
        currencies: (j['currencies'] as List? ?? [])
            .map(
              (e) =>
                  AdminLoanCurrencySummary.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
  final int totalApplications, pendingApplications, activeLoans, completedLoans;
  final List<AdminLoanCurrencySummary> currencies;
}
