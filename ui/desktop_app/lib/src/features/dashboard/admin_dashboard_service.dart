import '../../core/api_client.dart';
import '../cards/admin_card_request_service.dart';
import '../customers/admin_customer_service.dart';
import '../transactions/admin_transaction_service.dart';
import 'admin_dashboard_models.dart';

class AdminDashboardService {
  AdminDashboardService(ApiClient apiClient)
    : _transactions = AdminTransactionService(apiClient),
      _customers = AdminCustomerService(apiClient),
      _cardRequests = AdminCardRequestService(apiClient);

  final AdminTransactionService _transactions;
  final AdminCustomerService _customers;
  final AdminCardRequestService _cardRequests;

  Future<AdminDashboardSummary> getSummary({required String token}) async {
    final transactionsFuture = _transactions.getSummary(token: token);
    final reviewsFuture = _transactions.getSummary(
      token: token,
      status: 1,
      highRiskOnly: true,
    );
    final customersFuture = _customers.getSummary(token: token);
    final cardRequestsFuture = _cardRequests.getSummary(token: token);
    final recentFuture = _transactions.getTransactions(
      token: token,
      page: 1,
      pageSize: 5,
    );
    final failedFuture = _transactions.getSummary(token: token, status: 3);
    final documentsFuture = _transactions.getSummary(token: token, status: 5);

    final transactions = await transactionsFuture;
    final reviews = await reviewsFuture;
    final customers = await customersFuture;
    final cardRequests = await cardRequestsFuture;
    final recent = await recentFuture;
    final failed = await failedFuture;
    final documents = await documentsFuture;

    return AdminDashboardSummary(
      totalCustomers: customers.totalCustomers,
      activeCustomers: customers.activeCustomers,
      totalTransactions: transactions.totalTransactions,
      totalTransferred: transactions.totalTransferred,
      pendingReviews: reviews.totalTransactions,
      documentsRequested: documents.totalTransactions,
      failedTransactions: failed.totalTransactions,
      pendingCardRequests: cardRequests.pendingRequests,
      recentTransactions: recent.items,
    );
  }
}
