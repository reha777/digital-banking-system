import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/app_pagination.dart';
import '../../../widgets/app_status_badge.dart';
import '../../../widgets/app_summary_card.dart';
import '../models/admin_loan_models.dart';

class LoanApplicationFilters extends StatelessWidget {
  const LoanApplicationFilters({
    super.key,
    required this.controller,
    required this.status,
    required this.onSearch,
    required this.onStatus,
    required this.onRefresh,
    required this.onReset,
  });
  final TextEditingController controller;
  final int? status;
  final ValueChanged<String> onSearch;
  final ValueChanged<int?> onStatus;
  final VoidCallback onRefresh, onReset;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF303244)
            : AppTheme.border,
      ),
    ),
    child: LayoutBuilder(
      builder: (_, constraints) => Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth < 430 ? constraints.maxWidth : 430,
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.search),
                labelText: 'Search customer, email or product',
              ),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 210 ? constraints.maxWidth : 210,
            child: DropdownButtonFormField<int?>(
              key: ValueKey(status),
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All statuses')),
                DropdownMenuItem(value: 1, child: Text('Pending')),
                DropdownMenuItem(value: 2, child: Text('Approved')),
                DropdownMenuItem(value: 3, child: Text('Rejected')),
              ],
              onChanged: onStatus,
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
}

class LoanSummaryCards extends StatelessWidget {
  const LoanSummaryCards({super.key, required this.summary});
  final AdminLoanSummary summary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final width = constraints.maxWidth >= 900
          ? (constraints.maxWidth - 36) / 4
          : (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: AppSummaryCard(
              title: 'Total Applications',
              value: '${summary.totalApplications}',
              icon: LucideIcons.coins,
              tone: AppTheme.primary,
            ),
          ),
          SizedBox(
            width: width,
            child: AppSummaryCard(
              title: 'Pending',
              value: '${summary.pendingApplications}',
              icon: LucideIcons.clock3,
              tone: const Color(0xFFF59E0B),
            ),
          ),
          SizedBox(
            width: width,
            child: AppSummaryCard(
              title: 'Approved',
              value: '${summary.approvedApplications}',
              icon: LucideIcons.checkCircle,
              tone: const Color(0xFF16A34A),
            ),
          ),
          SizedBox(
            width: width,
            child: AppSummaryCard(
              title: 'Rejected',
              value: '${summary.rejectedApplications}',
              icon: LucideIcons.xCircle,
              tone: const Color(0xFFDC2626),
            ),
          ),
        ],
      );
    },
  );
}

class LoanApplicationsTable extends StatelessWidget {
  const LoanApplicationsTable({
    super.key,
    required this.page,
    required this.pageSize,
    required this.dateFormatter,
    required this.controller,
    required this.onDetails,
    required this.onPageSelected,
    required this.onPageSizeChanged,
  });
  final AdminLoanApplicationPage page;
  final int pageSize;
  final String Function(DateTime) dateFormatter;
  final ScrollController controller;
  final ValueChanged<AdminLoanApplicationListItem> onDetails;
  final ValueChanged<int> onPageSelected, onPageSizeChanged;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final desktop = constraints.maxWidth >= 980;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF303244)
                : AppTheme.border,
          ),
        ),
        child: Column(
          children: [
            if (desktop) const _LoanHeader(),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) => desktop
                    ? _LoanRow(
                        item: page.items[index],
                        dateFormatter: dateFormatter,
                        onDetails: onDetails,
                      )
                    : _LoanCompact(
                        item: page.items[index],
                        onDetails: onDetails,
                      ),
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
                itemLabel: 'applications',
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

class _LoanHeader extends StatelessWidget {
  const _LoanHeader();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 48,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Cell('Customer', 4, header: true),
          _Cell('Product', 3, header: true),
          _Cell('Amount', 2, header: true),
          _Cell('Term', 2, header: true),
          _Cell('Interest', 2, header: true),
          _Cell('Monthly Payment', 3, header: true),
          _Cell('Status', 2, header: true),
          _Cell('Submitted', 2, header: true),
          _Cell('Actions', 2, header: true),
        ],
      ),
    ),
  );
}

