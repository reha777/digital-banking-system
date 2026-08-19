import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/formatting/account_number_formatters.dart';
import '../../cards/card_models.dart';
import '../transaction_models.dart';

class TransferConfirmationSheet extends StatefulWidget {
  const TransferConfirmationSheet({
    super.key,
    required this.card,
    required this.recipient,
    required this.amount,
    required this.description,
    required this.quote,
    required this.onConfirm,
  });

  final BankCardModel card;
  final RecentRecipient recipient;
  final double amount;
  final String description;
  final MoneyTransferQuote quote;
  final Future<MoneyTransferResult> Function() onConfirm;

  @override
  State<TransferConfirmationSheet> createState() =>
      _TransferConfirmationSheetState();
}

class _TransferConfirmationSheetState extends State<TransferConfirmationSheet> {
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Transfer could not be completed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review payment', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 22),
          _ReviewRow(
            icon: LucideIcons.creditCard,
            label: 'FROM',
            title: widget.card.maskedCardNumber,
            subtitle: numericAccountNumber(widget.card.accountNumber),
          ),
          if (widget.quote.requiresConversion) ...[
            const SizedBox(height: 12),
            _ReviewRow(
              icon: LucideIcons.repeat2,
              label: 'CONVERSION',
              title:
                  'Debit ${widget.quote.debitAmount.toStringAsFixed(2)} ${widget.quote.sourceCurrency}',
              subtitle:
                  'Recipient gets ${widget.quote.destinationAmount.toStringAsFixed(2)} ${widget.quote.destinationCurrency}',
            ),
          ],
          const SizedBox(height: 18),
          _ReviewRow(
            icon: LucideIcons.user,
            label: 'TO',
            title: widget.recipient.displayName,
            subtitle: numericAccountNumber(widget.recipient.accountNumber),
          ),
          const SizedBox(height: 18),
          _ReviewRow(
            icon: LucideIcons.walletCards,
            label: 'PAYMENT',
            title:
                '${widget.card.currency} ${widget.amount.toStringAsFixed(2)}',
            subtitle: widget.description.isEmpty
                ? 'No description'
                : widget.description,
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${widget.card.currency} ${widget.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              key: const ValueKey('confirmation-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            key: const ValueKey('confirm-transfer'),
            onPressed: _submitting ? null : _confirm,
            icon: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.send),
            label: const Text('Confirm & Send'),
          ),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(child: Icon(icon, size: 19)),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
