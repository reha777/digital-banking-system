import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/app_error_message.dart';
import '../../../widgets/app_page_states.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../../../widgets/app_status_tabs.dart';
import '../../settings/admin_formatters.dart';
import '../admin_customer_models.dart';
import '../admin_customer_service.dart';
import '../customer_details_models.dart';
import '../customer_details_service.dart';
import '../widgets/customer_edit_dialog.dart';
import '../../loans/models/admin_loan_models.dart';
import '../../loans/widgets/admin_loans_widgets.dart';
import '../../loans/widgets/loan_widgets.dart';
import '../../cards/admin_card_request_models.dart';
import '../../transactions/admin_transaction_models.dart';

class CustomerDetailsPage extends StatefulWidget {
  const CustomerDetailsPage({
    super.key,
    required this.token,
    required this.customerId,
    required this.dateFormatter,
    required this.onBack,
    required this.onCustomerUpdated,
    this.service,
    this.customerService,
  });
  final String token, customerId;
  final String Function(DateTime) dateFormatter;
  final VoidCallback onBack, onCustomerUpdated;
  final CustomerDetailsService? service;
  final AdminCustomerService? customerService;

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  late final CustomerDetailsService _service;
  late final AdminCustomerService _customerService;
  late Future<AdminCustomerDetails> _core;
  int _tab = 0;
  final _tabCache = <int, Widget>{};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CustomerDetailsService(ApiClient());
    _customerService =
        widget.customerService ?? AdminCustomerService(ApiClient());
    _core = _service.getDetails(widget.token, widget.customerId);
  }

  void _refreshCore() {
    setState(() {
      _core = _service.getDetails(widget.token, widget.customerId);
    });
  }

  Future<void> _edit(AdminCustomerDetails value) async {
    final customer = AdminCustomer(
      id: value.id,
      firstName: value.firstName,
      lastName: value.lastName,
      fullName: value.fullName,
      email: value.email,
      phoneNumber: value.phoneNumber,
      status: value.status,
      statusValue: value.statusValue,
      accountCount: value.summary.accountCount,
      balances: value.balances,
      createdAtUtc: value.createdAtUtc,
    );
    final request = await showDialog<CustomerEditRequest>(
      context: context,
      builder: (_) => CustomerEditDialog(customer: customer),
    );
    if (request == null) return;
    try {
      await _customerService.updateCustomer(
        token: widget.token,
        id: value.id,
        firstName: request.firstName,
        lastName: request.lastName,
        phoneNumber: request.phoneNumber,
      );
      widget.onCustomerUpdated();
      _refreshCore();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminCustomerDetails>(
    future: _core,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const AppLoadingState();
      }
      if (snapshot.hasError) {
        return AppErrorState(
          message: AppErrorMessage.from(
            snapshot.error!,
            fallback: 'Unable to load customer details.',
          ),
          onRetry: _refreshCore,
        );
      }
      final value = snapshot.requireData;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            value: value,
            onBack: widget.onBack,
            onEdit: () => _edit(value),
            onRefresh: _refreshCore,
          ),
          const SizedBox(height: 16),
          AppStatusTabs<int>(
            value: _tab,
            tabs: const [
              AppStatusTab(value: 0, label: 'Overview'),
              AppStatusTab(value: 1, label: 'Accounts & Cards'),
              AppStatusTab(value: 2, label: 'Transactions'),
              AppStatusTab(value: 3, label: 'Loans'),
              AppStatusTab(value: 4, label: 'Requests'),
            ],
            onChanged: (selection) => setState(() => _tab = selection),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(_tab), child: _tabBody(value)),
            ),
          ),
        ],
      );
    },
  );

  Widget _tabBody(AdminCustomerDetails value) {
    if (_tab == 0) {
      return _Overview(value: value, dateFormatter: widget.dateFormatter);
    }
    if (_tab == 1) {
      return _AccountsCards(value: value, dateFormatter: widget.dateFormatter);
    }
    return _tabCache.putIfAbsent(
      _tab,
      () => switch (_tab) {
        2 => _CustomerTransactions(
          key: ValueKey('transactions-${value.id}'),
          service: _service,
          token: widget.token,
          customerId: value.id,
          dateFormatter: widget.dateFormatter,
        ),
        3 => _CustomerLoans(
          key: ValueKey('loans-${value.id}'),
          service: _service,
          token: widget.token,
          customerId: value.id,
          dateFormatter: widget.dateFormatter,
        ),
        _ => _CustomerRequests(
          key: ValueKey('requests-${value.id}'),
          service: _service,
          token: widget.token,
          customerId: value.id,
          dateFormatter: widget.dateFormatter,
        ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.value,
    required this.onBack,
    required this.onEdit,
    required this.onRefresh,
  });
  final AdminCustomerDetails value;
  final VoidCallback onBack, onEdit, onRefresh;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              IconButton(
                onPressed: onBack,
                tooltip: 'Back to customers',
                icon: const Icon(LucideIcons.chevronLeft),
              ),
              CircleAvatar(radius: 26, child: Text(_initials(value))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      value.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      value.phoneNumber,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppStatusBadge(status: value.status),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Refresh customer',
                icon: const Icon(LucideIcons.refreshCw),
              ),
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 17),
                label: const Text('Edit Customer'),
              ),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              actions,
            ],
          );
        },
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.value, required this.dateFormatter});
  final AdminCustomerDetails value;
  final String Function(DateTime) dateFormatter;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Metric(
            'Accounts',
            '${value.summary.accountCount}',
            LucideIcons.landmark,
          ),
          _Metric(
            'Issued cards',
            '${value.summary.cardCount}',
            LucideIcons.creditCard,
          ),
          _Metric(
            'Active loans',
            '${value.summary.activeLoanCount}',
            LucideIcons.coins,
          ),
          _Metric(
            'Pending requests',
            '${value.summary.pendingCardRequestCount + value.summary.pendingTransactionReviewCount + value.summary.pendingLoanApplicationCount}',
            LucideIcons.fileClock,
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (value.balances.isNotEmpty) ...[
        _Section(
          title: 'Financial overview',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: value.balances
                .map((item) => Chip(label: Text(item.formatted)))
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
      ],
      _Section(
        title: 'Customer information',
        child: Wrap(
          spacing: 30,
          runSpacing: 16,
          children: [
            _Info('First name', value.firstName),
            _Info('Last name', value.lastName),
            _Info('Email', value.email),
            _Info('Phone', value.phoneNumber),
            _Info('Joined', dateFormatter(value.createdAtUtc)),
            _Info('Customer ID', value.id),
          ],
        ),
      ),
    ],
  );
}

