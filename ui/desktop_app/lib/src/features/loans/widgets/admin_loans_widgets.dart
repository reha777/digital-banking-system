import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_summary_card.dart';
import '../../../widgets/app_date_range_picker.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_table_row_hover.dart';
import '../models/admin_loan_models.dart';

class AdminLoansOverviewCards extends StatelessWidget {
  const AdminLoansOverviewCards({super.key, required this.value});
  final AdminLoansOverview value;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _card(
        'Pending Applications',
        '${value.pendingApplications}',
        LucideIcons.clock3,
      ),
      _card('Active Loans', '${value.activeLoans}', LucideIcons.coins),
      _card(
        'Loans overdue',
        '${value.loansWithOverduePayments}',
        LucideIcons.alertTriangle,
      ),
      _card(
        'Completed Loans',
        '${value.completedLoans}',
        LucideIcons.checkCircle,
      ),
      for (final c in value.currencies)
        _card(
          'Outstanding ${c.currency}',
          c.outstanding.toStringAsFixed(2),
          LucideIcons.walletCards,
        ),
    ],
  );
  Widget _card(String title, String value, IconData icon) => SizedBox(
    width: 220,
    child: AppSummaryCard(
      title: title,
      value: value,
      icon: icon,
      tone: AppTheme.primary,
    ),
  );
}

class AdminLoanFilters extends StatelessWidget {
  const AdminLoanFilters({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onRefresh,
    required this.onReset,
    required this.dateFrom,
    required this.dateTo,
    required this.onDateRange,
    required this.onClearDates,
    required this.showOverdue,
    required this.overdueOnly,
    required this.onOverdueChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh, onReset;
  final DateTime? dateFrom, dateTo;
  final ValueChanged<DateTimeRange> onDateRange;
  final VoidCallback onClearDates;
  final bool showOverdue;
  final bool? overdueOnly;
  final ValueChanged<bool?> onOverdueChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 430,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              labelText: 'Search customer, email or product',
            ),
          ),
        ),
        AppDateRangePicker(
          dateFrom: dateFrom,
          dateTo: dateTo,
          onApply: onDateRange,
          onClear: onClearDates,
        ),
        if (showOverdue)
          SizedBox(
            width: 180,
            child: AppDropdownField<bool?>(
              label: 'Repayment',
              value: overdueOnly,
              items: const [
                AppDropdownItem(value: null, label: 'All'),
                AppDropdownItem(value: false, label: 'Up to date'),
                AppDropdownItem(value: true, label: 'Overdue'),
              ],
              onChanged: onOverdueChanged,
            ),
          ),
        IconButton.filledTonal(
          onPressed: onRefresh,
          tooltip: 'Refresh loans',
          icon: const Icon(LucideIcons.refreshCw),
        ),
        IconButton.filledTonal(
          onPressed: onReset,
          tooltip: 'Reset loan filters',
          icon: const Icon(LucideIcons.rotateCcw),
        ),
      ],
    ),
  );
}

