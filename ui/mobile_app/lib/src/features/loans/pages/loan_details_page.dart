import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../loan_service.dart';
import '../models/loan_models.dart';
import 'loan_payment_page.dart';

class LoanDetailsPage extends StatefulWidget {
  const LoanDetailsPage({
    super.key,
    required this.token,
    required this.loanId,
    required this.accounts,
    required this.repository,
  });
  final String token, loanId;
  final List<Account> accounts;
  final LoanRepository repository;
  @override
  State<LoanDetailsPage> createState() => _LoanDetailsPageState();
}

class _LoanDetailsPageState extends State<LoanDetailsPage> {
  late Future<LoanDetailsModel> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<LoanDetailsModel> _load() =>
      widget.repository.getLoanDetails(widget.token, widget.loanId);
  Future<void> _pay(LoanModel loan) async {
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoanPaymentPage(
          token: widget.token,
          loan: loan,
          accounts: widget.accounts,
          repository: widget.repository,
        ),
      ),
    );
    if (paid == true && mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Loan Details')),
    body: FutureBuilder<LoanDetailsModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final data = snapshot.requireData;
        final loan = data.loan;
        final progress = loan.termMonths == 0
            ? 0.0
            : loan.paidInstallments / loan.termMonths;
        final upcoming = data.installments
            .where((e) => !e.isPaid)
            .take(5)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.productName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      loan.isCompleted ? 'Completed' : 'Active',
                      style: TextStyle(
                        color: loan.isCompleted
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Divider(height: 24),
                    _row(
                      'Original amount',
                      '${formatMoney(loan.originalPrincipal)} ${loan.currency}',
                    ),
                    _row(
                      'Outstanding principal',
                      '${formatMoney(loan.outstandingPrincipal)} ${loan.currency}',
                    ),
                    _row(
                      'Total paid',
                      '${formatMoney(loan.totalPaid)} ${loan.currency}',
                    ),
                    _row(
                      'Interest rate',
                      '${loan.annualInterestRate.toStringAsFixed(2)}%',
                    ),
                    _row(
                      'Monthly payment',
                      '${formatMoney(loan.monthlyPayment)} ${loan.currency}',
                    ),
                    _row('Term', '${loan.termMonths} months'),
                    _row('Start date', _date(loan.startDateUtc)),
                    _row(
                      'Next payment',
                      loan.nextPaymentDateUtc == null
                          ? 'Repaid'
                          : _date(loan.nextPaymentDateUtc!),
                    ),
                    _row('Maturity', _date(loan.maturityDateUtc)),
                    if (loan.hasOverdue) ...[
                      const Divider(height: 24),
                      _row(
                        'Overdue installments',
                        '${loan.overdueInstallmentsCount}',
                      ),
                      _row(
                        'Overdue amount',
                        '${formatMoney(loan.totalOverdueAmount)} ${loan.currency}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Repayment Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 550),
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 6),
            Text('Paid ${loan.paidInstallments} / ${loan.termMonths}'),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Upcoming Schedule',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => _fullSchedule(data.installments),
                  child: const Text('View Full Schedule'),
                ),
              ],
            ),
            if (upcoming.isEmpty)
              const Text('All installments are paid.')
            else
              ...upcoming.map(_installment),
            const SizedBox(height: 22),
            Text(
              'Payment History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.payments.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(LucideIcons.receiptText),
                  title: Text('No payments yet.'),
                ),
              )
            else
              ...data.payments.map(
                (p) => Card(
                  child: ListTile(
                    leading: const Icon(LucideIcons.circleCheck),
                    title: Text('${formatMoney(p.amount)} ${loan.currency}'),
                    subtitle: Text(
                      '${_date(p.paidAtUtc)} · Principal ${formatMoney(p.principalAmount)} · Interest ${formatMoney(p.interestAmount)}\n${p.transactionReference}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            if (!loan.isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: FilledButton.icon(
                  onPressed: () => _pay(loan),
                  icon: const Icon(LucideIcons.handCoins),
                  label: const Text('Pay Installment'),
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
  Widget _installment(LoanInstallmentModel item) => Card(
    color: item.isOverdue ? Colors.red.withValues(alpha: .08) : null,
    child: ListTile(
      leading: Icon(
        item.isPaid
            ? LucideIcons.circleCheck
            : item.isOverdue
            ? LucideIcons.triangleAlert
            : LucideIcons.calendarDays,
        color: item.isPaid
            ? Colors.green
            : item.isOverdue
            ? Colors.red
            : null,
      ),
      title: Text('Installment #${item.installmentNumber}'),
      subtitle: Text(
        item.isOverdue
            ? 'Due ${_date(item.dueDateUtc)}\nOverdue by ${item.daysOverdue} day${item.daysOverdue == 1 ? '' : 's'}'
            : 'Due ${_date(item.dueDateUtc)}',
      ),
      isThreeLine: item.isOverdue,
      trailing: Text(formatMoney(item.scheduledAmount)),
    ),
  );
  void _fullSchedule(
    List<LoanInstallmentModel> items,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Full Repayment Schedule',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...items.map(
            (i) => Card(
              child: ListTile(
                leading: Icon(
                  i.isPaid
                      ? LucideIcons.circleCheck
                      : i.isOverdue
                      ? LucideIcons.triangleAlert
                      : LucideIcons.clock3,
                  color: i.isPaid
                      ? Colors.green
                      : i.isOverdue
                      ? Colors.red
                      : null,
                ),
                title: Text(
                  '#${i.installmentNumber} · ${formatMoney(i.scheduledAmount)}',
                ),
                subtitle: Text(
                  'Due ${_date(i.dueDateUtc)}${i.isOverdue ? '\nOverdue by ${i.daysOverdue} day${i.daysOverdue == 1 ? '' : 's'}' : ''}\nPrincipal ${formatMoney(i.principalAmount)} · Interest ${formatMoney(i.interestAmount)}',
                ),
                trailing: Text(
                  i.isPaid
                      ? 'Paid'
                      : i.isOverdue
                      ? 'Overdue'
                      : 'Upcoming',
                ),
                isThreeLine: true,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
