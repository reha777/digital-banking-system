import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/cards/card_service.dart';
import 'package:mobile_app/src/features/loans/loan_service.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';

void main() {
  test(
    'mobile list consumers parse paged responses with bounded requests',
    () async {
      final requested = <Uri>[];
      final api = ApiClient(
        httpClient: MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            jsonEncode({
              'items': <Object>[],
              'page': 1,
              'pageSize': 100,
              'totalCount': 0,
              'totalPages': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      expect(await CardService(api).getMyCards('token'), isEmpty);
      expect(await LoanService(api).getProducts('token'), isEmpty);
      expect(await LoanService(api).getLoanPurposes('token'), isEmpty);
      expect(
        await TransactionService(api).getRecentRecipients('token'),
        isEmpty,
      );

      expect(requested[0].queryParameters, {'page': '1', 'pageSize': '100'});
      expect(requested[1].queryParameters, {'page': '1', 'pageSize': '100'});
      expect(requested[2].queryParameters, {'page': '1', 'pageSize': '100'});
      expect(requested[3].queryParameters, {'page': '1', 'pageSize': '8'});
    },
  );
}
