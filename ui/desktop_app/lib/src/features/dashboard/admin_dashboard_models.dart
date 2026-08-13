import '../transactions/admin_transaction_models.dart';

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.totalTransactions,
    required this.totalTransferred,
    required this.pendingReviews,
    required this.documentsRequested,
    required this.failedTransactions,
    required this.pendingCardRequests,
    required this.recentTransactions,
  });

  final int totalCustomers;
  final int activeCustomers;
  final int totalTransactions;
  final double totalTransferred;
  final int pendingReviews;
  final int documentsRequested;
  final int failedTransactions;
  final int pendingCardRequests;
  final List<AdminTransaction> recentTransactions;
}
