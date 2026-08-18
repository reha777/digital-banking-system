import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_theme.dart';
import '../../accounts/account_models.dart';

class SendMoneySourceCard extends StatelessWidget {
  const SendMoneySourceCard({
    super.key,
    required this.account,
    required this.holderName,
  });
  final Account account;
  final String holderName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFF202349),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.landmark, color: Colors.white70),
            Spacer(),
            Icon(LucideIcons.wifi, color: Colors.white54),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          account.accountNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                holderName.isEmpty ? 'Banking customer' : holderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Text(
              '${account.currency} ${account.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Available balance',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    ),
  );
}
