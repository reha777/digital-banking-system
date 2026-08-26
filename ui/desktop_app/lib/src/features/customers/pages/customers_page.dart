import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_error_message.dart';

import '../../../core/api_client.dart';
import '../../../widgets/admin_modal.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_states.dart';
import '../admin_customer_models.dart';
import '../admin_customer_service.dart';
import '../widgets/customer_edit_dialog.dart';
import '../widgets/customer_filters.dart';
import '../widgets/customer_summary_cards.dart';
import '../widgets/customers_table.dart';
import 'customer_details_page.dart';
import '../customer_details_service.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({
    super.key,
    required this.token,
    required this.defaultPageSize,
    required this.dateFormatter,
    this.service,
    this.detailsService,
    this.showHeader = true,
  });

  final String token;
  final int defaultPageSize;
  final String Function(DateTime) dateFormatter;
  final AdminCustomerService? service;
  final CustomerDetailsService? detailsService;
  final bool showHeader;

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _searchController = TextEditingController();
  final _tableScrollController = ScrollController();
  late final AdminCustomerService _service;
  late Future<_CustomersData> _customersFuture;
  Timer? _searchDebounce;
  int _page = 1;
  late int _pageSize;
  int? _status;
  String? _selectedCustomerId;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.defaultPageSize;
    _service = widget.service ?? AdminCustomerService(ApiClient());
    _customersFuture = _loadCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<_CustomersData> _loadCustomers() async {
    final results = await Future.wait<Object>([
      _service.getCustomers(
        token: widget.token,
        page: _page,
        pageSize: _pageSize,
        search: _searchController.text,
        status: _status,
      ),
      _service.getSummary(
        token: widget.token,
        search: _searchController.text,
        status: _status,
      ),
    ]);

    return _CustomersData(
      page: results[0] as AdminCustomerPage,
      summary: results[1] as AdminCustomerSummary,
    );
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _customersFuture = _loadCustomers());
  }

  void _refreshFromFirstPage() {
    _page = 1;
    _scrollToTop();
    _refresh();
  }

  void _scrollToTop() {
    if (_tableScrollController.hasClients) {
      _tableScrollController.jumpTo(0);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _refreshFromFirstPage,
    );
  }

  void _resetFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _status = null;
    _refreshFromFirstPage();
  }

  Future<void> _editCustomer(AdminCustomer customer) async {
    final request = await showDialog<CustomerEditRequest>(
      context: context,
      builder: (_) => CustomerEditDialog(customer: customer),
    );
    if (request == null) return;

    try {
      await _service.updateCustomer(
        token: widget.token,
        id: customer.id,
        firstName: request.firstName,
        lastName: request.lastName,
        phoneNumber: request.phoneNumber,
      );
      if (!mounted) return;
      _showMessage('Customer updated successfully.');
      _refresh();
    } on ApiException catch (error) {
      if (mounted) _showMessage(AppErrorMessage.from(error));
    }
  }

  Future<void> _changeStatus(AdminCustomer customer, int status) async {
    if (status == customer.statusValue) return;

    try {
      await _service.updateStatus(
        token: widget.token,
        id: customer.id,
        status: status,
      );
      if (!mounted) return;
      _showMessage('Customer status updated.');
      _refresh();
    } on ApiException catch (error) {
      if (mounted) _showMessage(AppErrorMessage.from(error));
    }
  }

  Future<void> _deleteCustomer(AdminCustomer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AdminModal(
        title: 'Delete customer',
        primaryLabel: 'Delete',
        primaryColor: const Color(0xFFDC2626),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        width: 460,
        children: [
          Text('Remove ${customer.fullName} from active customer records?'),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteCustomer(token: widget.token, id: customer.id);
      if (!mounted) return;
      _showMessage('Customer deleted.');
      _refreshFromFirstPage();
    } on ApiException catch (error) {
      if (mounted) _showMessage(AppErrorMessage.from(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCustomerId case final customerId?) {
      return CustomerDetailsPage(
        token: widget.token,
        customerId: customerId,
        dateFormatter: widget.dateFormatter,
        onBack: () => setState(() => _selectedCustomerId = null),
        onCustomerUpdated: _refresh,
        service: widget.detailsService,
        customerService: _service,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          const AppPageHeader(
            icon: LucideIcons.users,
            title: 'Customers',
            subtitle:
                'Manage customer records, status and contact information.',
          ),
          const SizedBox(height: 22),
        ],
        CustomerFilters(
          searchController: _searchController,
          status: _status,
          onSearchChanged: _onSearchChanged,
          onStatusChanged: (value) {
            _status = value;
            _refreshFromFirstPage();
          },
          onRefresh: _refresh,
          onReset: _resetFilters,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: FutureBuilder<_CustomersData>(
            future: _customersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const AppLoadingState();
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  message: AppErrorMessage.from(
                    snapshot.error!,
                    fallback: 'Unable to load customers.',
                  ),
                  onRetry: _refresh,
                );
              }

              final data = snapshot.requireData;
              if (data.page.items.isEmpty) {
                return AppEmptyState(
                  icon: LucideIcons.users,
                  title: 'No customers found',
                  message: 'Try changing the search or status filter.',
                  onReset: _resetFilters,
                );
              }

              return Column(
                children: [
                  if (snapshot.connectionState != ConnectionState.done)
                    const LinearProgressIndicator(minHeight: 2),
                  CustomerSummaryCards(summary: data.summary),
                  const SizedBox(height: 16),
                  Expanded(
                    child: CustomersTable(
                      dateFormatter: widget.dateFormatter,
                      page: data.page,
                      pageSize: _pageSize,
                      controller: _tableScrollController,
                      onEdit: _editCustomer,
                      onView: (customer) =>
                          setState(() => _selectedCustomerId = customer.id),
                      onDelete: _deleteCustomer,
                      onStatusChanged: _changeStatus,
                      onPageSelected: (page) {
                        _page = page;
                        _scrollToTop();
                        _refresh();
                      },
                      onPageSizeChanged: (pageSize) {
                        _pageSize = pageSize;
                        _refreshFromFirstPage();
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
}

class _CustomersData {
  const _CustomersData({required this.page, required this.summary});

  final AdminCustomerPage page;
  final AdminCustomerSummary summary;
}
