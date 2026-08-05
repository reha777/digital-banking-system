import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';

class CustomerFilters extends StatelessWidget {
  const CustomerFilters({
    super.key,
    required this.searchController,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.onReset,
  });
  final TextEditingController searchController;
  final int? status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;
  final VoidCallback onRefresh;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF303244)
            : AppTheme.border,
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth < 430 ? constraints.maxWidth : 430,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.search),
                labelText: 'Search name, email, phone or account',
              ),
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<int?>(
              key: ValueKey(status),
              initialValue: status,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.listFilter),
                labelText: 'Status',
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All statuses')),
                DropdownMenuItem(value: 1, child: Text('Active')),
                DropdownMenuItem(value: 2, child: Text('Inactive')),
                DropdownMenuItem(value: 3, child: Text('Blocked')),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          IconButton.filledTonal(
            onPressed: onRefresh,
            tooltip: 'Refresh data',
            icon: const Icon(LucideIcons.refreshCw),
          ),
          IconButton.filledTonal(
            onPressed: onReset,
            tooltip: 'Reset filters',
            icon: const Icon(LucideIcons.rotateCcw),
          ),
        ],
      ),
    ),
  );
}