class _LoanRow extends StatelessWidget {
  const _LoanRow({
    required this.item,
    required this.dateFormatter,
    required this.onDetails,
  });
  final AdminLoanApplicationListItem item;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<AdminLoanApplicationListItem> onDetails;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 76,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.customerEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _Cell(item.productName, 3),
          _Cell('${item.principal.toStringAsFixed(2)} ${item.currency}', 2),
          _Cell('${item.termMonths} months', 2),
          _Cell('${item.annualInterestRate.toStringAsFixed(2)}%', 2),
          _Cell(
            '${item.estimatedMonthlyPayment.toStringAsFixed(2)} ${item.currency}',
            3,
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(status: adminLoanStatusLabel(item.status)),
            ),
          ),
          _Cell(dateFormatter(item.submittedAtUtc), 2),
          Expanded(
            flex: 2,
            child: IconButton(
              onPressed: () => onDetails(item),
              tooltip: 'View / Review',
              icon: const Icon(LucideIcons.eye),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LoanCompact extends StatelessWidget {
  const _LoanCompact({required this.item, required this.onDetails});
  final AdminLoanApplicationListItem item;
  final ValueChanged<AdminLoanApplicationListItem> onDetails;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const CircleAvatar(child: Icon(LucideIcons.coins, size: 18)),
    title: Text(item.customerName),
    subtitle: Text(
      '${item.productName}\n${item.principal.toStringAsFixed(2)} ${item.currency} · ${adminLoanStatusLabel(item.status)}',
    ),
    isThreeLine: true,
    trailing: IconButton(
      onPressed: () => onDetails(item),
      tooltip: 'View / Review',
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
        fontSize: header ? 12 : 13,
        fontWeight: header ? FontWeight.w800 : FontWeight.w400,
        color: header ? Theme.of(context).colorScheme.primary : null,
      ),
    ),
  );
}

class LoanApplicationDetailsDialog extends StatelessWidget {
  const LoanApplicationDetailsDialog({
    super.key,
    required this.details,
    required this.dateFormatter,
    this.onApprove,
    this.onReject,
  });
  final AdminLoanApplicationDetails details;
  final String Function(DateTime) dateFormatter;
  final Future<AdminLoanApplicationDetails> Function(String? note)? onApprove;
  final Future<AdminLoanApplicationDetails> Function(String note)? onReject;
  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.coins),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loan Application Details',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AppStatusBadge(status: adminLoanStatusLabel(details.status)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section(
                      context,
                      'Customer Information',
                      LucideIcons.user,
                      [
                        _line('Name', details.customer.fullName),
                        _line('Email', details.customer.email),
                        _line('Customer status', details.customer.status),
                      ],
                    ),
                    _section(context, 'Loan Product', LucideIcons.coins, [
                      _line('Product', details.product.name),
                      _line('Currency', details.product.currency),
                    ]),
                    _section(
                      context,
                      'Destination Account',
                      LucideIcons.walletCards,
                      [
                        _line(
                          'Account',
                          details.destinationAccount.maskedAccountNumber,
                        ),
                        _line('Type', details.destinationAccount.accountType),
                        _line('Currency', details.destinationAccount.currency),
                        _line(
                          'Current balance',
                          '${details.destinationAccount.currentBalance.toStringAsFixed(2)} ${details.destinationAccount.currency}',
                        ),
                      ],
                    ),
                    _section(context, 'Loan Calculation', LucideIcons.percent, [
                      _line(
                        'Principal',
                        '${details.financials.principal.toStringAsFixed(2)} ${details.product.currency}',
                      ),
                      _line(
                        'Interest rate',
                        '${details.financials.annualInterestRate.toStringAsFixed(2)}%',
                      ),
                      _line('Term', '${details.financials.termMonths} months'),
                      _line(
                        'Monthly payment',
                        '${details.financials.estimatedMonthlyPayment.toStringAsFixed(2)} ${details.product.currency}',
                      ),
                      _line(
                        'Total interest',
                        '${details.financials.estimatedTotalInterest.toStringAsFixed(2)} ${details.product.currency}',
                      ),
                      _line(
                        'Total repayment',
                        '${details.financials.estimatedTotalRepayment.toStringAsFixed(2)} ${details.product.currency}',
                      ),
                    ]),
                    _section(
                      context,
                      'Application Status',
                      LucideIcons.clock3,
                      [
                        _line(
                          'Submitted',
                          dateFormatter(details.submittedAtUtc),
                        ),
                        if (details.reviewedAtUtc != null)
                          _line(
                            'Reviewed',
                            dateFormatter(details.reviewedAtUtc!),
                          ),
                        if (details.adminNote?.isNotEmpty == true)
                          _line('Admin note', details.adminNote!),
                      ],
                    ),
                    if (details.status == AdminLoanStatus.pending)
                      _review(context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const Divider(height: 22),
          ...children,
        ],
      ),
    ),
  );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
  Widget _review(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Choose an action to review this pending application.'),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onReject == null ? null : () => _openReject(context),
                icon: const Icon(LucideIcons.xCircle),
                label: const Text('Reject'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onApprove == null
                    ? null
                    : () => _openApprove(context),
                icon: const Icon(LucideIcons.checkCircle),
                label: const Text('Approve'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Approval will create the loan, credit the destination account and generate the repayment schedule.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Future<void> _openApprove(BuildContext context) async {
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ApproveLoanDialog(details: details, onSubmit: onApprove!),
    );
    if (reviewed == true && context.mounted) Navigator.pop(context, true);
  }

  Future<void> _openReject(BuildContext context) async {
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (_) => _RejectLoanDialog(onSubmit: onReject!),
    );
    if (reviewed == true && context.mounted) Navigator.pop(context, true);
  }
}

