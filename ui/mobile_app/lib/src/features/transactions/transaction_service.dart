import 'dart:typed_data';

import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'transaction_models.dart';

class TransactionService {
  const TransactionService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BankTransaction>> getRecentTransactions(String token) async {
    final page = await getTransactions(
      token: token,
      page: 1,
      pageSize: 4,
    );

    return page.items;
  }

  Future<PagedTransactions> getTransactions({
    required String token,
    required int page,
    required int pageSize,
  }) async {
    final json = await _apiClient.getJson(
      '${MobileApiEndpoints.transactions}?page=$page&pageSize=$pageSize',
      token: token,
    );

    return PagedTransactions.fromJson(json);
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

  Future<BankTransaction> uploadDocument({
    required String token,
    required String transactionId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _apiClient.postMultipartBytes(
      '${MobileApiEndpoints.transactions}/$transactionId/documents',
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
      token: token,
    );

    return BankTransaction.fromJson(json);
  }
}
