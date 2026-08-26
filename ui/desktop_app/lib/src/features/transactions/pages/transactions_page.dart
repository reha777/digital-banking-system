import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_date_range_picker.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_states.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../../../widgets/app_summary_card.dart';
import '../../../widgets/app_status_tabs.dart';
import '../../../widgets/app_table_row_hover.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../admin_transaction_models.dart';
import '../admin_transaction_service.dart';
import '../widgets/transaction_details_dialog.dart';
import '../../settings/admin_formatters.dart';
import '../../../core/currency_amount.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    required this.token,
    required this.defaultPageSize,
    required this.dateFormatter,
    this.service,
    this.showHeader = true,
  });
  final String token;
  final int defaultPageSize;
  final String Function(DateTime) dateFormatter;
  final AdminTransactionService? service;
  final bool showHeader;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late final AdminTransactionService _service;
  late Future<_TransactionsData> _future;
  Timer? _debounce;
  int _page = 1;
  late int _pageSize;
  int? _status;
  int? _type;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.defaultPageSize;
    _service = widget.service ?? AdminTransactionService(ApiClient());
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_TransactionsData> _load() async {
    final page = await _service.getTransactions(
      token: widget.token,
      page: _page,
      pageSize: _pageSize,
      search: _searchController.text,
      status: _status,
      type: _type,
      dateFrom: _dateRange?.start,
      dateTo: _dateRange?.end,
    );
    final summary = await _service.getSummary(
      token: widget.token,
      search: _searchController.text,
      status: _status,
      type: _type,
      dateFrom: _dateRange?.start,
      dateTo: _dateRange?.end,
    );
    return _TransactionsData(page: page, summary: summary);
  }

  void _refresh({bool firstPage = false}) {
    if (firstPage) _page = 1;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _future = _load();
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refresh(firstPage: true);
    });
  }

  void _resetFilters() {
    _debounce?.cancel();
    _searchController.clear();
    _status = null;
    _type = null;
    _dateRange = null;
    _refresh(firstPage: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          const AppPageHeader(
            icon: LucideIcons.receipt,
            title: 'Transactions',
            subtitle: 'Search, filter and review customer money movement.',
          ),
          const SizedBox(height: 22),
        ],
        _TransactionFilters(
          searchController: _searchController,
          status: _status,
          type: _type,
          dateRange: _dateRange,
          onSearchChanged: _onSearchChanged,
          onStatusChanged: (value) {
            _status = value;
            _refresh(firstPage: true);
          },
          onTypeChanged: (value) {
            _type = value;
            _refresh(firstPage: true);
          },
          onDateChanged: (value) {
            _dateRange = value;
            _refresh(firstPage: true);
          },
          onRefresh: _refresh,
          onReset: _resetFilters,
        ),
        const SizedBox(height: 8),
        AppStatusTabs<int?>(
          value: _status,
          tabs: const [
            AppStatusTab(value: null, label: 'All'),
            AppStatusTab(value: 1, label: 'Pending'),
            AppStatusTab(value: 2, label: 'Completed'),
            AppStatusTab(value: 3, label: 'Failed'),
            AppStatusTab(value: 4, label: 'Cancelled'),
            AppStatusTab(value: 5, label: 'Documents requested'),
          ],
          onChanged: (value) {
            _status = value;
            _refresh(firstPage: true);
          },
        ),
        const SizedBox(height: 18),
        Expanded(
          child: FutureBuilder<_TransactionsData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const AppLoadingState();
              }
              if (snapshot.hasError) return AppErrorState(onRetry: _refresh);
              final data = snapshot.requireData;
              if (data.page.items.isEmpty) {
                return AppEmptyState(
                  icon: LucideIcons.receipt,
                  title: 'No transactions found',
                  message: 'Try changing or clearing the current filters.',
                  onReset: _resetFilters,
                );
              }
              return Column(
                children: [
                  if (snapshot.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(minHeight: 2),
                  _TransactionSummary(summary: data.summary),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _TransactionsTable(
                      page: data.page,
                      controller: _scrollController,
                      pageSize: _pageSize,
                      dateFormatter: widget.dateFormatter,
                      onPageSelected: (value) {
                        _page = value;
                        _refresh();
                      },
                      onPageSizeChanged: (value) {
                        _pageSize = value;
                        _refresh(firstPage: true);
                      },
                      onDetails: (item) => showDialog<void>(
                        context: context,
                        builder: (_) => TransactionDetailsDialog(
                          token: widget.token,
                          transactionId: item.id,
                          dateFormatter: widget.dateFormatter,
                          service: _service,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TransactionFilters extends StatelessWidget {
  const _TransactionFilters({
    required this.searchController,
    required this.status,
    required this.type,
    required this.dateRange,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onRefresh,
    required this.onReset,
  });
  final TextEditingController searchController;
  final int? status;
  final int? type;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;
  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<DateTimeRange?> onDateChanged;
  final VoidCallback onRefresh;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _pageBorder(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth < 300 ? constraints.maxWidth : 300,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search),
                  labelText: 'Search reference, customer or account',
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: AppDropdownField<int?>(
                label: 'Type',
                value: type,
                items: const [
                  AppDropdownItem(value: null, label: 'All types'),
                  AppDropdownItem(value: 1, label: 'Transfer'),
                  AppDropdownItem(value: 2, label: 'Internal Transfer'),
                  AppDropdownItem(value: 3, label: 'Loan Disbursement'),
                  AppDropdownItem(value: 4, label: 'Loan Repayment'),
                ],
                onChanged: onTypeChanged,
              ),
            ),
            SizedBox(
              width: 190,
              child: AppDropdownField<int?>(
                label: 'Status',
                value: status,
                items: const [
                  AppDropdownItem(value: null, label: 'All statuses'),
                  AppDropdownItem(value: 1, label: 'Pending'),
                  AppDropdownItem(value: 2, label: 'Completed'),
                  AppDropdownItem(value: 3, label: 'Failed'),
                  AppDropdownItem(value: 4, label: 'Cancelled'),
                  AppDropdownItem(value: 5, label: 'Documents requested'),
                ],
                onChanged: onStatusChanged,
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
    return row;
  }
}

class _TransactionSummary extends StatelessWidget {
  const _TransactionSummary({required this.summary});
  final AdminTransactionSummary summary;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: AppSummaryCard(
          title: 'Total transactions',
          value: '${summary.totalTransactions}',
          icon: LucideIcons.receipt,
          tone: const Color(0xFF0066FF),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Completed',
          value: '${summary.completedTransactions}',
          icon: LucideIcons.checkCircle,
          tone: const Color(0xFF16A34A),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: AppSummaryCard(
          title: 'Total transferred',
          value: formatCurrencyAmounts(summary.transferredByCurrency),
          icon: LucideIcons.circleDollarSign,
          tone: const Color(0xFF7C3AED),
        ),
      ),
    ],
  );
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.page,
    required this.controller,
    required this.pageSize,
    required this.dateFormatter,
    required this.onPageSelected,
    required this.onPageSizeChanged,
    required this.onDetails,
  });
  final AdminTransactionPage page;
  final ScrollController controller;
  final int pageSize;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;
  final ValueChanged<AdminTransaction> onDetails;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tableWidth = constraints.maxWidth < 860
          ? 1000.0
          : constraints.maxWidth;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _pageBorder(context)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.maxHeight,
            child: Column(
              children: [
                const _TransactionTableRow(
                  values: [
                    'SL No',
                    'Date',
                    'Reference',
                    'Type',
                    'From',
                    'To',
                    'Amount',
                    'Status',
                    'View',
                  ],
                  header: true,
                ),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = page.items[index];
                      return _TransactionTableRow(
                        values: [
                          '${((page.page - 1) * page.pageSize) + index + 1}.',
                          dateFormatter(item.createdAtUtc),
                          item.referenceNumber,
                          item.type.label,
                          item.sourceCustomerName ??
                              item.sourceAccountNumber ??
                              item.accountNumber,
                          item.destinationCustomerName ??
                              item.destinationAccountNumber ??
                              '-',
                          '${item.currency} ${AdminFormatters.number(item.amount)}',
                          item.status,
                          '',
                        ],
                        status: item.status,
                        onView: () => onDetails(item),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: AppPagination(
                    currentPage: page.page,
                    totalPages: page.totalPages,
                    pageSize: pageSize,
                    shownCount: page.items.length,
                    totalCount: page.totalCount,
                    itemLabel: 'transactions',
                    onPageSelected: onPageSelected,
                    onPageSizeChanged: onPageSizeChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TransactionTableRow extends StatelessWidget {
  const _TransactionTableRow({
    required this.values,
    this.header = false,
    this.status,
    this.onView,
  });
  final List<String> values;
  final bool header;
  final String? status;
  final VoidCallback? onView;
  @override
  Widget build(BuildContext context) {
    final row = Container(
      height: header ? 48 : null,
      constraints: header ? null : const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: header
          ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF202033)
                : const Color(0xFFF8FAFC))
          : Theme.of(context).cardColor,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: const [1, 2, 3, 2, 4, 4, 2, 2, 1][i],
              child: i == 7 && !header
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: AppStatusBadge(status: status!),
                    )
                  : i == 8 && !header
                  ? IconButton(
                      tooltip: 'View details',
                      onPressed: onView,
                      icon: const Icon(LucideIcons.eye, size: 18),
                    )
                  : Text(
                      values[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: header
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF87A7FF)
                                  : const Color(0xFF5A77B8))
                            : null,
                        fontSize: header ? 12 : 13,
                        fontWeight: header || i == 6
                            ? FontWeight.w800
                            : FontWeight.w400,
                      ),
                    ),
            ),
        ],
      ),
    );
    return header ? row : AppTableRowHover(child: row);
  }
}

class _TransactionsData {
  const _TransactionsData({required this.page, required this.summary});
  final AdminTransactionPage page;
  final AdminTransactionSummary summary;
}

Color _pageBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF303244)
    : AppTheme.border;
