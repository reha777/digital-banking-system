import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AppDropdownItem<T> {
  const AppDropdownItem({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class AppDropdownField<T> extends StatefulWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  State<AppDropdownField<T>> createState() => _AppDropdownFieldState<T>();
}

class _AppDropdownFieldState<T> extends State<AppDropdownField<T>> {
  final MenuController _controller = MenuController();
  bool _open = false;

  AppDropdownItem<T> get _selected => widget.items.firstWhere(
    (item) => item.value == widget.value,
    orElse: () => widget.items.first,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      final width = constraints.maxWidth;
      return MenuAnchor(
        controller: _controller,
        alignmentOffset: const Offset(0, 7),
        crossAxisUnconstrained: false,
        onOpen: () => setState(() => _open = true),
        onClose: () => setState(() => _open = false),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(theme.colorScheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: WidgetStatePropertyAll(
            const Color(0xFF0F172A).withValues(alpha: .2),
          ),
          minimumSize: WidgetStatePropertyAll(Size(width, 0)),
          maximumSize: WidgetStatePropertyAll(Size(width, 280)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        menuChildren: widget.items.map((item) {
          final selected = item.value == widget.value;
          return MenuItemButton(
            onPressed: () {
              _controller.close();
              widget.onChanged(item.value);
            },
            leadingIcon: item.icon == null ? null : Icon(item.icon, size: 17),
            trailingIcon: selected
                ? Icon(
                    LucideIcons.check,
                    size: 16,
                    color: theme.colorScheme.primary,
                  )
                : const SizedBox(width: 16),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return theme.colorScheme.primary.withValues(alpha: .065);
                }
                return selected
                    ? theme.colorScheme.primary.withValues(alpha: .09)
                    : Colors.transparent;
              }),
              foregroundColor: WidgetStatePropertyAll(
                selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(item.label),
            ),
          );
        }).toList(),
        builder: (context, controller, _) => InkWell(
          onTap: () =>
              controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? .42 : .6,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _open ? theme.colorScheme.primary : Colors.transparent,
                width: _open ? 1.2 : 1,
              ),
              boxShadow: _open
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: .1),
                        blurRadius: 0,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                if (_selected.icon case final icon?) ...[
                  Icon(icon, size: 17, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selected.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(LucideIcons.chevronDown, size: 17),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
