import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/transactions/admin_transaction_service.dart';
import 'package:desktop_app/src/features/transactions/pages/transactions_page.dart';
import 'package:desktop_app/src/features/transactions/pages/transaction_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'renders all transaction columns with semantic type and currency',
    (tester) async {
      await _pumpTransactions(tester, const Size(1280, 800));

      expect(find.text('Type'), findsNWidgets(2));
      expect(find.text('Internal Transfer'), findsOneWidget);
      expect(find.text('EUR 125.50'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transaction table remains renderable at narrow desktop width', (
    tester,
  ) async {
    await _pumpTransactions(tester, const Size(600, 800));

    expect(find.text('Internal Transfer'), findsOneWidget);
    expect(find.text('EUR 125.50'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens general details and sends semantic type filter', (
    tester,
  ) async {
    final requests = <Uri>[];
    await _pumpTransactions(
      tester,
      const Size(1024, 768),
      service: _service(requests),
    );

    await tester.tap(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Details'), findsOneWidget);
    expect(find.text('Internal Transfer'), findsWidgets);
    expect(find.text('EUR'), findsWidgets);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loan Repayment').last);
    await tester.pumpAndSettle();
    expect(requests.any((uri) => uri.queryParameters['type'] == '4'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction review uses the complete eight-column layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionReviewPage(
            token: 'token',
            defaultPageSize: 20,
            dateFormatter: (_) => '21 Aug 2026',
            service: _service(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Internal Transfer'), findsOneWidget);
    expect(find.text('EUR 125.50'), findsWidgets);
    expect(find.byTooltip('Review details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction review revision reloads the current query', (
    tester,
  ) async {
    final requests = <Uri>[];
    final service = _service(requests);

    Widget page(int revision) => MaterialApp(
      home: Scaffold(
        body: TransactionReviewPage(
          token: 'token',
          defaultPageSize: 20,
          dateFormatter: (_) => '21 Aug 2026',
          service: service,
          refreshRevision: revision,
        ),
      ),
    );

    await tester.pumpWidget(page(0));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));

    await tester.pumpWidget(page(1));
    await tester.pumpAndSettle();
    expect(requests, hasLength(4));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpTransactions(
  WidgetTester tester,
  Size size, {
  AdminTransactionService? service,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final effectiveService = service ?? _service();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TransactionsPage(
          token: 'token',
          defaultPageSize: 20,
          dateFormatter: (_) => '21 Aug 2026',
          service: effectiveService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AdminTransactionService _service([List<Uri>? requests]) {
  final client = MockClient((request) async {
    requests?.add(request.url);
    if (request.url.path.endsWith('/summary')) {
      return http.Response(
        jsonEncode({
          'totalTransactions': 1,
          'completedTransactions': 1,
          'transferredByCurrency': [
            {'currency': 'EUR', 'amount': 125.5},
          ],
        }),
        200,
      );
    }
    if (request.url.path == '/api/transactions/transaction-1') {
      return http.Response(jsonEncode(_transactionJson), 200);
    }
    return http.Response(
      jsonEncode({
        'items': [_transactionJson],
        'page': 1,
        'pageSize': 20,
        'totalCount': 1,
      }),
      200,
    );
  });

  return AdminTransactionService(ApiClient(httpClient: client));
}

const _transactionJson = <String, Object>{
  'id': 'transaction-1',
  'accountNumber': '1000000001',
  'referenceNumber': 'TXN-001',
  'amount': 125.5,
  'currency': 'EUR',
  'type': 2,
  'description': 'Own account transfer',
  'status': 2,
  'sourceAccountNumber': '1000000001',
  'destinationAccountNumber': '1000000002',
  'sourceCustomerName': 'Source Customer',
  'destinationCustomerName': 'Destination Customer',
  'createdAtUtc': '2026-08-21T10:00:00Z',
};