class _AccountsCards extends StatelessWidget {
  const _AccountsCards({required this.value, required this.dateFormatter});
  final AdminCustomerDetails value;
  final String Function(DateTime) dateFormatter;
  @override
  Widget build(BuildContext context) => value.accounts.isEmpty
      ? const AppEmptyState(
          icon: LucideIcons.landmark,
          title: 'No accounts found',
          message: 'This customer has no banking accounts.',
        )
      : ListView.separated(
          itemCount: value.accounts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final account = value.accounts[i];
            return _Section(
              title: '${account.accountType} · ${account.accountNumber}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${account.currency} ${AdminFormatters.number(account.balance)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Opened ${dateFormatter(account.createdAtUtc)}'),
                  const Divider(height: 24),
                  if (account.card case final card?)
                    Wrap(
                      spacing: 22,
                      runSpacing: 12,
                      children: [
                        _Info('Cardholder', card.cardholderName),
                        _Info('Masked card', card.maskedCardNumber),
                        _Info('Network', card.brand),
                        _Info('Status', card.status),
                        _Info(
                          'Expiry',
                          '${card.expiryDate.month.toString().padLeft(2, '0')}/${card.expiryDate.year}',
                        ),
                        _Info('Associated currency', account.currency),
                      ],
                    )
                  else
                    const Text('No card issued'),
                ],
              ),
            );
          },
        );
}

class _CustomerTransactions extends StatefulWidget {
  const _CustomerTransactions({
    super.key,
    required this.service,
    required this.token,
    required this.customerId,
    required this.dateFormatter,
  });
  final CustomerDetailsService service;
  final String token, customerId;
  final String Function(DateTime) dateFormatter;
  @override
  State<_CustomerTransactions> createState() => _CustomerTransactionsState();
}

