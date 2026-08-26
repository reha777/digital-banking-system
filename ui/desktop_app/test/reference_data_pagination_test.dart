import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/reference_data/reference_data_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reference data uses and parses server-side pagination', () async {
    late Uri requested;
    final service = ReferenceDataService(
      ApiClient(
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 'one',
                  'code': 'HOME',
                  'name': 'Home',
                  'description': null,
                  'isActive': true,
                  'sortOrder': 10,
                },
              ],
              'page': 2,
              'pageSize': 10,
              'totalCount': 21,
              'totalPages': 3,
            }),
            200,
          );
        }),
      ),
    );

    final result = await service.get(
      'token',
      'loan-purposes',
      search: 'home',
      active: true,
      page: 2,
      pageSize: 10,
    );

    expect(requested.queryParameters, {
      'search': 'home',
      'isActive': 'true',
      'page': '2',
      'pageSize': '10',
    });
    expect(result.items.single.code, 'HOME');
    expect(result.page, 2);
    expect(result.totalCount, 21);
    expect(result.totalPages, 3);
  });
}