class AdminLoansList extends StatelessWidget {
  const AdminLoansList({
    super.key,
    required this.page,
    required this.pageSize,
    required this.active,
    required this.dateFormatter,
    required this.onView,
    required this.onPage,
    required this.onPageSize,
  });
  final AdminLoanPage page;
  final int pageSize;
  final bool active;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<AdminLoanListItem> onView;
  final ValueChanged<int> onPage, onPageSize;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final wide = c.maxWidth >= 1050;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            if (wide) _header(),
            Expanded(
              child: ListView.separated(
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    wide ? _row(page.items[i]) : _card(context, page.items[i]),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: AppPagination(
                currentPage: page.page,
                totalPages: page.totalPages,
                pageSize: pageSize,
                shownCount: page.items.length,
                totalCount: page.totalCount,
                itemLabel: 'loans',
                onPageSelected: onPage,
                onPageSizeChanged: onPageSize,
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _header() => SizedBox(
    height: 48,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const _Cell('Customer', 3, true),
          const _Cell('Product', 3, true),
          const _Cell('Original', 2, true),
          _Cell(active ? 'Outstanding' : 'Total Paid', 2, true),
          const _Cell('Interest', 2, true),
          _Cell(active ? 'Next Payment' : 'Completed', 2, true),
          _Cell(active ? 'Overdue' : 'Term', 2, true),
          const _Cell('Status', 2, true),
          const _Cell('Action', 1, true),
        ],
      ),
    ),
  );
  Widget _row(AdminLoanListItem x) => AppTableRowHover(
    child: SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _Cell('${x.customerName}\n${x.customerEmail}', 3),
            _Cell(x.productName, 3),
            _Cell('${x.originalPrincipal.toStringAsFixed(2)} ${x.currency}', 2),
            _Cell(
              '${(active ? x.outstandingPrincipal : x.totalPaid).toStringAsFixed(2)} ${x.currency}',
              2,
            ),
            _Cell('${x.annualInterestRate.toStringAsFixed(2)}%', 2),
            _Cell(
              active
                  ? (x.nextPaymentDateUtc == null
                        ? '-'
                        : dateFormatter(x.nextPaymentDateUtc!))
                  : (x.completedAtUtc == null
                        ? '-'
                        : dateFormatter(x.completedAtUtc!)),
              2,
            ),
            _Cell(
              active
                  ? (x.hasOverdue
                        ? '${x.overdueInstallmentsCount} overdue'
                        : '0')
                  : '${x.termMonths} mo',
              2,
            ),
            _Cell(
              active
                  ? (x.hasOverdue ? 'Active · Overdue' : 'Active')
                  : 'Completed',
              2,
            ),
            Expanded(
              child: IconButton(
                onPressed: () => onView(x),
                tooltip: 'View Loan',
                icon: const Icon(LucideIcons.eye, size: 18),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _card(BuildContext context, AdminLoanListItem x) => ListTile(
    isThreeLine: true,
    leading: Icon(active ? LucideIcons.coins : LucideIcons.checkCircle),
    title: Text(x.customerName),
    subtitle: Text(
      '${x.productName}\n${active ? 'Outstanding ${x.outstandingPrincipal.toStringAsFixed(2)}${x.hasOverdue ? ' · ${x.overdueInstallmentsCount} overdue' : ''}' : 'Total paid ${x.totalPaid.toStringAsFixed(2)}'} ${x.currency}',
    ),
    trailing: IconButton(
      onPressed: () => onView(x),
      tooltip: 'View Loan',
      icon: const Icon(LucideIcons.eye),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, this.flex, [this.header = false]);
  final String text;
  final int flex;
  final bool header;
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: header ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );
}

class AdminLoanDetailsDialog extends StatelessWidget {
  const AdminLoanDetailsDialog({
    super.key,
    required this.details,
    required this.dateFormatter,
  });
  final AdminLoanDetails details;
  final String Function(DateTime) dateFormatter;
  @override
  Widget build(BuildContext context) {
    final loan = details.loan;
    return Dialog(
      child: SizedBox(
        width: 950,
        height: 760,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    loan.status == AdminLoanLifecycleStatus.active
                        ? LucideIcons.coins
                        : LucideIcons.checkCircle,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Loan Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(context, 'Customer Information', [
                      _line('Name', loan.customerName),
                      _line('Email', loan.customerEmail),
                      _line('Status', details.customerStatus),
                    ]),
                    _section(context, 'Loan Information', [
                      _line('Product', loan.productName),
                      _line(
                        'Status',
                        loan.status == AdminLoanLifecycleStatus.active
                            ? 'Active'
                            : 'Completed',
                      ),
                      _line(
                        'Original principal',
                        '${loan.originalPrincipal.toStringAsFixed(2)} ${loan.currency}',
                      ),
                      _line(
                        'Outstanding',
                        '${loan.outstandingPrincipal.toStringAsFixed(2)} ${loan.currency}',
                      ),
                      _line(
                        'Total paid',
                        '${loan.totalPaid.toStringAsFixed(2)} ${loan.currency}',
                      ),
                      _line(
                        'Total repayment',
                        '${details.totalRepayment.toStringAsFixed(2)} ${loan.currency}',
                      ),
                      _line(
                        'Monthly payment',
                        '${loan.monthlyPayment.toStringAsFixed(2)} ${loan.currency}',
                      ),
                      _line(
                        'Interest',
                        '${loan.annualInterestRate.toStringAsFixed(2)}%',
                      ),
                      _line(
                        'Next payment',
                        loan.nextPaymentDateUtc == null
                            ? 'None'
                            : dateFormatter(loan.nextPaymentDateUtc!),
                      ),
                      if (loan.hasOverdue) ...[
                        _line(
                          'Overdue installments',
                          '${loan.overdueInstallmentsCount}',
                        ),
                        _line(
                          'Overdue amount',
                          '${loan.totalOverdueAmount.toStringAsFixed(2)} ${loan.currency}',
                        ),
                      ],
                    ]),
                    _section(context, 'Destination Account', [
                      _line(
                        'Account',
                        details.destinationAccount.maskedAccountNumber,
                      ),
                      _line('Type', details.destinationAccount.accountType),
                      _line('Currency', details.destinationAccount.currency),
                    ]),
                    Text(
                      'Repayment Progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: loan.termMonths == 0
                          ? 0
                          : loan.paidInstallments / loan.termMonths,
                      minHeight: 9,
                    ),
                    Text(
                      'Paid ${loan.paidInstallments} / ${loan.termMonths} installments',
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Installment Schedule',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: details.installments.length,
                        itemBuilder: (_, index) {
                          final item = details.installments[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              item.paid
                                  ? LucideIcons.checkCircle
                                  : item.isOverdue
                                  ? LucideIcons.alertTriangle
                                  : LucideIcons.clock3,
                              color: item.paid
                                  ? Colors.green
                                  : item.isOverdue
                                  ? Colors.red
                                  : null,
                            ),
                            title: Text(
                              '#${item.number} - ${item.total.toStringAsFixed(2)} ${loan.currency}',
                            ),
                            subtitle: Text(
                              'Due ${dateFormatter(item.due)}${item.isOverdue ? ' - ${item.daysOverdue} days overdue' : ''} - Principal ${item.principal.toStringAsFixed(2)} - Interest ${item.interest.toStringAsFixed(2)}',
                            ),
                            trailing: Text(
                              item.paid
                                  ? 'Paid'
                                  : item.isOverdue
                                  ? 'Overdue'
                                  : 'Upcoming',
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Payment History',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (details.payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No payments yet.'),
                      )
                    else
                      ...details.payments.map(
                        (item) => ListTile(
                          leading: const Icon(LucideIcons.fileText),
                          title: Text(
                            '${item.amount.toStringAsFixed(2)} ${loan.currency} - Installment #${item.number}',
                          ),
                          subtitle: Text(
                            '${dateFormatter(item.paidAt)} - ${item.account}\n${item.reference}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    _section(context, 'Application History', [
                      _line(
                        'Submitted',
                        dateFormatter(details.applicationSubmittedAtUtc),
                      ),
                      _line(
                        'Approved',
                        details.applicationReviewedAtUtc == null
                            ? '-'
                            : dateFormatter(details.applicationReviewedAtUtc!),
                      ),
                      _line(
                        'Snapshot rate',
                        '${details.applicationRateSnapshot.toStringAsFixed(2)}%',
                      ),
                      _line('Admin note', details.adminNote ?? '-'),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> rows) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Divider(),
              ...rows,
            ],
          ),
        ),
      );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