class _ApproveLoanDialog extends StatefulWidget {
  const _ApproveLoanDialog({required this.details, required this.onSubmit});
  final AdminLoanApplicationDetails details;
  final Future<AdminLoanApplicationDetails> Function(String? note) onSubmit;
  @override
  State<_ApproveLoanDialog> createState() => _ApproveLoanDialogState();
}

class _ApproveLoanDialogState extends State<_ApproveLoanDialog> {
  final _note = TextEditingController();
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return AlertDialog(
      title: const Text('Approve Loan Application?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmationLine('Customer', details.customer.fullName),
              _confirmationLine(
                'Principal',
                '${details.financials.principal.toStringAsFixed(2)} ${details.product.currency}',
              ),
              _confirmationLine(
                'Destination account',
                details.destinationAccount.maskedAccountNumber,
              ),
              _confirmationLine(
                'Monthly payment',
                '${details.financials.estimatedMonthlyPayment.toStringAsFixed(2)} ${details.product.currency}',
              ),
              _confirmationLine(
                'Term',
                '${details.financials.termMonths} months',
              ),
              _confirmationLine(
                'Interest',
                '${details.financials.annualInterestRate.toStringAsFixed(2)}%',
              ),
              const Divider(height: 24),
              const Text(
                "Approving this application will create the loan and credit the customer's destination account.",
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                enabled: !_loading,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Admin Note (optional)',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Approve Loan'),
        ),
      ],
    );
  }
}

class _RejectLoanDialog extends StatefulWidget {
  const _RejectLoanDialog({required this.onSubmit});
  final Future<AdminLoanApplicationDetails> Function(String note) onSubmit;
  @override
  State<_RejectLoanDialog> createState() => _RejectLoanDialogState();
}

class _RejectLoanDialogState extends State<_RejectLoanDialog> {
  final _reason = TextEditingController();
  bool _loading = false;
  String? _error;
  bool get _valid => _reason.text.trim().isNotEmpty;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_valid) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_reason.text.trim());
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reject Loan Application?'),
    content: SizedBox(
      width: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A reason is required and will be visible to the customer.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            enabled: !_loading,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Admin Note / Reason'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
        onPressed: _loading || !_valid ? null : _submit,
        child: _loading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Reject Application'),
      ),
    ],
  );
}

Widget _confirmationLine(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    children: [
      Expanded(child: Text(label)),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  ),
);
