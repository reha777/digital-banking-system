import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/admin_modal.dart';
import '../auth/admin_login_screen.dart';
import '../auth/auth_session.dart';
import '../customers/admin_customer_models.dart';
import '../customers/admin_customer_service.dart';
import '../transactions/admin_transaction_models.dart';
import '../transactions/admin_transaction_service.dart';

enum _AdminSection { transactions, customers }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _tableScrollController = ScrollController();
  final _customerTableScrollController = ScrollController();
  late final AdminTransactionService _transactionService;
  late final AdminCustomerService _customerService;
  late Future<_TransactionsViewData> _transactionsFuture;
  late Future<_CustomersViewData> _customersFuture;
  Timer? _searchDebounce;
  Timer? _customerSearchDebounce;
  _AdminSection _selectedSection = _AdminSection.transactions;
  int _page = 1;
  int _pageSize = 10;
  int? _status;
  DateTimeRange? _dateRange;
  int _customerPage = 1;
  int _customerPageSize = 10;
  int? _customerStatus;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _transactionService = AdminTransactionService(apiClient);
    _customerService = AdminCustomerService(apiClient);
    _transactionsFuture = _loadTransactions();
    _customersFuture = _loadCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _customerSearchDebounce?.cancel();
    _searchController.dispose();
    _customerSearchController.dispose();
    _tableScrollController.dispose();
    _customerTableScrollController.dispose();
    super.dispose();
  }

  Future<_TransactionsViewData> _loadTransactions() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    final page = await _transactionService.getTransactions(
      token: token,
      page: _page,
      pageSize: _pageSize,
      search: _searchController.text,
      status: _status,
      dateFrom: _dateRange?.start,
      dateTo: _dateRange?.end,
    );
    final summary = await _transactionService.getSummary(
      token: token,
      search: _searchController.text,
      status: _status,
      dateFrom: _dateRange?.start,
      dateTo: _dateRange?.end,
    );

    return _TransactionsViewData(page: page, summary: summary);
  }

  Future<_CustomersViewData> _loadCustomers() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    final page = await _customerService.getCustomers(
      token: token,
      page: _customerPage,
      pageSize: _customerPageSize,
      search: _customerSearchController.text,
      status: _customerStatus,
    );
    final summary = await _customerService.getSummary(
      token: token,
      search: _customerSearchController.text,
      status: _customerStatus,
    );

    return _CustomersViewData(page: page, summary: summary);
  }

  void _refresh() {
    setState(() {
      _transactionsFuture = _loadTransactions();
    });
  }

  void _refreshCustomers() {
    setState(() {
      _customersFuture = _loadCustomers();
    });
  }

  void _refreshFromFirstPage() {
    _page = 1;
    _scrollTableTop();
    _refresh();
  }

  void _refreshCustomersFromFirstPage() {
    _customerPage = 1;
    _scrollCustomerTableTop();
    _refreshCustomers();
  }

  void _scrollTableTop() {
    if (_tableScrollController.hasClients) {
      _tableScrollController.jumpTo(0);
    }
  }

  void _scrollCustomerTableTop() {
    if (_customerTableScrollController.hasClients) {
      _customerTableScrollController.jumpTo(0);
    }
  }

  void _searchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _refreshFromFirstPage();
    });
  }

  void _customerSearchChanged(String _) {
    _customerSearchDebounce?.cancel();
    _customerSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _refreshCustomersFromFirstPage();
    });
  }

  void _selectSection(_AdminSection section) {
    setState(() {
      _selectedSection = section;
    });
  }

  Future<void> _pickDateRange() async {
    final selected = await showDialog<DateTimeRange?>(
      context: context,
      builder: (context) {
        return _DateRangeDialog(initialRange: _dateRange);
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _dateRange = selected;
    });
    _refreshFromFirstPage();
  }

  void _clearDateRange() {
    setState(() {
      _dateRange = null;
    });
    _refreshFromFirstPage();
  }

  Future<void> _editCustomer(AdminCustomer customer) async {
    final token = widget.session.token;
    if (token == null) {
      return;
    }

    final request = await showDialog<_CustomerEditRequest?>(
      context: context,
      builder: (context) => _CustomerEditDialog(customer: customer),
    );

    if (request == null) {
      return;
    }

    try {
      await _customerService.updateCustomer(
        token: token,
        id: customer.id,
        firstName: request.firstName,
        lastName: request.lastName,
        phoneNumber: request.phoneNumber,
      );
      _refreshCustomers();
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    }
  }

  Future<void> _changeCustomerStatus(AdminCustomer customer, int status) async {
    final token = widget.session.token;
    if (token == null || status == customer.statusValue) {
      return;
    }

    try {
      await _customerService.updateStatus(
        token: token,
        id: customer.id,
        status: status,
      );
      _refreshCustomers();
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    }
  }

  Future<void> _deleteCustomer(AdminCustomer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AdminModal(
        title: 'Delete customer',
        primaryLabel: 'Delete',
        primaryColor: const Color(0xFFDC2626),
        onPrimary: () => Navigator.of(context).pop(true),
        width: 460,
        children: [
          Text(
            'Remove ${customer.fullName} from active customer records?',
            style: const TextStyle(
              color: AppTheme.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final token = widget.session.token;
    if (token == null) {
      return;
    }

    try {
      await _customerService.deleteCustomer(token: token, id: customer.id);
      _refreshCustomersFromFirstPage();
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminLoginScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;

    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(
            userName: '${user?.firstName ?? 'Admin'} ${user?.lastName ?? ''}'.trim(),
            selectedSection: _selectedSection,
            onSectionSelected: _selectSection,
            onLogout: _logout,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PageTitle(
                    icon: _selectedSection == _AdminSection.transactions
                        ? Icons.receipt_long
                        : Icons.people_outline,
                    title: _selectedSection == _AdminSection.transactions
                        ? 'Transactions'
                        : 'Customers',
                    subtitle: _selectedSection == _AdminSection.transactions
                        ? 'Search, filter and review customer money movement.'
                        : 'Manage customer records, status and contact information.',
                  ),
                  const SizedBox(height: 22),
                  if (_selectedSection == _AdminSection.transactions)
                    _FiltersBar(
                      searchController: _searchController,
                      status: _status,
                      dateRange: _dateRange,
                      onSearchChanged: _searchChanged,
                      onStatusChanged: (value) {
                        _status = value;
                        _refreshFromFirstPage();
                      },
                      onPickDateRange: _pickDateRange,
                      onClearDateRange: _clearDateRange,
                      onRefresh: _refresh,
                    )
                  else
                    _CustomerFiltersBar(
                      searchController: _customerSearchController,
                      status: _customerStatus,
                      onSearchChanged: _customerSearchChanged,
                      onStatusChanged: (value) {
                        _customerStatus = value;
                        _refreshCustomersFromFirstPage();
                      },
                      onRefresh: _refreshCustomers,
                    ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: _selectedSection == _AdminSection.transactions
                        ? FutureBuilder<_TransactionsViewData>(
                            future: _transactionsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState != ConnectionState.done) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return _AdminErrorState(
                                  message: snapshot.error.toString(),
                                  onRetry: _refresh,
                                );
                              }

                              final data = snapshot.requireData;
                              return Column(
                                children: [
                                  _SummaryCards(summary: data.summary),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _TransactionsTable(
                                      page: data.page,
                                      currentPage: _page,
                                      pageSize: _pageSize,
                                      scrollController: _tableScrollController,
                                      onPageSelected: (pageNumber) {
                                        _page = pageNumber;
                                        _scrollTableTop();
                                        _refresh();
                                      },
                                      onPageSizeChanged: (value) {
                                        _pageSize = value;
                                        _refreshFromFirstPage();
                                      },
                                      onPrevious: data.page.page <= 1
                                          ? null
                                          : () {
                                              _page--;
                                              _scrollTableTop();
                                              _refresh();
                                            },
                                      onNext: data.page.page >= data.page.totalPages
                                          ? null
                                          : () {
                                              _page++;
                                              _scrollTableTop();
                                              _refresh();
                                            },
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        : FutureBuilder<_CustomersViewData>(
                            future: _customersFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState != ConnectionState.done) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError) {
                                return _AdminErrorState(
                                  message: snapshot.error.toString(),
                                  onRetry: _refreshCustomers,
                                );
                              }

                              final data = snapshot.requireData;
                              return Column(
                                children: [
                                  _CustomerSummaryCards(summary: data.summary),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: _CustomersTable(
                                      page: data.page,
                                      currentPage: _customerPage,
                                      pageSize: _customerPageSize,
                                      scrollController: _customerTableScrollController,
                                      onEdit: _editCustomer,
                                      onDelete: _deleteCustomer,
                                      onStatusChanged: _changeCustomerStatus,
                                      onPageSelected: (pageNumber) {
                                        _customerPage = pageNumber;
                                        _scrollCustomerTableTop();
                                        _refreshCustomers();
                                      },
                                      onPageSizeChanged: (value) {
                                        _customerPageSize = value;
                                        _refreshCustomersFromFirstPage();
                                      },
                                      onPrevious: data.page.page <= 1
                                          ? null
                                          : () {
                                              _customerPage--;
                                              _scrollCustomerTableTop();
                                              _refreshCustomers();
                                            },
                                      onNext: data.page.page >= data.page.totalPages
                                          ? null
                                          : () {
                                              _customerPage++;
                                              _scrollCustomerTableTop();
                                              _refreshCustomers();
                                            },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsViewData {
  const _TransactionsViewData({
    required this.page,
    required this.summary,
  });

  final AdminTransactionPage page;
  final AdminTransactionSummary summary;
}

class _CustomersViewData {
  const _CustomersViewData({
    required this.page,
    required this.summary,
  });

  final AdminCustomerPage page;
  final AdminCustomerSummary summary;
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final AdminTransactionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total transactions',
            value: summary.totalTransactions.toString(),
            icon: Icons.receipt_long,
            tone: const Color(0xFF0066FF),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            title: 'Completed',
            value: summary.completedTransactions.toString(),
            icon: Icons.check_circle_outline,
            tone: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            title: 'Total transferred',
            value: _formatAdminAmount(summary.totalTransferred),
            icon: Icons.payments_outlined,
            tone: const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: tone),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSummaryCards extends StatelessWidget {
  const _CustomerSummaryCards({required this.summary});

  final AdminCustomerSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Total customers',
            value: summary.totalCustomers.toString(),
            icon: Icons.people_outline,
            tone: const Color(0xFF0066FF),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            title: 'Active',
            value: summary.activeCustomers.toString(),
            icon: Icons.verified_user_outlined,
            tone: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            title: 'Inactive / blocked',
            value: '${summary.inactiveCustomers + summary.blockedCustomers}',
            icon: Icons.person_off_outlined,
            tone: const Color(0xFFF97316),
          ),
        ),
      ],
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.userName,
    required this.selectedSection,
    required this.onSectionSelected,
    required this.onLogout,
  });

  final String userName;
  final _AdminSection selectedSection;
  final ValueChanged<_AdminSection> onSectionSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: const Color(0xFF111827),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text(
                'BankPick',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SidebarItem(
            icon: Icons.receipt_long,
            title: 'Transactions',
            isActive: selectedSection == _AdminSection.transactions,
            onTap: () => onSectionSelected(_AdminSection.transactions),
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            title: 'Customers',
            isActive: selectedSection == _AdminSection.customers,
            onTap: () => onSectionSelected(_AdminSection.customers),
          ),
          const _SidebarItem(
            icon: Icons.credit_card,
            title: 'Cards',
          ),
          const _SidebarItem(
            icon: Icons.bar_chart,
            title: 'Reports',
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF374151),
                  child: Icon(Icons.person, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    userName.isEmpty ? 'Admin' : userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.title,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0x1F0066FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.searchController,
    required this.status,
    required this.dateRange,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final int? status;
  final DateTimeRange? dateRange;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 390,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search reference, customer or account',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _StatusFilterButton(
            status: status,
            onChanged: onStatusChanged,
          ),
          const SizedBox(width: 14),
          _DateRangeButton(
            dateRange: dateRange,
            onPressed: onPickDateRange,
            onClear: dateRange == null ? null : onClearDateRange,
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F6FF),
              foregroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerFiltersBar extends StatelessWidget {
  const _CustomerFiltersBar({
    required this.searchController,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final int? status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int?> onStatusChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 430,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search name, email, phone or account',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _CustomerStatusFilterButton(
            status: status,
            onChanged: onStatusChanged,
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F6FF),
              foregroundColor: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerStatusFilterButton extends StatelessWidget {
  const _CustomerStatusFilterButton({
    required this.status,
    required this.onChanged,
  });

  final int? status;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Customer status filter',
      position: PopupMenuPosition.under,
      onSelected: (value) => onChanged(value == 0 ? null : value),
      itemBuilder: (context) => const [
        PopupMenuItem<int>(
          value: 0,
          child: Text('All statuses'),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Text('Active'),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Text('Inactive'),
        ),
        PopupMenuItem<int>(
          value: 3,
          child: Text('Blocked'),
        ),
      ],
      child: _FilterChipButton(
        icon: Icons.tune,
        label: _customerStatusFilterLabel(status),
        trailing: const Icon(Icons.keyboard_arrow_down, size: 20),
      ),
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({
    required this.dateRange,
    required this.onPressed,
    required this.onClear,
  });

  final DateTimeRange? dateRange;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final label = dateRange == null
        ? 'Date range'
        : '${_formatDate(dateRange!.start)} - ${_formatDate(dateRange!.end)}';

    return Container(
      height: 54,
      constraints: const BoxConstraints(minWidth: 210),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textDark,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
          if (onClear != null)
            IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear date range',
            ),
        ],
      ),
    );
  }
}

class _StatusFilterButton extends StatelessWidget {
  const _StatusFilterButton({
    required this.status,
    required this.onChanged,
  });

  final int? status;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Status filter',
      position: PopupMenuPosition.under,
      onSelected: (value) => onChanged(value == 0 ? null : value),
      itemBuilder: (context) => const [
        PopupMenuItem<int>(
          value: 0,
          child: Text('All statuses'),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Text('Pending'),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Text('Completed'),
        ),
        PopupMenuItem<int>(
          value: 3,
          child: Text('Failed'),
        ),
        PopupMenuItem<int>(
          value: 4,
          child: Text('Cancelled'),
        ),
      ],
      child: _FilterChipButton(
        icon: Icons.tune,
        label: _statusFilterLabel(status),
        trailing: const Icon(Icons.keyboard_arrow_down, size: 20),
      ),
    );
  }
}

class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({required this.initialRange});

  final DateTimeRange? initialRange;

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(
      text: _formatInputDate(widget.initialRange?.start),
    );
    _toController = TextEditingController(
      text: _formatInputDate(widget.initialRange?.end),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _setQuickRange(DateTime start, DateTime end) {
    setState(() {
      _error = null;
      _fromController.text = _formatInputDate(start);
      _toController.text = _formatInputDate(end);
    });
  }

  void _apply() {
    final from = _parseDateInput(_fromController.text);
    final to = _parseDateInput(_toController.text);

    if (from == null || to == null) {
      setState(() {
        _error = 'Use format YYYY-MM-DD or DD.MM.YYYY.';
      });
      return;
    }

    if (from.isAfter(to)) {
      setState(() {
        _error = 'From date must be before To date.';
      });
      return;
    }

    Navigator.of(context).pop(DateTimeRange(start: from, end: to));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Period',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Type a date or use a quick period.',
                style: TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickRangeButton(
                    label: 'Today',
                    onPressed: () => _setQuickRange(today, today),
                  ),
                  _QuickRangeButton(
                    label: 'Last 7 days',
                    onPressed: () => _setQuickRange(
                      today.subtract(const Duration(days: 6)),
                      today,
                    ),
                  ),
                  _QuickRangeButton(
                    label: 'Last 30 days',
                    onPressed: () => _setQuickRange(
                      today.subtract(const Duration(days: 29)),
                      today,
                    ),
                  ),
                  _QuickRangeButton(
                    label: 'This month',
                    onPressed: () => _setQuickRange(
                      DateTime(today.year, today.month),
                      today,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DateTextField(
                      label: 'From',
                      controller: _fromController,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _DateTextField(
                      label: 'To',
                      controller: _toController,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickRangeButton extends StatelessWidget {
  const _QuickRangeButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.textDark,
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}

class _DateTextField extends StatelessWidget {
  const _DateTextField({
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        prefixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
    );
  }
}

DateTime? _parseDateInput(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return null;
  }

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (isoMatch != null) {
    return _safeDate(
      int.parse(isoMatch.group(1)!),
      int.parse(isoMatch.group(2)!),
      int.parse(isoMatch.group(3)!),
    );
  }

  final localMatch = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\.?$').firstMatch(text);
  if (localMatch != null) {
    return _safeDate(
      int.parse(localMatch.group(3)!),
      int.parse(localMatch.group(2)!),
      int.parse(localMatch.group(1)!),
    );
  }

  return null;
}

DateTime? _safeDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }

  return date;
}

String _formatInputDate(DateTime? value) {
  if (value == null) {
    return '';
  }

  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.page,
    required this.currentPage,
    required this.pageSize,
    required this.scrollController,
    required this.onPageSelected,
    required this.onPageSizeChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final AdminTransactionPage page;
  final int currentPage;
  final int pageSize;
  final ScrollController scrollController;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const _TableHeader(),
          Expanded(
            child: page.items.isEmpty
                ? const Center(child: Text('No transactions found.'))
                : ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFEFF2F7)),
                    itemBuilder: (context, index) {
                      return _TransactionRow(
                        index: ((page.page - 1) * page.pageSize) + index + 1,
                        transaction: page.items[index],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Showing ${page.items.length} of ${page.totalCount} transactions',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                const Spacer(),
                const Text('Rows'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  height: 40,
                  child: DropdownButtonFormField<int>(
                    initialValue: pageSize,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onPageSizeChanged(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 18),
                IconButton.filledTonal(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous page',
                ),
                ..._visiblePages(currentPage, page.totalPages).map(
                  (pageNumber) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PageButton(
                      pageNumber: pageNumber,
                      isActive: pageNumber == currentPage,
                      onPressed: () => onPageSelected(pageNumber),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next page',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _visiblePages(int currentPage, int totalPages) {
    final start = (currentPage - 2).clamp(1, totalPages).toInt();
    final end = (start + 4).clamp(1, totalPages).toInt();
    return [for (var page = start; page <= end; page++) page];
  }
}

class _CustomersTable extends StatelessWidget {
  const _CustomersTable({
    required this.page,
    required this.currentPage,
    required this.pageSize,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
    required this.onPageSelected,
    required this.onPageSizeChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final AdminCustomerPage page;
  final int currentPage;
  final int pageSize;
  final ScrollController scrollController;
  final ValueChanged<AdminCustomer> onEdit;
  final ValueChanged<AdminCustomer> onDelete;
  final void Function(AdminCustomer customer, int status) onStatusChanged;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const _CustomersTableHeader(),
          Expanded(
            child: page.items.isEmpty
                ? const Center(child: Text('No customers found.'))
                : ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFEFF2F7)),
                    itemBuilder: (context, index) {
                      return _CustomerRow(
                        index: ((page.page - 1) * page.pageSize) + index + 1,
                        customer: page.items[index],
                        onEdit: onEdit,
                        onDelete: onDelete,
                        onStatusChanged: onStatusChanged,
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Showing ${page.items.length} of ${page.totalCount} customers',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                const Spacer(),
                const Text('Rows'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  height: 40,
                  child: DropdownButtonFormField<int>(
                    initialValue: pageSize,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 20, child: Text('20')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onPageSizeChanged(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 18),
                IconButton.filledTonal(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous page',
                ),
                ..._visiblePages(currentPage, page.totalPages).map(
                  (pageNumber) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _PageButton(
                      pageNumber: pageNumber,
                      isActive: pageNumber == currentPage,
                      onPressed: () => onPageSelected(pageNumber),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next page',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _visiblePages(int currentPage, int totalPages) {
    final start = (currentPage - 2).clamp(1, totalPages).toInt();
    final end = (start + 4).clamp(1, totalPages).toInt();
    return [for (var page = start; page <= end; page++) page];
  }
}

class _CustomersTableHeader extends StatelessWidget {
  const _CustomersTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          _HeaderCell('SL No', flex: 1),
          _HeaderCell('Customer', flex: 4),
          _HeaderCell('Contact', flex: 4),
          _HeaderCell('Bank accounts', flex: 2),
          _HeaderCell('Balance', flex: 2),
          _HeaderCell('Joined', flex: 2),
          _HeaderCell('Status', flex: 2),
          _HeaderCell('Actions', flex: 2),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.index,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final int index;
  final AdminCustomer customer;
  final ValueChanged<AdminCustomer> onEdit;
  final ValueChanged<AdminCustomer> onDelete;
  final void Function(AdminCustomer customer, int status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          _TableText('${index.toString().padLeft(2, '0')}.', flex: 1),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEAF1FF),
                  child: Text(
                    _customerInitials(customer),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        customer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        customer.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _TableText(customer.phoneNumber, flex: 4),
          _TableText(customer.accountCount.toString(), flex: 2),
          _TableText(_formatAdminAmount(customer.totalBalance), flex: 2),
          _TableText(_formatDate(customer.createdAtUtc), flex: 2),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CustomerStatusMenu(
                customer: customer,
                onChanged: onStatusChanged,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => onEdit(customer),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit customer',
                ),
                IconButton(
                  onPressed: () => onDelete(customer),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete customer',
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerStatusMenu extends StatelessWidget {
  const _CustomerStatusMenu({
    required this.customer,
    required this.onChanged,
  });

  final AdminCustomer customer;
  final void Function(AdminCustomer customer, int status) onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Change status',
      position: PopupMenuPosition.under,
      onSelected: (status) => onChanged(customer, status),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 1, child: Text('Active')),
        PopupMenuItem(value: 2, child: Text('Inactive')),
        PopupMenuItem(value: 3, child: Text('Blocked')),
      ],
      child: _CustomerStatusBadge(status: customer.status),
    );
  }
}

class _CustomerStatusBadge extends StatelessWidget {
  const _CustomerStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      'Active' => (const Color(0xFFE9F9EF), const Color(0xFF16834A)),
      'Blocked' => (const Color(0xFFFFEAEA), const Color(0xFFB91C1C)),
      _ => (const Color(0xFFFFF7E6), const Color(0xFFB7791F)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              color: colors.$2,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 14, color: colors.$2),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: const Row(
        children: [
          _HeaderCell('SL No', flex: 1),
          _HeaderCell('Date', flex: 2),
          _HeaderCell('Reference', flex: 3),
          _HeaderCell('From', flex: 4),
          _HeaderCell('To', flex: 4),
          _HeaderCell('Amount', flex: 2),
          _HeaderCell('Status', flex: 2),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5A77B8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.index,
    required this.transaction,
  });

  final int index;
  final AdminTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          _TableText('${index.toString().padLeft(2, '0')}.', flex: 1),
          _TableText(_formatDate(transaction.createdAtUtc), flex: 2),
          _TableText(_shorten(transaction.referenceNumber, 20), flex: 3),
          _TableText(
            _partyLabel(
              transaction.sourceCustomerName,
              transaction.sourceAccountNumber,
              fallback: transaction.accountNumber,
            ),
            flex: 4,
          ),
          _TableText(
            _partyLabel(
              transaction.destinationCustomerName,
              transaction.destinationAccountNumber,
              fallback: '-',
            ),
            flex: 4,
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatAdminAmount(transaction.amount),
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _StatusBadge(status: transaction.status),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableText extends StatelessWidget {
  const _TableText(this.value, {required this.flex});

  final String value;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textDark,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.pageNumber,
    required this.isActive,
    required this.onPressed,
  });

  final int pageNumber;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: TextButton(
        onPressed: isActive ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFFEAF1FF) : const Color(0xFFF8FAFC),
          foregroundColor: isActive ? AppTheme.primary : AppTheme.textDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isActive ? AppTheme.primary : AppTheme.border,
            ),
          ),
        ),
        child: Text('$pageNumber'),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'Completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE9F9EF) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isCompleted ? const Color(0xFF16834A) : const Color(0xFFB7791F),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _CustomerEditRequest {
  const _CustomerEditRequest({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String phoneNumber;
}

class _CustomerEditDialog extends StatefulWidget {
  const _CustomerEditDialog({required this.customer});

  final AdminCustomer customer;

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.customer.firstName);
    _lastNameController = TextEditingController(text: widget.customer.lastName);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _CustomerEditRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AdminModal(
        title: 'Edit customer',
        primaryLabel: 'Save',
        onPrimary: _save,
        children: [
          AdminModalField(
            controller: _firstNameController,
            label: 'First name',
            icon: Icons.person_outline,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          AdminModalField(
            controller: _lastNameController,
            label: 'Last name',
            icon: Icons.person_outline,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          AdminModalField(
            controller: _phoneController,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            validator: _requiredValidator,
          ),
        ],
      ),
    );
  }
}

String _partyLabel(String? name, String? accountNumber, {required String fallback}) {
  final cleanName = name?.trim();
  final cleanAccount = accountNumber?.trim();

  if (cleanName != null && cleanName.isNotEmpty && cleanAccount != null && cleanAccount.isNotEmpty) {
    return '$cleanName ($cleanAccount)';
  }

  if (cleanAccount != null && cleanAccount.isNotEmpty) {
    return cleanAccount;
  }

  return fallback;
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'This field is required.';
  }

  return null;
}

String _customerInitials(AdminCustomer customer) {
  final first = customer.firstName.isEmpty ? '' : customer.firstName[0];
  final last = customer.lastName.isEmpty ? '' : customer.lastName[0];
  final initials = '$first$last'.trim();
  return initials.isEmpty ? 'C' : initials.toUpperCase();
}

String _shorten(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }

  return '${value.substring(0, maxLength - 1)}...';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.year}.';
}

String _formatAdminAmount(double value) {
  return '\$${value.abs().toStringAsFixed(2)}';
}

String _statusFilterLabel(int? status) {
  return switch (status) {
    1 => 'Pending',
    2 => 'Completed',
    3 => 'Failed',
    4 => 'Cancelled',
    _ => 'All statuses',
  };
}

String _customerStatusFilterLabel(int? status) {
  return switch (status) {
    1 => 'Active',
    2 => 'Inactive',
    3 => 'Blocked',
    _ => 'All statuses',
  };
}
