import '../../core/api_client.dart';
import '../cards/admin_card_request_models.dart';
import '../loans/models/admin_loan_models.dart';
import '../transactions/admin_transaction_models.dart';
import 'customer_details_models.dart';

class CustomerDetailsService {
  const CustomerDetailsService(this._client);
  final ApiClient _client;

  Future<AdminCustomerDetails> getDetails(String token, String id) async =>
      AdminCustomerDetails.fromJson(
        await _client.getJson('/api/admin/customers/$id', token: token),
      );

  Future<AdminTransactionPage> getTransactions({
    required String token,
    required String customerId,
    required int page,
    required int pageSize,
    bool reviewsOnly = false,
  }) async => AdminTransactionPage.fromJson(
    await _client.getJson(
      Uri(
        path: '/api/transactions',
        queryParameters: {
          'customerId': customerId,
          'page': '$page',
          'pageSize': '$pageSize',
          if (reviewsOnly) 'highRiskOnly': 'true',
        },
      ).toString(),
      token: token,
    ),
  );

  Future<AdminLoanPage> getLoans({
    required String token,
    required String customerId,
    required int status,
    required int page,
    required int pageSize,
  }) async => AdminLoanPage.fromJson(
    await _client.getJson(
      Uri(
        path: '/api/admin/loans',
        queryParameters: {
          'customerId': customerId,
          'status': '$status',
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ).toString(),
      token: token,
    ),
  );

  Future<AdminLoanApplicationPage> getLoanApplications({
    required String token,
    required String customerId,
    required int page,
    required int pageSize,
  }) async => AdminLoanApplicationPage.fromJson(
    await _client.getJson(
      Uri(
        path: '/api/admin/loans/applications',
        queryParameters: {
          'customerId': customerId,
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ).toString(),
      token: token,
    ),
  );

  Future<AdminCardRequestPage> getCardRequests({
    required String token,
    required String customerId,
    required int page,
    required int pageSize,
  }) async => AdminCardRequestPage.fromJson(
    await _client.getJson(
      Uri(
        path: '/api/admin/card-requests',
        queryParameters: {
          'customerId': customerId,
          'page': '$page',
          'pageSize': '$pageSize',
        },
      ).toString(),
      token: token,
    ),
  );

  Future<AdminLoanDetails> getLoanDetails({
    required String token,
    required String id,
  }) async => AdminLoanDetails.fromJson(
    await _client.getJson('/api/admin/loans/$id', token: token),
  );

  Future<AdminLoanApplicationDetails> getLoanApplicationDetails({
    required String token,
    required String id,
  }) async => AdminLoanApplicationDetails.fromJson(
    await _client.getJson('/api/admin/loans/applications/$id', token: token),
  );
}
