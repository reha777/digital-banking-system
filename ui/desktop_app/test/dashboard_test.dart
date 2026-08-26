import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/admin_shell/admin_section.dart';
import 'package:desktop_app/src/features/auth/auth_models.dart';
import 'package:desktop_app/src/features/dashboard/admin_dashboard_overview.dart';
import 'package:desktop_app/src/features/dashboard/admin_dashboard_screen.dart';
import 'package:desktop_app/src/features/dashboard/admin_dashboard_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'aggregate dashboard renders KPIs currency loans recent and attention',
    (tester) async {
      final requests = <Uri>[];
      var loans = 0, reviews = 0, cards = 0;
      final service = AdminDashboardService(
        ApiClient(
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response(jsonEncode(_dashboardJson), 200);
          }),
        ),
      );
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardOverview(
              token: 'token',
              service: service,
              onViewTransactions: () {},
              onViewLoans: () => loans++,
              onViewReviews: () => reviews++,
              onViewCardRequests: () => cards++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.path, '/api/admin/dashboard');
      expect(requests.single.queryParameters['periodDays'], '7');
      expect(find.text('Transaction activity'), findsOneWidget);
      expect(find.text('Operational overview'), findsOneWidget);
      expect(find.text('Completed volume'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('3 active'), findsOneWidget);
      expect(find.textContaining('BAM 100.00'), findsOneWidget);
      expect(find.textContaining('EUR 25.00'), findsWidgets);
      expect(find.textContaining('TX-RECENT'), findsOneWidget);
      expect(find.textContaining('Internal Transfer'), findsOneWidget);
      await tester.tap(find.text('30D'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last.queryParameters['periodDays'], '30');
      await tester.tap(find.byTooltip('Refresh dashboard'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(3));
      final pendingLoans = find.byKey(
        const ValueKey('Pending loan applications'),
      );
      await tester.ensureVisible(pendingLoans);
      await tester.pumpAndSettle();
      await tester.tap(pendingLoans);
      final reviewsFinder = find.byKey(const ValueKey('High-risk reviews'));
      await tester.ensureVisible(reviewsFinder);
      await tester.pumpAndSettle();
      await tester.tap(reviewsFinder);
      final cardsFinder = find.byKey(const ValueKey('Pending card requests'));
      await tester.ensureVisible(cardsFinder);
      await tester.pumpAndSettle();
      await tester.tap(cardsFinder);
      expect((loans, reviews, cards), (1, 1, 1));
      expect(find.text('Overdue loans'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dashboard error is safe and retry performs one new aggregate call',
    (tester) async {
      var calls = 0;
      final service = AdminDashboardService(
        ApiClient(
          httpClient: MockClient((_) async {
            calls++;
            return calls == 1
                ? http.Response(
                    '{"message":"SQL Exception https://internal"}',
                    500,
                  )
                : http.Response(jsonEncode(_dashboardJson), 200);
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardOverview(
              token: 'token',
              service: service,
              onViewTransactions: () {},
              onViewLoans: () {},
              onViewReviews: () {},
              onViewCardRequests: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dashboard data could not be loaded.'), findsOneWidget);
      expect(find.textContaining('SQL'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Customers · 9 active'), findsOneWidget);
    },
  );

  testWidgets('header hides future actions and keyword router includes loans', (
    tester,
  ) async {
    AdminSection? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDashboardScreen(
            token: 'token',
            onNavigate: (value) => selected = value,
            user: const AuthUser(
              id: 'a',
              firstName: 'Admin',
              lastName: 'User',
              email: 'a@test.com',
              role: 'Admin',
            ),
            onOpenProfile: () {},
            onOpenPreferences: () {},
            onOpenSecurity: () {},
            onLogout: () {},
          ),
        ),
      ),
    );
    expect(find.byTooltip('Notifications'), findsNothing);
    expect(find.byTooltip('Messages'), findsNothing);
    await tester.enterText(find.byType(TextField), 'loans');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(selected, AdminSection.loans);
  });

  testWidgets('zero activity remains stable at narrow dashboard width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = AdminDashboardService(
      ApiClient(
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode(_zeroDashboardJson), 200),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDashboardOverview(
            token: 'token',
            service: service,
            onViewTransactions: () {},
            onViewLoans: () {},
            onViewReviews: () {},
            onViewCardRequests: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No transaction activity in this period.'),
      findsOneWidget,
    );
    expect(find.text('Operational overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _dashboardJson = {
  'periodDays': 7,
  'transactionActivity': [
    {'dateUtc': '2026-08-16T00:00:00Z', 'transactionCount': 0},
    {'dateUtc': '2026-08-17T00:00:00Z', 'transactionCount': 2},
    {'dateUtc': '2026-08-18T00:00:00Z', 'transactionCount': 4},
    {'dateUtc': '2026-08-19T00:00:00Z', 'transactionCount': 1},
    {'dateUtc': '2026-08-20T00:00:00Z', 'transactionCount': 3},
    {'dateUtc': '2026-08-21T00:00:00Z', 'transactionCount': 5},
    {'dateUtc': '2026-08-22T00:00:00Z', 'transactionCount': 2},
  ],
  'totalCustomers': 12,
  'activeCustomers': 9,
  'totalTransactions': 42,
  'completedTransactions': 35,
  'failedTransactions': 2,
  'transferredByCurrency': [
    {'currency': 'BAM', 'amount': 100},
    {'currency': 'EUR', 'amount': 25},
  ],
  'pendingTransactionReviews': 4,
  'documentsRequested': 1,
  'pendingCardRequests': 2,
  'pendingLoanApplications': 5,
  'activeLoans': 3,
  'loansWithOverduePayments': 1,
  'recentTransactions': [
    {
      'id': 'tx',
      'accountNumber': '1001',
      'referenceNumber': 'TX-RECENT',
      'amount': 25,
      'currency': 'EUR',
      'type': 2,
      'description': 'Transfer',
      'status': 2,
      'isHighRiskReview': false,
      'createdAtUtc': '2026-08-22T00:00:00Z',
    },
  ],
};

final _zeroDashboardJson = {
  ..._dashboardJson,
  'transactionActivity': [
    for (var day = 16; day <= 22; day++)
      {
        'dateUtc': '2026-08-${day.toString().padLeft(2, '0')}T00:00:00Z',
        'transactionCount': 0,
      },
  ],
};
