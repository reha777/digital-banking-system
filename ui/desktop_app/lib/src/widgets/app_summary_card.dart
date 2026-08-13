import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class AppSummaryCard extends StatefulWidget {
  const AppSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  State<AppSummaryCard> createState() => _AppSummaryCardState();
}

class _AppSummaryCardState extends State<AppSummaryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: dark ? const Color(0xFF303244) : AppTheme.border,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF0F172A,
              ).withValues(alpha: dark ? .18 : .04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.tone.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, color: widget.tone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
