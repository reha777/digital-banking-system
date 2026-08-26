import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_date_range_picker.dart';
import '../../../widgets/app_dropdown_field.dart';

class CardRequestFilters extends StatelessWidget {
  const CardRequestFilters({
    super.key,
    required this.searchController,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.dateRange,
    required this.onDateChanged,
    required this.onRefresh,
    required this.onReset,
  });
  final TextEditingController searchController;
  final int? status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;
  final DateTimeRange? dateRange;
  final ValueChanged<DateTimeRange?> onDateChanged;
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
                labelText: 'Search customer, email, document or currency',
              ),
            ),
          ),
          SizedBox(
            width: 245,
            child: AppDateRangePicker(
              dateFrom: dateRange?.start,
              dateTo: dateRange?.end,
              onApply: onDateChanged,
              onClear: () => onDateChanged(null),
            ),
          ),
          SizedBox(
            width: 210,
            child: AppDropdownField<int?>(
              label: 'Status',
              value: status,
              items: const [
                AppDropdownItem(value: null, label: 'All statuses'),
                AppDropdownItem(value: 1, label: 'Pending'),
                AppDropdownItem(value: 4, label: 'Documents requested'),
                AppDropdownItem(value: 2, label: 'Approved'),
                AppDropdownItem(value: 3, label: 'Rejected'),
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
