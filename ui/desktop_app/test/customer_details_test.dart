import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/customers/admin_customer_service.dart';
import 'package:desktop_app/src/features/customers/customer_details_service.dart';
import 'package:desktop_app/src/features/customers/pages/customers_page.dart';
import 'package:desktop_app/src/features/customers/pages/customer_details_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('opens Customer 360 and lazy-loads all real data tabs', (
    tester,
  ) async {
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return _response(request.url);
    });
    final api = ApiClient(httpClient: client);
    tester.view.physicalSize = const Size(1180, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomersPage(
            token: 'token',
            defaultPageSize: 20,
            dateFormatter: (_) => '21 Aug 2026',
            service: AdminCustomerService(api),
            detailsService: CustomerDetailsService(api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View customer'));
    await tester.pumpAndSettle();

    expect(find.text('Customer Alpha With A Very Long Name'), findsOneWidget);
    expect(find.text('BAM 300.00'), findsOneWidget);
    expect(find.text('EUR 200.00'), findsOneWidget);
    expect(find.text('USD 150.00'), findsOneWidget);
    expect(requested.where((uri) => uri.path == '/api/transactions'), isEmpty);
    expect(find.text('Edit Customer'), findsOneWidget);
    await tester.tap(find.text('Edit Customer'));
    await tester.pumpAndSettle();
    expect(find.text('Edit customer'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accounts & Cards'));
    await tester.pumpAndSettle();
    expect(find.text('**** **** **** 3456'), findsOneWidget);
    expect(find.text('No card issued'), findsOneWidget);
    expect(find.textContaining('999'), findsNothing);

    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Internal Transfer'), findsOneWidget);
    expect(find.text('EUR 125.50'), findsOneWidget);
    expect(requested.last.queryParameters['customerId'], 'customer-a');
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(requested.last.queryParameters['page'], '2');

    await tester.tap(find.text('Loans'));
    await tester.pumpAndSettle();
    expect(find.text('Active Loans'), findsOneWidget);
    expect(find.text('Personal Loan'), findsWidgets);
    expect(find.textContaining('of 21 records'), findsNWidgets(3));
    await tester.tap(find.byTooltip('Next page').first);
    await tester.pumpAndSettle();
    expect(
      requested
          .lastWhere((uri) => uri.path == '/api/admin/loans')
          .queryParameters['page'],
      '2',
    );

    await tester.drag(
      find
          .ancestor(of: find.text('Overview'), matching: find.byType(ListView))
          .first,
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('USD card request'), findsOneWidget);
    expect(find.text('RISK-001'), findsOneWidget);
    expect(find.textContaining('of 21 requests'), findsOneWidget);
    expect(find.textContaining('of 21 reviews'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Customer 360 shows isolated empty tab state at narrow width', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/admin/customers/customer-a') {
        return _details();
      }
      if (request.url.path == '/api/admin/customers/summary') return _summary();
      if (request.url.path == '/api/admin/customers') return _customers();
      return http.Response(
        jsonEncode({'items': [], 'page': 1, 'pageSize': 10, 'totalCount': 0}),
        200,
      );
    });
    final api = ApiClient(httpClient: client);
    tester.view.physicalSize = const Size(700, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomersPage(
            token: 'token',
            defaultPageSize: 20,
            dateFormatter: (_) => '21 Aug 2026',
            service: AdminCustomerService(api),
            detailsService: CustomerDetailsService(api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    await tester.drag(
      find
          .ancestor(of: find.text('Overview'), matching: find.byType(ListView))
          .first,
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('No transactions found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core details error is retryable without losing the feature', (
    tester,
  ) async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      return attempts == 1
          ? http.Response('{"message":"temporary"}', 500)
          : _details();
    });
    final api = ApiClient(httpClient: client);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerDetailsPage(
            token: 'token',
            customerId: 'customer-a',
            dateFormatter: (_) => '21 Aug 2026',
            onBack: () {},
            onCustomerUpdated: () {},
            service: CustomerDetailsService(api),
            customerService: AdminCustomerService(api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load customer details.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Customer Alpha With A Very Long Name'), findsOneWidget);
    expect(attempts, 2);
  });
}

http.Response _response(Uri uri) {
  if (uri.path == '/api/admin/customers/customer-a') return _details();
  if (uri.path == '/api/admin/customers/summary') return _summary();
  if (uri.path == '/api/admin/customers') return _customers();
  if (uri.path == '/api/transactions') {
    final review = uri.queryParameters['highRiskOnly'] == 'true';
    return http.Response(
      jsonEncode({
        'items': [review ? _reviewJson() : _transactionJson()],
        'page': int.parse(uri.queryParameters['page'] ?? '1'),
        'pageSize': 10,
        'totalCount': review ? 21 : 11,
      }),
      200,
    );
  }
  if (uri.path == '/api/admin/card-requests') {
    return http.Response(
      jsonEncode({
        'items': [_cardRequestJson()],
        'page': int.parse(uri.queryParameters['page'] ?? '1'),
        'pageSize': int.parse(uri.queryParameters['pageSize'] ?? '10'),
        'totalCount': 21,
      }),
      200,
    );
  }
  if (uri.path == '/api/admin/loans/applications') {
    return http.Response(
      jsonEncode({
        'items': [_applicationJson()],
        'page': int.parse(uri.queryParameters['page'] ?? '1'),
        'pageSize': int.parse(uri.queryParameters['pageSize'] ?? '10'),
        'totalCount': 21,
      }),
      200,
    );
  }
  if (uri.path == '/api/admin/loans') {
    return http.Response(
      jsonEncode({
        'items': [_loanJson(int.parse(uri.queryParameters['status']!))],
        'page': int.parse(uri.queryParameters['page'] ?? '1'),
        'pageSize': int.parse(uri.queryParameters['pageSize'] ?? '10'),
        'totalCount': 21,
      }),
      200,
    );
  }
  return http.Response('{}', 404);
}

http.Response _customers() => http.Response(
  jsonEncode({
    'items': [_customerJson()],
    'page': 1,
    'pageSize': 20,
    'totalCount': 1,
  }),
  200,
);
http.Response _summary() => http.Response(
  jsonEncode({
    'totalCustomers': 1,
    'activeCustomers': 1,
    'inactiveCustomers': 0,
    'blockedCustomers': 0,
  }),
  200,
);
http.Response _details() => http.Response(
  jsonEncode({
    ..._customerJson(),
    'summary': {
      'accountCount': 2,
      'cardCount': 1,
      'activeLoanCount': 1,
      'pendingCardRequestCount': 1,
      'pendingTransactionReviewCount': 1,
      'pendingLoanApplicationCount': 1,
    },
    'accounts': [
      {
        'id': 'account-1',
        'accountNumber': '10000001',
        'accountType': 1,
        'balance': 150,
        'currency': 'USD',
        'createdAtUtc': '2026-01-01T00:00:00Z',
        'card': {
          'id': 'card-1',
          'maskedCardNumber': '**** **** **** 3456',
          'cardholderName': 'Customer Alpha',
          'expiryDate': '2030-06-01T00:00:00Z',
          'brand': 2,
          'status': 1,
          'createdAtUtc': '2026-01-01T00:00:00Z',
        },
      },
      {
        'id': 'account-2',
        'accountNumber': '10000002',
        'accountType': 2,
        'balance': 200,
        'currency': 'EUR',
        'createdAtUtc': '2026-01-01T00:00:00Z',
        'card': null,
      },
    ],
  }),
  200,
);
Map<String, dynamic> _customerJson() => {
  'id': 'customer-a',
  'firstName': 'Customer Alpha With',
  'lastName': 'A Very Long Name',
  'fullName': 'Customer Alpha With A Very Long Name',
  'email': 'a.very.long.customer.email.address@example.com',
  'phoneNumber': '+38761123456',
  'status': 1,
  'accountCount': 2,
  'balances': [
    {'currency': 'BAM', 'amount': 300},
    {'currency': 'EUR', 'amount': 200},
    {'currency': 'USD', 'amount': 150},
  ],
  'createdAtUtc': '2026-01-01T00:00:00Z',
};
Map<String, dynamic> _transactionJson() => {
  'id': 'tx',
  'accountNumber': '1001',
  'referenceNumber': 'TX-001',
  'amount': 125.5,
  'currency': 'EUR',
  'type': 2,
  'description': 'Transfer',
  'status': 2,
  'createdAtUtc': '2026-08-21T00:00:00Z',
};
Map<String, dynamic> _reviewJson() => {
  ..._transactionJson(),
  'referenceNumber': 'RISK-001',
  'status': 1,
  'isHighRiskReview': true,
  'reviewReason': 'High value',
};
Map<String, dynamic> _cardRequestJson() => {
  'id': 'request',
  'customerName': 'Customer Alpha',
  'customerEmail': 'alpha@test.com',
  'cardholderName': 'Customer Alpha',
  'currency': 'USD',
  'documentNumber': 'DOC',
  'deliveryAddress': 'Address',
  'note': '',
  'status': 1,
  'adminNote': 'Review identity',
  'documents': [],
  'createdAtUtc': '2026-08-21T00:00:00Z',
};
Map<String, dynamic> _applicationJson() => {
  'applicationId': 'app',
  'customerId': 'customer-a',
  'customerName': 'Customer Alpha',
  'customerEmail': 'alpha@test.com',
  'productName': 'Personal Loan',
  'principal': 1000,
  'currency': 'USD',
  'termMonths': 12,
  'annualInterestRate': 5,
  'estimatedMonthlyPayment': 90,
  'status': 1,
  'submittedAtUtc': '2026-08-21T00:00:00Z',
};
Map<String, dynamic> _loanJson(int status) => {
  'loanId': 'loan-$status',
  'applicationId': 'app',
  'customerId': 'customer-a',
  'customerName': 'Customer Alpha',
  'customerEmail': 'alpha@test.com',
  'productName': 'Personal Loan',
  'currency': 'USD',
  'originalPrincipal': 1000,
  'outstandingPrincipal': status == 1 ? 800 : 0,
  'monthlyPayment': 90,
  'annualInterestRate': 5,
  'termMonths': 12,
  'totalPaid': status == 1 ? 200 : 1080,
  'startDateUtc': '2026-01-01T00:00:00Z',
  'nextPaymentDateUtc': status == 1 ? '2026-09-01T00:00:00Z' : null,
  'maturityDateUtc': '2027-01-01T00:00:00Z',
  'completedAtUtc': status == 2 ? '2026-08-01T00:00:00Z' : null,
  'status': status,
  'paidInstallments': status == 1 ? 2 : 12,
  'remainingInstallments': status == 1 ? 10 : 0,
};