class _CustomerTransactionsState extends State<_CustomerTransactions> {
  int _page = 1;
  static const _pageSize = 10;
  late Future<AdminTransactionPage> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.service.getTransactions(
      token: widget.token,
      customerId: widget.customerId,
      page: _page,
      pageSize: _pageSize,
    );
  }

  void _refresh() => setState(_load);
  @override
  Widget build(BuildContext context) => FutureBuilder<AdminTransactionPage>(
    future: _future,
    builder: (_, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppLoadingState();
      }
      if (snapshot.hasError) {
        return AppErrorState(
          message: AppErrorMessage.from(
            snapshot.error!,
            fallback: 'Unable to load transactions.',
          ),
          onRetry: _refresh,
        );
      }
      final data = snapshot.requireData;
      if (data.items.isEmpty) {
        return const AppEmptyState(
          icon: LucideIcons.arrowLeftRight,
          title: 'No transactions found',
          message: 'This customer has no matching transactions.',
        );
      }
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh transactions',
              icon: const Icon(LucideIcons.refreshCw),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: data.items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, i) {
                final item = data.items[i];
                return ListTile(
                  title: Text(item.referenceNumber),
                  subtitle: Text(
                    '${item.type.label} · ${widget.dateFormatter(item.createdAtUtc)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.currency} ${AdminFormatters.number(item.amount)}',
                      ),
                      AppStatusBadge(status: item.status),
                    ],
                  ),
                );
              },
            ),
          ),
          AppPagination(
            currentPage: data.page,
            totalPages: data.totalPages,
            pageSize: _pageSize,
            shownCount: data.items.length,
            totalCount: data.totalCount,
            itemLabel: 'transactions',
            showPageSizeSelector: false,
            onPageSelected: (value) {
              _page = value;
              _refresh();
            },
            onPageSizeChanged: (_) {},
          ),
        ],
      );
    },
  );
}

class _CustomerLoans extends StatefulWidget {
  const _CustomerLoans({
    super.key,
    required this.service,
    required this.token,
    required this.customerId,
    required this.dateFormatter,
  });
  final CustomerDetailsService service;
  final String token, customerId;
  final String Function(DateTime) dateFormatter;
  @override
  State<_CustomerLoans> createState() => _CustomerLoansState();
}

