import 'package:flutter/material.dart';

class AppStatusTab<T> {
  const AppStatusTab({required this.value, required this.label});
  final T value;
  final String label;
}

class AppStatusTabs<T> extends StatelessWidget {
  const AppStatusTabs({
    super.key,
    required this.value,
    required this.tabs,
    required this.onChanged,
  });
  final T value;
  final List<AppStatusTab<T>> tabs;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: tabs.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, index) {
        final tab = tabs[index];
        final active = tab.value == value;
        return InkWell(
          onTap: () => onChanged(tab.value),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(tab.label),
            ),
          ),
        );
      },
    ),
  );
}
