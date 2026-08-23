import 'package:flutter/material.dart';

import '../../transactions/transaction_models.dart';
import '../../transactions/widgets/transaction_tile.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({
    super.key,
    required this.transactions,
    required this.onSeeAll,
  });

  final List<BankTransaction> transactions;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Transaction', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(onPressed: onSeeAll, child: const Text('See All')),
          ],
        ),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No transactions yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else
          ...transactions.map(
            (transaction) => TransactionHistoryTile(transaction: transaction),
          ),
      ],
    );
  }
}
