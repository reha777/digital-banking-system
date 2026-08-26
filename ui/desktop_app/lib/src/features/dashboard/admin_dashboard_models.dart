import '../transactions/admin_transaction_models.dart';
import '../../core/currency_amount.dart';

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalTransactions,
    required this.completedTransactions,
    required this.transferredByCurrency,
    required this.pendingReviews,
    required this.documentsRequested,
    required this.failedTransactions,
    required this.pendingCardRequests,
    required this.pendingLoanApplications,
    required this.activeLoans,
    required this.overdueLoans,
    required this.recentTransactions,
    required this.periodDays,
    required this.transactionActivity,
  });

  factory AdminDashboardSummary.fromJson(
    Map<String, dynamic> json,
  ) => AdminDashboardSummary(
    totalCustomers: json['totalCustomers'] as int? ?? 0,
    activeCustomers: json['activeCustomers'] as int? ?? 0,
    totalTransactions: json['totalTransactions'] as int? ?? 0,
    completedTransactions: json['completedTransactions'] as int? ?? 0,
    transferredByCurrency: (json['transferredByCurrency'] as List? ?? [])
        .map((item) => CurrencyAmount.fromJson(item as Map<String, dynamic>))
        .toList(),
    pendingReviews: json['pendingTransactionReviews'] as int? ?? 0,
    documentsRequested: json['documentsRequested'] as int? ?? 0,
    failedTransactions: json['failedTransactions'] as int? ?? 0,
    pendingCardRequests: json['pendingCardRequests'] as int? ?? 0,
    pendingLoanApplications: json['pendingLoanApplications'] as int? ?? 0,
    activeLoans: json['activeLoans'] as int? ?? 0,
    overdueLoans: json['loansWithOverduePayments'] as int? ?? 0,
    recentTransactions: (json['recentTransactions'] as List? ?? [])
        .map((item) => AdminTransaction.fromJson(item as Map<String, dynamic>))
        .toList(),
    periodDays: json['periodDays'] as int? ?? 7,
    transactionActivity: (json['transactionActivity'] as List? ?? [])
        .map(
          (item) =>
              TransactionActivityPoint.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );

  final int totalCustomers;
  final int activeCustomers;
  final int totalTransactions;
  final int completedTransactions;
  final List<CurrencyAmount> transferredByCurrency;
  final int pendingReviews;
  final int documentsRequested;
  final int failedTransactions;
  final int pendingCardRequests;
  final int pendingLoanApplications;
  final int activeLoans;
  final int overdueLoans;
  final List<AdminTransaction> recentTransactions;
  final int periodDays;
  final List<TransactionActivityPoint> transactionActivity;
}

class TransactionActivityPoint {
  const TransactionActivityPoint({required this.dateUtc, required this.count});
  factory TransactionActivityPoint.fromJson(Map<String, dynamic> json) =>
      TransactionActivityPoint(
        dateUtc: DateTime.parse(json['dateUtc'].toString()),
        count: json['transactionCount'] as int? ?? 0,
      );
  final DateTime dateUtc;
  final int count;
}
