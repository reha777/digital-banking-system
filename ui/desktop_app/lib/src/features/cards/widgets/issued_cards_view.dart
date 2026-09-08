import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../widgets/app_page_states.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_table_row_hover.dart';
import '../admin_card_request_models.dart';
import '../admin_card_request_service.dart';

class IssuedCardsView extends StatefulWidget {
  const IssuedCardsView({
    super.key,
    required this.token,
    required this.pageSize,
    required this.dateFormatter,
    this.service,
  });
  final String token;
  final int pageSize;
  final String Function(DateTime) dateFormatter;
  final AdminCardRequestService? service;

  @override
  State<IssuedCardsView> createState() => _IssuedCardsViewState();
}

class _IssuedCardsViewState extends State<IssuedCardsView> {
  final _search = TextEditingController();
  late final AdminCardRequestService _service;
  late Future<AdminIssuedCardPage> _future;
  Timer? _debounce;
  int _page = 1;
  late int _pageSize;
  int? _status;
  String? _busyId;

  Future<void> _changeStatus(AdminIssuedCard card, bool blocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Block card?' : 'Unblock card?'),
        content: Text(
          '${blocked ? 'Block' : 'Unblock'} ${card.maskedCardNumber} for ${card.customerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = card.id);
    try {
      await _service.setIssuedCardBlocked(
        token: widget.token,
        id: card.id,
        blocked: blocked,
      );
      if (mounted) _refresh();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminCardRequestService(ApiClient());
    _pageSize = widget.pageSize;
    _future = _load();
  }

  Future<AdminIssuedCardPage> _load() => _service.getIssuedCards(
    token: widget.token,
    page: _page,
    pageSize: _pageSize,
    search: _search.text,
    status: _status,
  );

  void _refresh({bool firstPage = false}) {
    if (firstPage) _page = 1;
    setState(() {
      _future = _load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        spacing: 14,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Search customer, account or last four',
                prefixIcon: Icon(LucideIcons.search),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _refresh(firstPage: true),
                );
              },
            ),
          ),
          SizedBox(
            width: 190,
            child: AppDropdownField<int?>(
              label: 'Status',
              value: _status,
              items: const [
                AppDropdownItem(value: null, label: 'All statuses'),
                AppDropdownItem(value: 1, label: 'Active'),
                AppDropdownItem(value: 2, label: 'Blocked'),
                AppDropdownItem(value: 3, label: 'Expired'),
              ],
              onChanged: (value) {
                _status = value;
                _refresh(firstPage: true);
              },
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh data',
            onPressed: _refresh,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Expanded(
        child: FutureBuilder<AdminIssuedCardPage>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AppLoadingState();
            }
            if (snapshot.hasError) return AppErrorState(onRetry: _refresh);
            final page = snapshot.requireData;
            if (page.items.isEmpty) {
              return AppEmptyState(
                icon: LucideIcons.creditCard,
                title: 'No issued cards found',
                message: 'Try changing the current filters.',
                onReset: () {
                  _search.clear();
                  _status = null;
                  _refresh(firstPage: true);
                },
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final card = page.items[index];
                      return AppTableRowHover(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(LucideIcons.creditCard),
                          ),
                          title: Text(
                            '${card.customerName} · ${card.maskedCardNumber}',
                          ),
                          subtitle: Text(
                            '${card.brand} · ${card.accountNumber} · ${card.currency}\nExpires ${widget.dateFormatter(card.expiryDate)} · Issued ${widget.dateFormatter(card.createdAtUtc)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppStatusBadge(status: card.status),
                              const SizedBox(width: 8),
                              if (_busyId == card.id)
                                const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (card.status == 'Active')
                                IconButton(
                                  tooltip: 'Block card',
                                  onPressed: () => _changeStatus(card, true),
                                  icon: const Icon(LucideIcons.lock),
                                )
                              else if (card.status == 'Blocked')
                                IconButton(
                                  tooltip: 'Unblock card',
                                  onPressed: () => _changeStatus(card, false),
                                  icon: const Icon(LucideIcons.unlock),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                AppPagination(
                  currentPage: page.page,
                  totalPages: page.totalPages,
                  pageSize: page.pageSize,
                  shownCount: page.items.length,
                  totalCount: page.totalCount,
                  itemLabel: 'cards',
                  onPageSelected: (value) {
                    _page = value;
                    _refresh();
                  },
                  onPageSizeChanged: (value) {
                    _pageSize = value;
                    _refresh(firstPage: true);
                  },
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
