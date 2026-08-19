import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/app_theme.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    this.onSendMoney,
    this.onReceiveMoney,
    this.onTransfer,
  });

  final VoidCallback? onSendMoney;
  final VoidCallback? onReceiveMoney;
  final VoidCallback? onTransfer;

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
        const Expanded(
          child: _ActionButton(
            icon: Icons.attach_money,
            assetPath: 'assets/icons/dashboard/loan.png',
            label: 'Loan',
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
    this.assetPath,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? assetPath;

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
            child: assetPath == null
                ? Icon(
                    icon,
                    color: isDark ? Colors.white : const Color(0xFF10163A),
                    size: 25,
                  )
                : Image.asset(
                    assetPath!,
                    width: 25,
                    height: 25,
                    color: isDark ? Colors.white : const Color(0xFF10163A),
                    colorBlendMode: BlendMode.srcIn,
                  ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
