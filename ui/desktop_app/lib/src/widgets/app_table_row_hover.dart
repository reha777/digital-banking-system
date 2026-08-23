import 'package:flutter/material.dart';

class AppTableRowHover extends StatefulWidget {
  const AppTableRowHover({super.key, required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  State<AppTableRowHover> createState() => _AppTableRowHoverState();
}

class _AppTableRowHoverState extends State<AppTableRowHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 135),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: _hovered ? .026 : 0),
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
