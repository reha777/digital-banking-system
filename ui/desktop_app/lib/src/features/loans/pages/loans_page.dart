import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_error_message.dart';
import '../../../core/api_client.dart';
import '../../../widgets/app_page_header.dart';
import '../../../widgets/app_page_states.dart';
import '../../../widgets/app_status_tabs.dart';
import '../admin_loan_service.dart';
import '../models/admin_loan_models.dart';
import '../widgets/loan_widgets.dart';
import '../widgets/admin_loans_widgets.dart';

enum _LoanTab { applications, active, completed }

class LoansPage extends StatefulWidget {
  const LoansPage({
    super.key,
    required this.token,
    required this.defaultPageSize,
    required this.dateFormatter,
    this.repository,
  });
  final String token;
  final int defaultPageSize;
  final String Function(DateTime) dateFormatter;
  final AdminLoanRepository? repository;
  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoanData {
  const _LoanData(this.page, this.summary);
  final AdminLoanApplicationPage page;
  final AdminLoanSummary summary;
}

class _LoansPageState extends State<LoansPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late final AdminLoanRepository _repository;
  late Future<_LoanData> _future;
  late int _pageSize;
  int _page = 1;
  int? _status;
  _LoanTab _tab = _LoanTab.applications;
  Future<_AdminLoansData>? _loansFuture;
  DateTime? _loanDateFrom, _loanDateTo;
  DateTimeRange? _applicationDateRange;
  bool? _overdueOnly;
  @override
  void initState() {
    super.initState();
    _pageSize = widget.defaultPageSize;
    _repository = widget.repository ?? AdminLoanService(ApiClient());
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<_LoanData> _load() async {
    final values = await Future.wait<Object>([
      _repository.getApplications(
        token: widget.token,
        page: _page,
        pageSize: _pageSize,
        search: _search.text,
        status: _status,
        dateFromUtc: _applicationDateRange?.start,
        dateToUtc: _applicationDateRange?.end,
      ),
      _repository.getSummary(
        token: widget.token,
        search: _search.text,
        status: _status,
        dateFromUtc: _applicationDateRange?.start,
        dateToUtc: _applicationDateRange?.end,
      ),
    ]);
    return _LoanData(
      values[0] as AdminLoanApplicationPage,
      values[1] as AdminLoanSummary,
    );
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _future = _load();
      });
    }
  }

  void _firstPage() {
    _page = 1;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _refresh();
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _firstPage);
  }

  void _reset() {
    _debounce?.cancel();
    _search.clear();
    _status = null;
    _applicationDateRange = null;
    _firstPage();
  }

  Future<_AdminLoansData> _loadLoans() async {
    final values = await Future.wait<Object>([
      _repository.getLoans(
        token: widget.token,
        page: _page,
        pageSize: _pageSize,
        status: _tab == _LoanTab.active ? 1 : 2,
        search: _search.text,
        dateFromUtc: _loanDateFrom,
        dateToUtc: _loanDateTo,
        overdueOnly: _tab == _LoanTab.active ? _overdueOnly : null,
      ),
      _repository.getLoansOverview(token: widget.token),
    ]);
    return _AdminLoansData(
      values[0] as AdminLoanPage,
      values[1] as AdminLoansOverview,
    );
  }

  void _refreshLoans() {
    setState(() {
      _loansFuture = _loadLoans();
    });
  }

  void _changeTab(_LoanTab value) {
    _debounce?.cancel();
    _search.clear();
    _status = null;
    _page = 1;
    _loanDateFrom = null;
    _loanDateTo = null;
    _overdueOnly = null;
    setState(() {
      _tab = value;
      if (value != _LoanTab.applications) _loansFuture = _loadLoans();
    });
  }

  Future<void> _loanDetails(AdminLoanListItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => FutureBuilder<AdminLoanDetails>(
        future: _repository.getLoanDetails(
          token: widget.token,
          id: item.loanId,
        ),
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Dialog(
              child: SizedBox(
                width: 500,
                height: 300,
                child: AppLoadingState(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Dialog(
              child: SizedBox(
                width: 500,
                height: 300,
                child: AppErrorState(
                  message: AppErrorMessage.from(
                    snapshot.error!,
                    fallback: 'Unable to load loan applications.',
                  ),
                  onRetry: () {
                    Navigator.pop(context);
                    _loanDetails(item);
                  },
                ),
              ),
            );
          }
          return AdminLoanDetailsDialog(
            details: snapshot.requireData,
            dateFormatter: widget.dateFormatter,
          );
        },
      ),
    );
  }

  Future<void> _details(AdminLoanApplicationListItem item) async {
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (_) => FutureBuilder<AdminLoanApplicationDetails>(
        future: _repository.getApplicationDetails(
          token: widget.token,
          id: item.applicationId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Dialog(
              child: SizedBox(
                width: 420,
                height: 220,
                child: AppLoadingState(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Dialog(
              child: SizedBox(
                width: 480,
                height: 260,
                child: AppErrorState(
                  message: AppErrorMessage.from(
                    snapshot.error!,
                    fallback: 'Unable to load loan applications.',
                  ),
                  onRetry: () {
                    Navigator.pop(context);
                    _details(item);
                  },
                ),
              ),
            );
          }
          return LoanApplicationDetailsDialog(
            details: snapshot.requireData,
            dateFormatter: widget.dateFormatter,
            onApprove: (note) => _repository.approveApplication(
              token: widget.token,
              id: item.applicationId,
              adminNote: note,
            ),
            onReject: (note) => _repository.rejectApplication(
              token: widget.token,
              id: item.applicationId,
              adminNote: note,
            ),
          );
        },
      ),
    );
    if (reviewed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan application review saved.')),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppPageHeader(
        icon: LucideIcons.coins,
        title: 'Loans',
        subtitle:
            'Review customer loan applications and prepare lending decisions.',
      ),
      const SizedBox(height: 16),
      AppStatusTabs<_LoanTab>(
        value: _tab,
        tabs: const [
          AppStatusTab(value: _LoanTab.applications, label: 'Applications'),
          AppStatusTab(value: _LoanTab.active, label: 'Active'),
          AppStatusTab(value: _LoanTab.completed, label: 'Completed'),
        ],
        onChanged: _changeTab,
      ),
      const SizedBox(height: 16),
      Expanded(
        child: _tab == _LoanTab.applications ? _applications() : _loans(),
      ),
    ],
  );
  Widget _applications() => Column(
    children: [
      LoanApplicationFilters(
        controller: _search,
        status: _status,
        onSearch: _onSearch,
        onStatus: (value) {
          _status = value;
          _firstPage();
        },
        onRefresh: _refresh,
        onReset: _reset,
        dateRange: _applicationDateRange,
        onDateRange: (value) {
          _applicationDateRange = value;
          _firstPage();
        },
      ),
      const SizedBox(height: 16),
      Expanded(
        child: FutureBuilder<_LoanData>(
          future: _future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AppLoadingState();
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
            final data = snapshot.requireData;
            if (data.page.items.isEmpty) {
              return AppEmptyState(
                icon: LucideIcons.coins,
                title: 'No loan applications found',
                message: 'Try changing the search or status filter.',
                onReset: _reset,
              );
            }
            return Column(
              children: [
                if (snapshot.connectionState != ConnectionState.done)
                  const LinearProgressIndicator(minHeight: 2),
                LoanSummaryCards(summary: data.summary),
                const SizedBox(height: 14),
                Expanded(
                  child: LoanApplicationsTable(
                    page: data.page,
                    pageSize: _pageSize,
                    dateFormatter: widget.dateFormatter,
                    controller: _scroll,
                    onDetails: _details,
                    onPageSelected: (value) {
                      _page = value;
                      _refresh();
                    },
                    onPageSizeChanged: (value) {
                      _pageSize = value;
                      _firstPage();
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
  Widget _loans() => Column(
    children: [
      AdminLoanFilters(
        controller: _search,
        onChanged: (value) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () {
            _page = 1;
            _refreshLoans();
          });
        },
        onRefresh: _refreshLoans,
        onReset: () {
          _search.clear();
          _loanDateFrom = null;
          _loanDateTo = null;
          _overdueOnly = null;
          _page = 1;
          _refreshLoans();
        },
        dateFrom: _loanDateFrom,
        dateTo: _loanDateTo,
        onDateRange: (range) {
          _loanDateFrom = range.start;
          _loanDateTo = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
            23,
            59,
            59,
          );
          _page = 1;
          _refreshLoans();
        },
        onClearDates: () {
          _loanDateFrom = null;
          _loanDateTo = null;
          _page = 1;
          _refreshLoans();
        },
        showOverdue: _tab == _LoanTab.active,
        overdueOnly: _overdueOnly,
        onOverdueChanged: (value) {
          _overdueOnly = value;
          _page = 1;
          _refreshLoans();
        },
      ),
      const SizedBox(height: 16),
      Expanded(
        child: FutureBuilder<_AdminLoansData>(
          future: _loansFuture,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const AppLoadingState();
            }
            if (snapshot.hasError) {
              return AppErrorState(
                message: AppErrorMessage.from(
                  snapshot.error!,
                  fallback: 'Unable to load loans.',
                ),
                onRetry: _refreshLoans,
              );
            }
            final data = snapshot.requireData;
            if (data.page.items.isEmpty) {
              return AppEmptyState(
                icon: _tab == _LoanTab.active
                    ? LucideIcons.coins
                    : LucideIcons.checkCircle,
                title: _tab == _LoanTab.active
                    ? 'No active loans found'
                    : 'No completed loans found',
                message: _search.text.isEmpty
                    ? 'There are no loans in this lifecycle state.'
                    : 'Try changing the search filter.',
                onReset: _search.text.isEmpty
                    ? null
                    : () {
                        _search.clear();
                        _refreshLoans();
                      },
              );
            }
            return Column(
              children: [
                AdminLoansOverviewCards(value: data.overview),
                const SizedBox(height: 14),
                Expanded(
                  child: AdminLoansList(
                    page: data.page,
                    pageSize: _pageSize,
                    active: _tab == _LoanTab.active,
                    dateFormatter: widget.dateFormatter,
                    onView: _loanDetails,
                    onPage: (value) {
                      _page = value;
                      _refreshLoans();
                    },
                    onPageSize: (value) {
                      _pageSize = value;
                      _page = 1;
                      _refreshLoans();
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

class _AdminLoansData {
  const _AdminLoansData(this.page, this.overview);
  final AdminLoanPage page;
  final AdminLoansOverview overview;
}
