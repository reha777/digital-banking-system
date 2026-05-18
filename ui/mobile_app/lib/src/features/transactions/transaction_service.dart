import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'transaction_models.dart';

class TransactionService {
  const TransactionService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BankTransaction>> getRecentTransactions(String token) async {
    final json = await _apiClient.getJson(
      '${MobileApiEndpoints.transactions}?page=1&pageSize=10',
      token: token,
    );

    return PagedTransactions.fromJson(json).items;
  }

  Future<MoneyTransferResult> sendMoney({
    required String token,
    required String sourceAccountId,
    required String destinationAccountNumber,
    required double amount,
    String? description,
  }) async {
    final json = await _apiClient.postJson(
      MobileApiEndpoints.sendMoney,
      {
        'sourceAccountId': sourceAccountId,
        'destinationAccountNumber': destinationAccountNumber,
        'amount': amount,
        'description': description,
      },
      token: token,
    );

    return MoneyTransferResult.fromJson(json);
  }
}
