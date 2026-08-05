import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_date_range_picker.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_states.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../admin_transaction_models.dart';
import '../admin_transaction_service.dart';
import '../widgets/transaction_review_dialog.dart';

class TransactionReviewPage extends StatefulWidget {
  const TransactionReviewPage({
    super.key,
    required this.token,
    this.showHeader = true,
  });
  final String token;
  final bool showHeader;
  @override
  State<TransactionReviewPage> createState() => _TransactionReviewPageState();
}

class _TransactionReviewPageState extends State<TransactionReviewPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late final AdminTransactionService _service;
  late Future<_ReviewData> _future;
  Timer? _debounce;
  int _page = 1;
  int _pageSize = 10;
  int? _status;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _service = AdminTransactionService(ApiClient());
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ReviewData> _load() async {
    final pageFuture = _service.getTransactions(
      token: widget.token,
      page: _page,
      pageSize: _pageSize,
      search: _searchController.text,
      status: _status,
      dateFrom: _dateRange?.start,
      dateTo: _dateRange?.end,
      highRiskOnly: true,
    );
    final summaryFuture = _service.getSummary(
      token: widget.token,
      search: _searchController.text,
      status: _status,
      dateFrom: _dateRange?.start,
      dateTo: _dateRange?.end,
      highRiskOnly: true,
    );
    return _ReviewData(page: await pageFuture, summary: await summaryFuture);
  }

  void _refresh({bool firstPage = false}) {
    if (firstPage) _page = 1;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() => _future = _load());
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _refresh(firstPage: true);
    });
  }

  void _reset() {
    _debounce?.cancel();
    _searchController.clear();
    _status = null;
    _dateRange = null;
    _refresh(firstPage: true);
  }

  Future<bool> _action(
    AdminTransaction transaction,
    String note,
    String action,
  ) async {
    try {
      if (action == 'approve') {
        await _service.approveReview(
          token: widget.token,
          id: transaction.id,
          adminNote: note,
        );
      }
      if (action == 'reject') {
        await _service.rejectReview(
          token: widget.token,
          id: transaction.id,
          adminNote: note,
        );
      }
      if (action == 'documents') {
        await _service.requestDocuments(
          token: widget.token,
          id: transaction.id,
          adminNote: note,
        );
      }
      if (!mounted) return true;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Transaction approved.'
                : action == 'reject'
                ? 'Transaction rejected.'
                : 'Document request sent to customer.',
          ),
        ),
      );
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Future<Uint8List> _download(
    AdminTransaction transaction,
    AdminTransactionDocument document,
  ) async => Uint8List.fromList(
    await _service.downloadDocument(
      token: widget.token,
      transactionId: transaction.id,
      documentId: document.id,
    ),
  );

  Future<void> _open(AdminTransaction transaction) => showDialog<void>(
    context: context,
    builder: (_) => TransactionReviewDialog(
      transaction: transaction,
      onRequestDocuments: (note) => _action(transaction, note, 'documents'),
      onApprove: (note) => _action(transaction, note, 'approve'),
      onReject: (note) => _action(transaction, note, 'reject'),
      onDownloadDocument: (document) => _download(transaction, document),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.showHeader) ...[
        const AppPageHeader(
          icon: LucideIcons.shieldAlert,
          title: 'Transaction Review',
          subtitle:
              'Review high-risk transfers that require administrative approval.',
        ),
        const SizedBox(height: 22),
      ],
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _reviewBorder(context)),
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                onChanged: _searchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.search),
                  labelText: 'Search reference, customer or account',
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                key: ValueKey(_status),
                initialValue: _status,
                decoration: const InputDecoration(
                  prefixIcon: Icon(LucideIcons.listFilter),
                  labelText: 'Status',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All statuses')),
                  DropdownMenuItem(value: 1, child: Text('Pending')),
                  DropdownMenuItem(
                    value: 5,
                    child: Text('Documents requested'),
                  ),
                  DropdownMenuItem(value: 2, child: Text('Completed')),
                  DropdownMenuItem(value: 3, child: Text('Failed')),
                ],
                onChanged: (value) {
                  _status = value;
                  _refresh(firstPage: true);
                },
              ),
            ),
            SizedBox(
              width: 245,
              child: AppDateRangePicker(
                dateFrom: _dateRange?.start,
                dateTo: _dateRange?.end,
                onApply: (value) {
                  _dateRange = value;
                  _refresh(firstPage: true);
                },
                onClear: () {
                  _dateRange = null;
                  _refresh(firstPage: true);
                },
              ),
            ),
            IconButton.filledTonal(
              onPressed: _refresh,
              tooltip: 'Refresh data',
              icon: const Icon(LucideIcons.refreshCw),
            ),
            IconButton.filledTonal(
              onPressed: _reset,
              tooltip: 'Reset filters',
              icon: const Icon(LucideIcons.rotateCcw),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: FutureBuilder<_ReviewData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoadingState();
            }
            if (snapshot.hasError) return AppErrorState(onRetry: _refresh);
            final data = snapshot.requireData;
            if (data.page.items.isEmpty) {
              return AppEmptyState(
                icon: LucideIcons.shieldAlert,
                title: 'No reviews found',
                message: 'Try changing or clearing the current filters.',
                onReset: _reset,
              );
            }
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${data.summary.totalTransactions} high-risk transactions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _ReviewTable(
                    page: data.page,
                    pageSize: _pageSize,
                    controller: _scrollController,
                    onView: _open,
                    onPageSelected: (value) {
                      _page = value;
                      _refresh();
                    },
                    onPageSizeChanged: (value) {
                      _pageSize = value;
                      _refresh(firstPage: true);
                    },
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

class _ReviewTable extends StatelessWidget {
  const _ReviewTable({
    required this.page,
    required this.pageSize,
    required this.controller,
    required this.onView,
    required this.onPageSelected,
    required this.onPageSizeChanged,
  });
  final AdminTransactionPage page;
  final int pageSize;
  final ScrollController controller;
  final ValueChanged<AdminTransaction> onView;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 860 ? 1100.0 : constraints.maxWidth;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _reviewBorder(context)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: Column(
              children: [
                const _ReviewRow(
                  values: [
                    'SL No',
                    'Date',
                    'Reference',
                    'From',
                    'To',
                    'Amount',
                    'Status',
                    'Actions',
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
                      return _ReviewRow(
                        values: [
                          '${((page.page - 1) * page.pageSize) + index + 1}.',
                          _reviewDate(item.createdAtUtc),
                          item.referenceNumber,
                          item.sourceCustomerName ??
                              item.sourceAccountNumber ??
                              item.accountNumber,
                          item.destinationCustomerName ??
                              item.destinationAccountNumber ??
                              '-',
                          '\$${item.amount.toStringAsFixed(2)}',
                          item.status,
                          'View',
                        ],
                        status: item.status,
                        onView: () => onView(item),
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

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
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
  Widget build(BuildContext context) => Container(
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
            flex: const [1, 2, 3, 4, 4, 2, 2, 2][i],
            child: i == 6 && !header
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: AppStatusBadge(status: status!),
                  )
                : i == 7 && !header
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(LucideIcons.eye, size: 18),
                      label: const Text('View'),
                    ),
                  )
                : Text(
                    values[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: header ? 12 : 13,
                      fontWeight: header
                          ? FontWeight.w800
                          : (i == 5 ? FontWeight.w800 : FontWeight.w400),
                      color: header
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF87A7FF)
                                : const Color(0xFF5A77B8))
                          : null,
                    ),
                  ),
          ),
      ],
    ),
  );
}

String _reviewDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}.';
}

Color _reviewBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF303244)
    : AppTheme.border;

class _ReviewData {
  const _ReviewData({required this.page, required this.summary});
  final AdminTransactionPage page;
  final AdminTransactionSummary summary;
}
