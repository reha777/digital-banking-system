import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../core/app_theme.dart';

class AppPagination extends StatelessWidget {
  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPageSelected,
    required this.onPageSizeChanged,
    this.shownCount,
    this.totalCount,
    this.itemLabel = 'items',
  });
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int? shownCount;
  final int? totalCount;
  final String itemLabel;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages();
    final controls = <Widget>[
      const Text('Rows'),
      const SizedBox(width: 8),
      SizedBox(
        width: 80,
        height: 36,
        child: DropdownButtonFormField<int>(
          initialValue: pageSize,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
          ),
          items: const [10, 20, 50]
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text('$value')),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onPageSizeChanged(value);
          },
        ),
      ),
      const SizedBox(width: 12),
      IconButton.filledTonal(
        onPressed: currentPage <= 1
            ? null
            : () => onPageSelected(currentPage - 1),
        tooltip: 'Previous page',
        icon: const Icon(LucideIcons.chevronLeft, size: 18),
      ),
      ...pages.map(
        (page) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _PageButton(
            page: page,
            active: page == currentPage,
            enabled: page <= totalPages,
            onPressed: () => onPageSelected(page),
          ),
        ),
      ),
      if (pages.isNotEmpty && pages.last < totalPages - 1)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Text('...'),
        ),
      if (pages.isNotEmpty && pages.last < totalPages)
        _PageButton(
          page: totalPages,
          active: totalPages == currentPage,
          enabled: true,
          onPressed: () => onPageSelected(totalPages),
        ),
      const SizedBox(width: 6),
      IconButton.filledTonal(
        onPressed: currentPage >= totalPages
            ? null
            : () => onPageSelected(currentPage + 1),
        tooltip: 'Next page',
        icon: const Icon(LucideIcons.chevronRight, size: 18),
      ),
    ];
    final startItem = shownCount == null || shownCount == 0
        ? 0
        : ((currentPage - 1) * pageSize) + 1;
    final endItem = shownCount == null
        ? 0
        : startItem + shownCount! - (shownCount == 0 ? 0 : 1);
    final Widget count = shownCount != null && totalCount != null
        ? Text(
            'Showing $startItem to $endItem of $totalCount $itemLabel',
            style: Theme.of(context).textTheme.bodySmall,
          )
        : const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(children: [count, const Spacer(), ...controls]);
        }
        return Wrap(
          spacing: 0,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            count,
            if (shownCount != null && totalCount != null)
              const SizedBox(width: 18),
            ...controls,
          ],
        );
      },
    );
  }

  List<int> _visiblePages() {
    if (totalPages <= 3) return const [1, 2, 3];
    var start = (currentPage - 2).clamp(1, totalPages);
    final end = (start + 4).clamp(1, totalPages);
    start = (end - 4).clamp(1, totalPages);
    return [for (var page = start; page <= end; page++) page];
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.page,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });
  final int page;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: TextButton(
      onPressed: active || !enabled ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: active
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
        disabledForegroundColor: active
            ? Colors.white
            : Theme.of(context).disabledColor,
        disabledBackgroundColor: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: active
                ? Theme.of(context).colorScheme.primary
                : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF303244)
                      : AppTheme.border),
          ),
        ),
      ),
      child: Text('$page'),
    ),
  );
}
