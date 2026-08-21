import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_theme.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    this.onSendMoney,
    this.onReceiveMoney,
    this.onTransfer,
    this.onLoan,
  });

  final VoidCallback? onSendMoney;
  final VoidCallback? onReceiveMoney;
  final VoidCallback? onTransfer;
  final VoidCallback? onLoan;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.arrow_upward,
            label: 'Send',
            onPressed: onSendMoney,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.arrow_downward,
            label: 'Receive',
            onPressed: onReceiveMoney,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.landmark,
            label: 'Loan',
            onPressed: onLoan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.arrowRightLeft,
            label: 'Transfer',
            onPressed: onTransfer,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark
                ? AppTheme.darkSurface
                : const Color(0xFFF5F6FA),
            child: Icon(
              icon,
              color: isDark ? Colors.white : const Color(0xFF10163A),
              size: 25,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
