import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../admin_card_request_models.dart';

/// Shows the newly issued card once, right after approval.
///
/// The CVV is generated at issuance and never persisted, so this dialog is the
/// only place it can ever be seen. Closing it discards the value for good.
class IssuedCardOnceDialog extends StatelessWidget {
  const IssuedCardOnceDialog({super.key, required this.issued});

  final CardIssueResult issued;

  static Future<void> show(BuildContext context, CardIssueResult issued) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => IssuedCardOnceDialog(issued: issued),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: const Icon(LucideIcons.creditCard),
      title: const Text('Card issued'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Row(label: 'Card number', value: _grouped(issued.cardNumber)),
            _Row(label: 'Expires', value: issued.formattedExpiry),
            _Row(label: 'CVV', value: issued.oneTimeCvv, emphasized: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.alertTriangle, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      issued.warning,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  static String _grouped(String value) {
    final buffer = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      if (index > 0 && index % 4 == 0) buffer.write(' ');
      buffer.write(value[index]);
    }
    return buffer.toString();
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: emphasized ? 20 : 16,
              fontWeight: FontWeight.w700,
              letterSpacing: emphasized ? 2 : 1,
            ),
          ),
        ),
      ],
    ),
  );
}
