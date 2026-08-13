import 'package:flutter/material.dart';

import '../transaction_models.dart';

class TransactionStatusBadge extends StatelessWidget {
  const TransactionStatusBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class TransactionReviewHint extends StatelessWidget {
  const TransactionReviewHint({super.key, required this.transaction});

  final BankTransaction transaction;

  @override
  Widget build(BuildContext context) {
    if (!transaction.isHighRiskReview) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        transaction.documentsRequestNote?.isNotEmpty == true
            ? transaction.documentsRequestNote!
            : 'High-risk transfer is waiting for admin review.',
        style: const TextStyle(
          color: Color(0xFFF59E0B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
