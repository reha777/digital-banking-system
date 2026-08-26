import 'dart:typed_data';
import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/cards/admin_card_request_service.dart';
import 'package:desktop_app/src/features/cards/admin_card_request_models.dart';
import 'package:desktop_app/src/features/cards/widgets/card_request_details_dialog.dart';
import 'package:desktop_app/src/features/cards/widgets/card_request_filters.dart';
import 'package:desktop_app/src/features/cards/widgets/issued_cards_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('approved request shows safe issued account and card result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardRequestDetailsDialog(
            request: _approvedRequest,
            onApprove: () async => true,
            onReject: () async => true,
            onRequestDocuments: (_) async => true,
            onSelectDocument: (_) async => Uint8List(0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Issued result'), findsOneWidget);
    expect(find.text('BA-123456-CHECKING'), findsOneWidget);
    expect(find.text('**** **** **** 7852'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.textContaining('1234567890127852'), findsNothing);
    expect(find.textContaining('CVV'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card request filters expose shared date range and clear', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CardRequestFilters(
            searchController: TextEditingController(),
            status: null,
            dateRange: DateTimeRange(
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 8, 21),
            ),
            onSearchChanged: (_) {},
            onStatusChanged: (_) {},
            onDateChanged: (value) => cleared = value == null,
            onRefresh: () {},
            onReset: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Clear date range'));
    expect(cleared, isTrue);
  });

  testWidgets('issued cards page size resets page and reaches backend', (
    tester,
  ) async {
    final requests = <Uri>[];
    final service = AdminCardRequestService(
      ApiClient(
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final size = int.parse(request.url.queryParameters['pageSize']!);
          return http.Response(
            jsonEncode({
              'items': [_issuedCardJson()],
              'page': int.parse(request.url.queryParameters['page']!),
              'pageSize': size,
              'totalCount': 80,
            }),
            200,
          );
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IssuedCardsView(
            token: 'token',
            pageSize: 20,
            dateFormatter: (_) => 'date',
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['page'], '1');
    expect(requests.last.queryParameters['pageSize'], '50');
  });
}

Map<String, dynamic> _issuedCardJson() => {
  'id': 'card',
  'customerId': 'customer',
  'customerName': 'Customer',
  'accountId': 'account',
  'accountNumber': '10000001',
  'maskedCardNumber': '**** **** **** 1234',
  'brand': 2,
  'status': 1,
  'currency': 'USD',
  'expiryDate': '2030-01-01T00:00:00Z',
  'createdAtUtc': '2026-01-01T00:00:00Z',
};

final _approvedRequest = AdminCardRequest(
  id: 'request-1',
  customerName: 'Demo Customer',
  customerEmail: 'demo@example.com',
  cardholderName: 'Demo Customer',
  currency: 'USD',
  documentNumber: 'DOC-1',
  deliveryAddress: 'Test Address',
  note: '',
  status: 'Approved',
  statusValue: 2,
  createdAtUtc: DateTime.utc(2026, 8, 20),
  documents: const [],
  approvedAccountNumber: 'BA-123456-CHECKING',
  approvedMaskedCardNumber: '**** **** **** 7852',
  approvedCardBrand: 'Mastercard',
  approvedCardStatus: 'Active',
  approvedCardExpiryDate: DateTime.utc(2030, 8, 1),
);
