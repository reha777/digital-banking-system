import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/formatting/money_formatters.dart';
import '../transaction_models.dart';
import 'transaction_status_badge.dart';

class TransactionHistoryTile extends StatelessWidget {
  const TransactionHistoryTile({
    super.key,
    required this.transaction,
    this.documentUploadAction,
  });

  final BankTransaction transaction;
  final Widget? documentUploadAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncoming = transaction.amount > 0;
    final tone = isIncoming ? AppTheme.primary : _transactionTone(transaction);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isDark
            ? AppTheme.darkSurface
            : const Color(0xFFF5F6FA),
        child: Icon(
          _transactionIcon(transaction, isIncoming),
          color: tone,
          size: 18,
        ),
      ),
      title: Text(
        _transactionTitle(transaction),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransactionStatusBadge(label: _transactionSubtitle(transaction)),
          TransactionReviewHint(transaction: transaction),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isIncoming ? '' : '- '}\$${formatMoney(transaction.amount.abs())}',
            style: TextStyle(
              color: isIncoming
                  ? AppTheme.primary
                  : (isDark ? Colors.white : AppTheme.textDark),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          ?documentUploadAction,
        ],
      ),
    );
  }
}

String _transactionTitle(BankTransaction transaction) {
  final description = transaction.description.trim();
  if (description.isEmpty || description.toLowerCase().contains('transfer')) {
    return 'Money Transfer';
  }

  return description;
}

String _transactionSubtitle(BankTransaction transaction) {
  final description = transaction.description.trim();
  if (description.isEmpty || description.toLowerCase().contains('transfer')) {
    return 'Transaction';
  }

  return transaction.status;
}

IconData _transactionIcon(BankTransaction transaction, bool isIncoming) {
  final text = transaction.description.toLowerCase();
  if (text.contains('grocery')) {
    return Icons.shopping_cart_outlined;
  }
  if (text.contains('spotify') || text.contains('music')) {
    return Icons.music_note;
  }
  if (text.contains('apple')) {
    return Icons.apple;
  }
  if (text.contains('netflix')) {
    return Icons.movie_creation_outlined;
  }

  return isIncoming ? Icons.arrow_downward : Icons.arrow_upward;
}

Color _transactionTone(BankTransaction transaction) {
  final text = transaction.description.toLowerCase();
  if (text.contains('grocery')) {
    return const Color(0xFFFF5A66);
  }
  if (text.contains('spotify') || text.contains('music')) {
    return const Color(0xFF1DB954);
  }
  if (text.contains('netflix')) {
    return const Color(0xFFE50914);
  }

  return AppTheme.textMuted;
}
