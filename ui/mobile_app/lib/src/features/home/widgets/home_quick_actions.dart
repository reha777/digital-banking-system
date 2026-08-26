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
            icon: LucideIcons.send,
            label: 'Send',
            onPressed: onSendMoney,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: LucideIcons.scanLine,
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

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onPressed == null
            ? null
            : () => setState(() => _pressed = false),
        onTapUp: widget.onPressed == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? .94 : 1,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : const Color(0xFFF4F7FC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: .06)
                        : const Color(0xFFE6EBF3),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120066FF),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: isDark ? Colors.white : const Color(0xFF10163A),
                  size: 23,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
