import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_table_row_hover.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../admin_customer_models.dart';
import '../../../core/currency_amount.dart';

class CustomersTable extends StatelessWidget {
  const CustomersTable({
    super.key,
    required this.page,
    required this.pageSize,
    required this.dateFormatter,
    required this.controller,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onPageSelected,
    required this.onPageSizeChanged,
  });
  final AdminCustomerPage page;
  final int pageSize;
  final String Function(DateTime) dateFormatter;
  final ScrollController controller;
  final ValueChanged<AdminCustomer> onEdit;
  final ValueChanged<AdminCustomer> onView;
  final ValueChanged<AdminCustomer> onDelete;
  final void Function(AdminCustomer, int) onStatusChanged;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 860;
      return Container(
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border(context)),
        ),
        child: Column(
          children: [
            if (desktop) const _Header(),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: EdgeInsets.zero,
                itemCount: page.items.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: _divider(context)),
                itemBuilder: (_, index) => desktop
                    ? _DesktopRow(
                        index: ((page.page - 1) * page.pageSize) + index + 1,
                        customer: page.items[index],
                        dateFormatter: dateFormatter,
                        onEdit: onEdit,
                        onView: onView,
                        onDelete: onDelete,
                        onStatusChanged: onStatusChanged,
                      )
                    : _CompactRow(
                        customer: page.items[index],
                        onEdit: onEdit,
                        onView: onView,
                        onDelete: onDelete,
                        onStatusChanged: onStatusChanged,
                      ),
              ),
            ),
            Divider(height: 1, color: _divider(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: AppPagination(
                currentPage: page.page,
                totalPages: page.totalPages,
                pageSize: pageSize,
                shownCount: page.items.length,
                totalCount: page.totalCount,
                itemLabel: 'customers',
                onPageSelected: onPageSelected,
                onPageSizeChanged: onPageSizeChanged,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF202033)
          : const Color(0xFFF8FAFC),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
    ),
    child: const Row(
      children: [
        _Cell('SL No', 1, header: true),
        _Cell('Customer', 4, header: true),
        _Cell('Contact', 4, header: true),
        _Cell('Accounts', 2, header: true),
        _Cell('Balance', 2, header: true),
        _Cell('Joined', 2, header: true),
        _Cell('Status', 2, header: true),
        _Cell('Actions', 3, header: true),
      ],
    ),
  );
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({
    required this.index,
    required this.customer,
    required this.dateFormatter,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onStatusChanged,
  });
  final int index;
  final AdminCustomer customer;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<AdminCustomer> onEdit;
  final ValueChanged<AdminCustomer> onView;
  final ValueChanged<AdminCustomer> onDelete;
  final void Function(AdminCustomer, int) onStatusChanged;
  @override
  Widget build(BuildContext context) => AppTableRowHover(
    child: Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: _surface(context),
      child: Row(
        children: [
          _Cell('${index.toString().padLeft(2, '0')}.', 1),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEAF1FF),
                  child: Text(
                    _initials(customer),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        customer.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _Cell(customer.phoneNumber, 4),
          _Cell('${customer.accountCount}', 2),
          _Cell(formatCurrencyAmounts(customer.balances), 2),
          _Cell(dateFormatter(customer.createdAtUtc), 2),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusMenu(
                customer: customer,
                onChanged: onStatusChanged,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => onView(customer),
                  tooltip: 'View customer',
                  icon: const Icon(LucideIcons.eye, size: 18),
                ),
                IconButton(
                  onPressed: () => onEdit(customer),
                  tooltip: 'Edit customer',
                  icon: const Icon(LucideIcons.pencil, size: 18),
                ),
                IconButton(
                  onPressed: () => onDelete(customer),
                  tooltip: 'Delete customer',
                  color: const Color(0xFFDC2626),
                  icon: const Icon(LucideIcons.trash2, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.customer,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
    required this.onStatusChanged,
  });
  final AdminCustomer customer;
  final ValueChanged<AdminCustomer> onEdit;
  final ValueChanged<AdminCustomer> onView;
  final ValueChanged<AdminCustomer> onDelete;
  final void Function(AdminCustomer, int) onStatusChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(child: Text(_initials(customer))),
    title: Text(customer.fullName),
    subtitle: Text(
      '${customer.email}\n${customer.phoneNumber} · ${customer.accountCount} accounts',
    ),
    isThreeLine: true,
    trailing: PopupMenuButton<int>(
      icon: const Icon(LucideIcons.moreVertical),
      onSelected: (value) {
        if (value == 10) {
          onEdit(customer);
        } else if (value == 9) {
          onView(customer);
        } else if (value == 11) {
          onDelete(customer);
        } else {
          onStatusChanged(customer, value);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 9, child: Text('View')),
        PopupMenuItem(value: 10, child: Text('Edit')),
        PopupMenuItem(value: 1, child: Text('Set active')),
        PopupMenuItem(value: 2, child: Text('Set inactive')),
        PopupMenuItem(value: 3, child: Text('Block')),
        PopupMenuItem(value: 11, child: Text('Delete')),
      ],
    ),
  );
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({required this.customer, required this.onChanged});
  final AdminCustomer customer;
  final void Function(AdminCustomer, int) onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    tooltip: 'Change status',
    position: PopupMenuPosition.under,
    onSelected: (value) => onChanged(customer, value),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 1, child: Text('Active')),
      PopupMenuItem(value: 2, child: Text('Inactive')),
      PopupMenuItem(value: 3, child: Text('Blocked')),
    ],
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppStatusBadge(status: customer.status),
        const SizedBox(width: 4),
        const Icon(LucideIcons.chevronDown, size: 14),
      ],
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, this.flex, {this.header = false});
  final String text;
  final int flex;
  final bool header;
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: header
            ? (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF87A7FF)
                  : const Color(0xFF5A77B8))
            : null,
        fontSize: header ? 12 : 13,
        fontWeight: header ? FontWeight.w800 : FontWeight.w400,
      ),
    ),
  );
}

Color _surface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? AppTheme.darkSurface
    : Colors.white;
Color _border(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF303244)
    : AppTheme.border;
Color _divider(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF2A2C3D)
    : const Color(0xFFEFF2F7);
String _initials(AdminCustomer c) {
  final value =
      '${c.firstName.isEmpty ? '' : c.firstName[0]}${c.lastName.isEmpty ? '' : c.lastName[0]}';
  return value.isEmpty ? 'C' : value.toUpperCase();
}
