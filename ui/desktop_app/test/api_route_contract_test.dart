import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/notifications/notification_service.dart';
import 'package:desktop_app/src/features/reports/report_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'notification service uses the backend notification route contract',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('unread-count')) {
            return http.Response(jsonEncode({'count': 3}), 200);
          }
          return http.Response(
            jsonEncode({'items': <Object>[], 'totalCount': 0}),
            200,
          );
        }),
      );
      final service = NotificationService(client);

      expect(await service.unreadCount('token'), 3);
      await service.list('token', page: 2, pageSize: 5, unreadOnly: true);

      expect(requests[0].url.path, '/api/notifications/unread-count');
      expect(requests[1].url.path, '/api/notifications');
      expect(requests[1].url.queryParameters, {
        'page': '2',
        'pageSize': '5',
        'unreadOnly': 'true',
      });
    },
  );

  test('report service uses exact list and create routes', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'id': 'report-1',
              'type': 'TransactionReport',
              'status': 'Queued',
              'requestedBy': 'Admin',
              'requestedAtUtc': '2026-08-24T10:00:00Z',
              'downloadAvailable': false,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'items': <Object>[], 'totalCount': 0}),
          200,
        );
      }),
    );
    final service = ReportService(client);

    await service.list('token');
    await service.create('token', 'transactions', const {});

    expect(requests[0].url.path, '/api/admin/reports');
    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/api/admin/reports/transactions');
  });
}
