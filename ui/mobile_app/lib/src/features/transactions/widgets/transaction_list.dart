import 'package:flutter/material.dart';

import '../transaction_models.dart';
import 'transaction_tile.dart';

typedef TransactionDocumentUploadBuilder =
    Widget Function(BankTransaction transaction);

class TransactionList extends StatelessWidget {
  const TransactionList({
    super.key,
    required this.transactions,
    required this.scrollController,
    required this.isLoadingMore,
    required this.onRefresh,
    required this.documentUploadBuilder,
    this.onOpenTransaction,
  });

  final List<BankTransaction> transactions;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final RefreshCallback onRefresh;
  final TransactionDocumentUploadBuilder documentUploadBuilder;
  final ValueChanged<BankTransaction>? onOpenTransaction;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: transactions.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= transactions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final transaction = transactions[index];
          return TransactionHistoryTile(
            transaction: transaction,
            onTap: onOpenTransaction == null
                ? null
                : () => onOpenTransaction!(transaction),
            documentUploadAction: transaction.requiresDocuments
                ? documentUploadBuilder(transaction)
                : null,
          );
        },
      ),
    );
  }
}