class _CustomerLoansState extends State<_CustomerLoans> {
  static const _pageSize = 10;
  int _activePage = 1, _completedPage = 1, _applicationsPage = 1;
  late Future<AdminLoanPage> _activeFuture, _completedFuture;
  late Future<AdminLoanApplicationPage> _applicationsFuture;
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _activeFuture = _loadLoans(1, _activePage);
    _completedFuture = _loadLoans(2, _completedPage);
    _applicationsFuture = widget.service.getLoanApplications(
      token: widget.token,
      customerId: widget.customerId,
      page: _applicationsPage,
      pageSize: _pageSize,
    );
  }

  Future<AdminLoanPage> _loadLoans(int status, int page) =>
      widget.service.getLoans(
        token: widget.token,
        customerId: widget.customerId,
        status: status,
        page: page,
        pageSize: _pageSize,
      );

  void _refresh() => setState(_loadAll);
  Future<void> _openLoan(AdminLoanListItem item) async {
    try {
      final details = await widget.service.getLoanDetails(
        token: widget.token,
        id: item.loanId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AdminLoanDetailsDialog(
          details: details,
          dateFormatter: widget.dateFormatter,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(error))));
      }
    }
  }

  Future<void> _openApplication(AdminLoanApplicationListItem item) async {
    try {
      final details = await widget.service.getLoanApplicationDetails(
        token: widget.token,
        id: item.applicationId,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => LoanApplicationDetailsDialog(
          details: details,
          dateFormatter: widget.dateFormatter,
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      _paged<AdminLoanPage>(
        title: 'Active Loans',
        future: _activeFuture,
        items: (p) => p.items,
        totalPages: (p) => p.totalPages,
        totalCount: (p) => p.totalCount,
        page: _activePage,
        onPage: (value) => setState(() {
          _activePage = value;
          _activeFuture = _loadLoans(1, value);
        }),
        content: (items) => _loanTiles(items.cast<AdminLoanListItem>()),
      ),
      _paged<AdminLoanPage>(
        title: 'Completed Loans',
        future: _completedFuture,
        items: (p) => p.items,
        totalPages: (p) => p.totalPages,
        totalCount: (p) => p.totalCount,
        page: _completedPage,
        onPage: (value) => setState(() {
          _completedPage = value;
          _completedFuture = _loadLoans(2, value);
        }),
        content: (items) => _loanTiles(items.cast<AdminLoanListItem>()),
      ),
      _paged<AdminLoanApplicationPage>(
        title: 'Loan Applications',
        future: _applicationsFuture,
        items: (p) => p.items,
        totalPages: (p) => p.totalPages,
        totalCount: (p) => p.totalCount,
        page: _applicationsPage,
        onPage: (value) => setState(() {
          _applicationsPage = value;
          _applicationsFuture = widget.service.getLoanApplications(
            token: widget.token,
            customerId: widget.customerId,
            page: value,
            pageSize: _pageSize,
          );
        }),
        content: (items) => Column(
          children: items
              .cast<AdminLoanApplicationListItem>()
              .map(
                (item) => ListTile(
                  title: Text(item.productName),
                  subtitle: Text(
                    '${widget.dateFormatter(item.submittedAtUtc)} · ${adminLoanStatusLabel(item.status)}',
                  ),
                  trailing: Text(
                    '${item.currency} ${AdminFormatters.number(item.principal)}',
                  ),
                  onTap: () => _openApplication(item),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  Widget _loanTiles(List<AdminLoanListItem> items) => Column(
    children: items
        .map(
          (item) => ListTile(
            title: Text(item.productName),
            subtitle: Text(
              '${item.currency} · ${item.paidInstallments}/${item.termMonths} paid',
            ),
            trailing: Text(
              '${item.currency} ${AdminFormatters.number(item.outstandingPrincipal)}',
            ),
            onTap: () => _openLoan(item),
          ),
        )
        .toList(),
  );

  Widget _paged<T>({
    required String title,
    required Future<T> future,
    required List<Object> Function(T) items,
    required int Function(T) totalPages,
    required int Function(T) totalCount,
    required int page,
    required ValueChanged<int> onPage,
    required Widget Function(List<Object>) content,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: _Section(
      title: title,
      child: FutureBuilder<T>(
        future: future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 90, child: AppLoadingState());
          }
          if (snapshot.hasError) {
            return AppErrorState(
              message: AppErrorMessage.from(
                snapshot.error!,
                fallback: 'Unable to load loans.',
              ),
              onRetry: _refresh,
            );
          }
          final data = snapshot.requireData, values = items(data);
          return Column(
            children: [
              if (values.isEmpty) const Text('No records') else content(values),
              if (totalPages(data) > 1)
                AppPagination(
                  currentPage: page,
                  totalPages: totalPages(data),
                  pageSize: _pageSize,
                  shownCount: values.length,
                  totalCount: totalCount(data),
                  itemLabel: 'records',
                  showPageSizeSelector: false,
                  onPageSelected: onPage,
                  onPageSizeChanged: (_) {},
                ),
            ],
          );
        },
      ),
    ),
  );
}

// Retained as the compact loan-row presentation used by related admin views.
// ignore: unused_element
class _LoanGroup extends StatelessWidget {
  const _LoanGroup({
    required this.title,
    required this.items,
    required this.dateFormatter,
    required this.onView,
  });
  final String title;
  final List<AdminLoanListItem> items;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<AdminLoanListItem> onView;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: _Section(
      title: title,
      child: items.isEmpty
          ? const Text('No records')
          : Column(
              children: items
                  .map(
                    (item) => ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.currency} · ${item.annualInterestRate.toStringAsFixed(2)}% · ${item.paidInstallments}/${item.termMonths} paid',
                      ),
                      trailing: Text(
                        '${item.currency} ${AdminFormatters.number(item.status == AdminLoanLifecycleStatus.active ? item.outstandingPrincipal : item.totalPaid)}',
                      ),
                      onTap: () => onView(item),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}

class _CustomerRequests extends StatefulWidget {
  const _CustomerRequests({
    super.key,
    required this.service,
    required this.token,
    required this.customerId,
    required this.dateFormatter,
  });
  final CustomerDetailsService service;
  final String token, customerId;
  final String Function(DateTime) dateFormatter;
  @override
  State<_CustomerRequests> createState() => _CustomerRequestsState();
}

class _CustomerRequestsState extends State<_CustomerRequests> {
  static const _pageSize = 10;
  int _cardPage = 1, _reviewPage = 1;
  late Future<AdminCardRequestPage> _cardsFuture;
  late Future<AdminTransactionPage> _reviewsFuture;
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _cardsFuture = widget.service.getCardRequests(
      token: widget.token,
      customerId: widget.customerId,
      page: _cardPage,
      pageSize: _pageSize,
    );
    _reviewsFuture = widget.service.getTransactions(
      token: widget.token,
      customerId: widget.customerId,
      page: _reviewPage,
      pageSize: _pageSize,
      reviewsOnly: true,
    );
  }

  void _refresh() => setState(_loadAll);
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      FutureBuilder<AdminCardRequestPage>(
        future: _cardsFuture,
        builder: (_, snapshot) => _requestState(
          snapshot,
          'Card Requests',
          (data) => _RequestGroup(
            title: 'Card Requests',
            cards: data.items,
            dateFormatter: widget.dateFormatter,
          ),
          _cardPage,
          (value) => setState(() {
            _cardPage = value;
            _cardsFuture = widget.service.getCardRequests(
              token: widget.token,
              customerId: widget.customerId,
              page: value,
              pageSize: _pageSize,
            );
          }),
        ),
      ),
      const SizedBox(height: 14),
      FutureBuilder<AdminTransactionPage>(
        future: _reviewsFuture,
        builder: (_, snapshot) => _reviewState(
          snapshot,
          (data) => _ReviewGroup(
            items: data.items,
            dateFormatter: widget.dateFormatter,
          ),
          _reviewPage,
          (value) => setState(() {
            _reviewPage = value;
            _reviewsFuture = widget.service.getTransactions(
              token: widget.token,
              customerId: widget.customerId,
              page: value,
              pageSize: _pageSize,
              reviewsOnly: true,
            );
          }),
        ),
      ),
    ],
  );

  Widget _requestState(
    AsyncSnapshot<AdminCardRequestPage> snapshot,
    String title,
    Widget Function(AdminCardRequestPage) content,
    int page,
    ValueChanged<int> onPage,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SizedBox(height: 100, child: AppLoadingState());
    }
    if (snapshot.hasError) {
      return AppErrorState(
        message: AppErrorMessage.from(
          snapshot.error!,
          fallback: 'Unable to load card requests.',
        ),
        onRetry: _refresh,
      );
    }
    final data = snapshot.requireData;
    return Column(
      children: [
        content(data),
        if (data.totalPages > 1)
          AppPagination(
            currentPage: page,
            totalPages: data.totalPages,
            pageSize: _pageSize,
            shownCount: data.items.length,
            totalCount: data.totalCount,
            itemLabel: 'requests',
            showPageSizeSelector: false,
            onPageSelected: onPage,
            onPageSizeChanged: (_) {},
          ),
      ],
    );
  }

  Widget _reviewState(
    AsyncSnapshot<AdminTransactionPage> snapshot,
    Widget Function(AdminTransactionPage) content,
    int page,
    ValueChanged<int> onPage,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SizedBox(height: 100, child: AppLoadingState());
    }
    if (snapshot.hasError) {
      return AppErrorState(
        message: AppErrorMessage.from(
          snapshot.error!,
          fallback: 'Unable to load transaction reviews.',
        ),
        onRetry: _refresh,
      );
    }
    final data = snapshot.requireData;
    return Column(
      children: [
        content(data),
        if (data.totalPages > 1)
          AppPagination(
            currentPage: page,
            totalPages: data.totalPages,
            pageSize: _pageSize,
            shownCount: data.items.length,
            totalCount: data.totalCount,
            itemLabel: 'reviews',
            showPageSizeSelector: false,
            onPageSelected: onPage,
            onPageSizeChanged: (_) {},
          ),
      ],
    );
  }
}

class _RequestGroup extends StatelessWidget {
  const _RequestGroup({
    required this.title,
    required this.cards,
    required this.dateFormatter,
  });
  final String title;
  final List<AdminCardRequest> cards;
  final String Function(DateTime) dateFormatter;
  @override
  Widget build(BuildContext context) => _Section(
    title: title,
    child: Column(
      children: cards
          .map(
            (item) => ListTile(
              title: Text('${item.currency} card request'),
              subtitle: Text(
                '${dateFormatter(item.createdAtUtc)} · ${item.adminNote ?? 'No admin note'}',
              ),
              trailing: AppStatusBadge(status: item.status),
            ),
          )
          .toList(),
    ),
  );
}

class _ReviewGroup extends StatelessWidget {
  const _ReviewGroup({required this.items, required this.dateFormatter});
  final List<AdminTransaction> items;
  final String Function(DateTime) dateFormatter;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: _Section(
      title: 'Transaction Reviews',
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                title: Text(item.referenceNumber),
                subtitle: Text(item.reviewReason ?? 'Review required'),
                trailing: Text(
                  '${item.currency} ${AdminFormatters.number(item.amount)} · ${item.status}',
                ),
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          child,
        ],
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

String _initials(AdminCustomerDetails value) =>
    '${value.firstName.isEmpty ? '' : value.firstName[0]}${value.lastName.isEmpty ? '' : value.lastName[0]}'
        .toUpperCase();
