import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_theme.dart';
import '../transaction_models.dart';

class TransferResultView extends StatelessWidget {
  const TransferResultView({
    super.key,
    required this.result,
    required this.recipient,
    required this.onDone,
  });

  final MoneyTransferResult result;
  final RecentRecipient recipient;
  final VoidCallback onDone;

  bool get _pending =>
      result.status == '1' || result.status.toLowerCase() == 'pending';

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .82, end: 1),
            duration: const Duration(milliseconds: 320),
            builder: (_, value, child) => Transform.scale(
              scale: value,
              child: Opacity(opacity: value, child: child),
            ),
            child: CircleAvatar(
              radius: 42,
              backgroundColor: (_pending ? Colors.amber : AppTheme.primary)
                  .withValues(alpha: .14),
              child: Icon(
                _pending ? LucideIcons.clock3 : LucideIcons.circleCheck,
                size: 42,
                color: _pending ? Colors.amber : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _pending
                ? 'Transfer submitted for review'
                : 'Money sent successfully',
            key: ValueKey(_pending ? 'pending-result' : 'completed-result'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            _pending
                ? 'Your transfer requires administrative approval before funds are moved.'
                : 'Your payment has been completed.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          _ResultLine('Recipient', recipient.displayName),
          _ResultLine(
            'Amount',
            '${result.currency} ${result.amount.toStringAsFixed(2)}',
          ),
          _ResultLine('Reference', result.referenceNumber),
          if (_pending) const _ResultLine('Status', 'Pending'),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    ),
  );
}

class _ResultLine extends StatelessWidget {
  const _ResultLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
