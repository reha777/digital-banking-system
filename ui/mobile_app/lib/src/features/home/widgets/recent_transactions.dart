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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No transactions yet.'),
          )
        else
          ...transactions.map(
            (transaction) => TransactionHistoryTile(transaction: transaction),
          ),
      ],
    );
  }
}
