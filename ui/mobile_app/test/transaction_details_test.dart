import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/transactions/pages/transaction_details_page.dart';
import 'package:mobile_app/src/features/transactions/pages/transaction_history_screen.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:mobile_app/src/features/transactions/transaction_service.dart';
import 'package:mobile_app/src/features/transactions/widgets/transaction_tile.dart';

/// Professor item 14: a transaction in the history list must open its detail,
/// loaded from GET /api/transactions/{id}.
void main() {
  testWidgets('tapping a history tile opens the transaction detail', (
    tester,
  ) async {
    final service = _FakeTransactionService(_transaction());
    await tester.pumpWidget(
      MaterialApp(
        home: TransactionHistoryScreen(
          session: _session(),
          transactionService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The tile is genuinely interactive, not just visually clickable.
    final tile = tester.widget<TransactionHistoryTile>(
      find.byType(TransactionHistoryTile),
    );
    expect(tile.onTap, isNotNull);

    await tester.tap(find.byType(TransactionHistoryTile));
    await tester.pumpAndSettle();

    expect(find.text('Transaction Details'), findsOneWidget);
    // The detail was fetched by id, not reused from the list summary.
    expect(service.requestedIds, ['transaction-1']);

    // Back keeps the history working.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TransactionHistoryTile), findsOneWidget);
  });

  testWidgets('the detail shows a loading state, then the key fields', (
    tester,
  ) async {
    final service = _FakeTransactionService(_transaction());
    await tester.pumpWidget(_detailApp(service));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(service.requestedIds, ['transaction-1']);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('TRX-2026-0001'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.textContaining('120.50'), findsWidgets);
    expect(find.textContaining('BAM'), findsWidgets);
  });

  testWidgets('the date uses DD.MM.YYYY HH:mm, never a raw ISO string', (
    tester,
  ) async {
    final service = _FakeTransactionService(_transaction());
    await tester.pumpWidget(_detailApp(service));
    await tester.pumpAndSettle();

    final local = DateTime.utc(2026, 9, 9, 13, 52).toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final expected =
        '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';

    expect(find.text(expected), findsOneWidget);
    expect(find.textContaining('2026-09-09T'), findsNothing);
    expect(find.textContaining('Z'), findsNothing);
  });

  testWidgets('a failed detail fetch shows a controlled error with retry', (
    tester,
  ) async {
    final service = _FakeTransactionService(_transaction())..failNext = true;
    await tester.pumpWidget(_detailApp(service));
    await tester.pumpAndSettle();

    expect(find.text('Transaction could not be found.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('TRX-2026-0001'), findsOneWidget);
  });

  test('transaction timestamps parse zone-less API values as UTC', () {
    final value = BankTransaction.fromJson(_transactionJson);

    expect(value.createdAtUtc.isUtc, isTrue);
    expect(value.createdAtUtc, DateTime.utc(2026, 9, 9, 13, 52));
  });
}

Widget _detailApp(TransactionService service) => MaterialApp(
  home: TransactionDetailsPage(
    session: _session(),
    transactionId: 'transaction-1',
    transactionService: service,
  ),
);

AuthSession _session() => AuthSession(ApiClient())
  ..token = 'customer-token'
  ..user = const AuthUser(
    id: 'customer-1',
    firstName: 'Test',
    lastName: 'Customer',
    email: 'customer@test.local',
    role: 'Customer',
  );

const _transactionJson = {
  'id': 'transaction-1',
  'accountId': 'account-1',
  'accountNumber': '10000001',
  'referenceNumber': 'TRX-2026-0001',
  'amount': -120.50,
  'description': 'Groceries',
  'status': 'Completed',
  'isHighRiskReview': false,
  'currency': 'BAM',
  'type': 'Transfer',
  'sourceAccountNumber': '10000001',
  'destinationAccountNumber': '10000002',
  // SQL datetime2 serializes UTC without a trailing Z.
  'createdAtUtc': '2026-09-09T13:52:00',
};

BankTransaction _transaction() => BankTransaction.fromJson(_transactionJson);

class _FakeTransactionService implements TransactionService {
  _FakeTransactionService(this.transaction);

  final BankTransaction transaction;
  final List<String> requestedIds = [];
  bool failNext = false;

  @override
  Future<BankTransaction> getTransactionById({
    required String token,
    required String id,
  }) async {
    requestedIds.add(id);
    if (failNext) {
      failNext = false;
      throw ApiException('Transaction could not be found.', 404);
    }
    return transaction;
  }

  @override
  Future<PagedTransactions> getTransactions({
    required String token,
    required int page,
    required int pageSize,
    String? accountId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async => PagedTransactions(
    items: [transaction],
    page: 1,
    pageSize: pageSize,
    totalCount: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Not needed for these tests.');
}
