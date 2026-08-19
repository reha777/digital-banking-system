import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/statistics/models/statistics_models.dart';
import 'package:mobile_app/src/features/statistics/statistics_service.dart';
import 'package:mobile_app/src/features/statistics/widgets/statistics_chart.dart';

void main() {
  const response = {
    'accounts': [
      {
        'id': 'a1',
        'accountNumber': '12345678',
        'accountType': 1,
        'balance': 100,
        'currency': 'USD',
      },
      {
        'id': 'a2',
        'accountNumber': '87654321',
        'accountType': 2,
        'balance': 80,
        'currency': 'EUR',
      },
    ],
    'currencySeries': [
      {
        'currency': 'USD',
        'balance': 100,
        'months': [
          {
            'year': 2026,
            'month': 8,
            'income': 40,
            'spending': 12,
            'recentTransactions': [],
          },
        ],
      },
      {
        'currency': 'EUR',
        'balance': 80,
        'months': [
          {
            'year': 2026,
            'month': 8,
            'income': 20,
            'spending': 5,
            'recentTransactions': [],
          },
        ],
      },
    ],
  };

  test(
    'maps accounts, currencies and monthly calculations without mixing currencies',
    () {
      final data = StatisticsData.fromJson(response);
      expect(data.accounts.map((a) => a.accountType), ['Checking', 'Savings']);
      expect(data.currencySeries.map((s) => s.currency), ['USD', 'EUR']);
      expect(data.currencySeries.first.months.first.net, 28);
      expect(data.currencySeries.last.balance, 80);
    },
  );

  test('maps six calendar months including zero months and BAM', () {
    final months = List.generate(
      6,
      (index) => {
        'year': 2026,
        'month': index + 3,
        'income': index == 5 ? 70 : 0,
        'spending': index == 5 ? 30 : 0,
        'recentTransactions': <Object>[],
      },
    );
    final data = StatisticsData.fromJson({
      'accounts': <Object>[],
      'currencySeries': [
        {'currency': 'BAM', 'balance': 500, 'months': months},
      ],
    });
    expect(data.currencySeries.single.months, hasLength(6));
    expect(data.currencySeries.single.currency, 'BAM');
    expect(data.currencySeries.single.months.first.spending, 0);
    expect(data.currencySeries.single.months.last.income, 70);
  });

  test('empty statistics response maps to safe empty collections', () {
    final data = StatisticsData.fromJson(const {});
    expect(data.accounts, isEmpty);
    expect(data.currencySeries, isEmpty);
  });

  test('statistics service sends account and exact period filters', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = StatisticsService(ApiClient(httpClient: client));
    await service.getStatistics(
      token: 'token',
      from: DateTime.utc(2026, 3),
      to: DateTime.utc(2026, 9),
      accountId: 'a1',
    );
    expect(requested.path, '/api/transactions/statistics');
    expect(requested.queryParameters['accountId'], 'a1');
    expect(
      DateTime.parse(requested.queryParameters['from']!),
      DateTime.utc(2026, 3),
    );
    expect(
      DateTime.parse(requested.queryParameters['to']!),
      DateTime.utc(2026, 9),
    );
  });

  test('all accounts omits accountId and API error is propagated', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({'message': 'Statistics unavailable'}),
        503,
      );
    });
    final service = StatisticsService(ApiClient(httpClient: client));
    await expectLater(
      service.getStatistics(
        token: 'token',
        from: DateTime.utc(2026, 3),
        to: DateTime.utc(2026, 9),
      ),
      throwsA(isA<ApiException>()),
    );
    expect(requested.queryParameters.containsKey('accountId'), isFalse);
  });

  testWidgets('chart supports tap selection and renders zero data safely', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          child: StatisticsChart(
            values: const [0, 0, 0, 0, 0, 0],
            selectedIndex: 5,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(StatisticsChart)) + const Offset(2, 40),
    );
    expect(selected, 0);
    expect(tester.takeException(), isNull);
  });

  test('history request retains selected account and month boundaries', () {
    final month = StatisticsData.fromJson(
      response,
    ).currencySeries.first.months.first;
    final request = StatisticsHistoryRequest(
      accountId: 'a1',
      from: month.start,
      to: month.end,
    );
    expect(request.accountId, 'a1');
    expect(request.from, DateTime.utc(2026, 8));
    expect(request.to, DateTime.utc(2026, 9));
  });
}
