import 'dart:typed_data';

import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'transaction_models.dart';

class TransactionService {
  const TransactionService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BankTransaction>> getRecentTransactions(String token) async {
    final page = await getTransactions(token: token, page: 1, pageSize: 4);

    return page.items;
  }

  Future<PagedTransactions> getTransactions({
    required String token,
    required int page,
    required int pageSize,
    String? accountId,
  }) async {
    final accountQuery = accountId == null
        ? ''
        : '&accountId=${Uri.encodeQueryComponent(accountId)}';
    final json = await _apiClient.getJson(
      '${MobileApiEndpoints.transactions}?page=$page&pageSize=$pageSize$accountQuery',
      token: token,
    );

    return PagedTransactions.fromJson(json);
  }

  Future<MoneyTransferResult> sendMoney({
    required String token,
    required String sourceAccountId,
    required String destinationAccountNumber,
    required double amount,
    required String currency,
    String? description,
  }) async {
    final json = await _apiClient.postJson(MobileApiEndpoints.sendMoney, {
      'sourceAccountId': sourceAccountId,
      'destinationAccountNumber': destinationAccountNumber,
      'amount': amount,
      'currency': currency,
      'description': description,
    }, token: token);

    return MoneyTransferResult.fromJson(json);
  }

  Future<MoneyTransferQuote> getTransferQuote({
    required String token,
    required String sourceAccountId,
    required String destinationAccountNumber,
    required double amount,
    required String currency,
  }) async {
    final json = await _apiClient.postJson(MobileApiEndpoints.transferQuote, {
      'sourceAccountId': sourceAccountId,
      'destinationAccountNumber': destinationAccountNumber,
      'amount': amount,
      'currency': currency,
    }, token: token);
    return MoneyTransferQuote.fromJson(json);
  }

  Future<List<RecentRecipient>> getRecentRecipients(String token) async {
    final json = await _apiClient.getJsonList(
      MobileApiEndpoints.recentRecipients,
      token: token,
    );
    return json.map(RecentRecipient.fromJson).toList();
  }

  Future<RecentRecipient> lookupRecipient({
    required String token,
    required String accountNumber,
  }) async {
    final encoded = Uri.encodeQueryComponent(accountNumber.trim());
    final json = await _apiClient.getJson(
      '${MobileApiEndpoints.recipientLookup}?accountNumber=$encoded',
      token: token,
    );
    return RecentRecipient.fromJson(json);
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
