import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_table_row_hover.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../admin_card_request_models.dart';

class CardRequestsTable extends StatelessWidget {
  const CardRequestsTable({
    super.key,
    required this.page,
    required this.pageSize,
    required this.dateFormatter,
    required this.controller,
    required this.onDetails,
    required this.onPageSelected,
    required this.onPageSizeChanged,
  });
  final AdminCardRequestPage page;
  final int pageSize;
  final String Function(DateTime) dateFormatter;
  final ScrollController controller;
  final ValueChanged<AdminCardRequest> onDetails;
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
                        request: page.items[index],
                        dateFormatter: dateFormatter,
                        onDetails: onDetails,
                      )
                    : _CompactRow(
                        request: page.items[index],
                        onDetails: onDetails,
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
                itemLabel: 'requests',
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
        _Cell('Request', 3, header: true),
        _Cell('Document', 3, header: true),
        _Cell('Delivery', 4, header: true),
        _Cell('Created', 2, header: true),
        _Cell('Status', 2, header: true),
        _Cell('Actions', 4, header: true),
      ],
    ),
  );
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({
    required this.index,
    required this.request,
    required this.dateFormatter,
    required this.onDetails,
  });
  final int index;
  final AdminCardRequest request;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<AdminCardRequest> onDetails;
  @override
  Widget build(BuildContext context) => AppTableRowHover(
    child: Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: _surface(context),
      child: Row(
        children: [
          _Cell('${index.toString().padLeft(2, '0')}.', 1),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  request.customerEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _Cell('${request.currency} card for ${request.cardholderName}', 3),
          _Cell(_shorten(request.documentNumber, 18), 3),
          _Cell(_shorten(request.deliveryAddress, 30), 4),
          _Cell(dateFormatter(request.createdAtUtc), 2),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(status: request.status),
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onDetails(request),
                icon: const Icon(LucideIcons.eye, size: 18),
                label: const Text('Details'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.request, required this.onDetails});
  final AdminCardRequest request;
  final ValueChanged<AdminCardRequest> onDetails;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const CircleAvatar(child: Icon(LucideIcons.creditCard, size: 18)),
    title: Text(request.customerName),
    subtitle: Text(
      '${request.customerEmail}\n${request.currency} · ${request.cardholderName}',
    ),
    isThreeLine: true,
    trailing: IconButton(
      onPressed: () => onDetails(request),
      tooltip: 'View details',
      icon: const Icon(LucideIcons.eye),
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
String _shorten(String value, int max) =>
    value.length <= max ? value : '${value.substring(0, max - 1)}...';
