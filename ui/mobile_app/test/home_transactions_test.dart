import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';

void main() {
  test('home recent query uses active account id and page size four', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'items': <Object>[],
          'page': 1,
          'pageSize': 4,
          'totalCount': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await TransactionService(ApiClient(httpClient: client)).getTransactions(
      token: 'token',
      page: 1,
      pageSize: 4,
      accountId: 'active-account-id',
    );

    expect(requested.queryParameters['page'], '1');
    expect(requested.queryParameters['pageSize'], '4');
    expect(requested.queryParameters['accountId'], 'active-account-id');
  });
}
