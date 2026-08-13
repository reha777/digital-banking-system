import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/features/transactions/transaction_models.dart';
import 'package:mobile_app/src/features/transactions/widgets/transaction_tile.dart';

void main() {
  testWidgets('shows requested-document note', (tester) async {
    final transaction = _transaction(
      status: 'Documents requested',
      statusValue: 5,
      isHighRiskReview: true,
      documentsRequestNote: 'Please upload proof of payment.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TransactionHistoryTile(transaction: transaction)),
      ),
    );

    expect(find.text('Please upload proof of payment.'), findsOneWidget);
    expect(transaction.requiresDocuments, isTrue);
  });

  testWidgets('keeps the generic high-risk review hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionHistoryTile(
            transaction: _transaction(
              status: 'Pending',
              statusValue: 1,
              isHighRiskReview: true,
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('High-risk transfer is waiting for admin review.'),
      findsOneWidget,
    );
  });
}

BankTransaction _transaction({
  required String status,
  required int statusValue,
  required bool isHighRiskReview,
  String? documentsRequestNote,
}) {
  return BankTransaction(
    id: 'transaction-1',
    accountId: 'account-1',
    accountNumber: 'BA-000001',
    referenceNumber: 'REF-1',
    amount: -25,
    description: 'Mobile money transfer',
    status: status,
    statusValue: statusValue,
    isHighRiskReview: isHighRiskReview,
    createdAtUtc: DateTime.utc(2026),
    documentsRequestNote: documentsRequestNote,
  );
}
