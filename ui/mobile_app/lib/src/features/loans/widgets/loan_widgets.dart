import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../models/loan_models.dart';

class LoanProductCard extends StatelessWidget {
  const LoanProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });
  final LoanProductModel product;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(LucideIcons.landmark)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product.annualInterestRate.toStringAsFixed(2)}% APR · ${formatMoney(product.minPrincipal)} - ${formatMoney(product.maxPrincipal)} ${product.currency}',
                  ),
                  Text(
                    '${product.minTermMonths}-${product.maxTermMonths} months',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight),
          ],
        ),
      ),
    ),
  );
}

class LoanQuoteCard extends StatelessWidget {
  const LoanQuoteCard({super.key, required this.quote});
  final LoanQuoteModel quote;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _row(
            'Monthly payment',
            '${formatMoney(quote.monthlyPayment)} ${quote.currency}',
          ),
          _row(
            'Interest rate',
            '${quote.annualInterestRate.toStringAsFixed(2)}%',
          ),
          _row(
            'Total interest',
            '${formatMoney(quote.totalInterest)} ${quote.currency}',
          ),
          _row(
            'Total repayment',
            '${formatMoney(quote.totalRepayment)} ${quote.currency}',
          ),
          _row('Term', '${quote.termMonths} months'),
        ],
      ),
    ),
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class LoanAccountTile extends StatelessWidget {
  const LoanAccountTile({
    super.key,
    required this.account,
    required this.selected,
    required this.onTap,
  });
  final Account account;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final digits = account.accountNumber.replaceAll(RegExp(r'\D'), '');
    final ending = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits.padLeft(4, '0');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .14)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(LucideIcons.walletCards),
        title: Text('Account **** $ending'),
        subtitle: Text(account.currency),
        trailing: selected ? const Icon(LucideIcons.circleCheck) : null,
      ),
    );
  }
}

class LoanStatusCard extends StatelessWidget {
  const LoanStatusCard({super.key, required this.application});
  final LoanApplicationModel application;
  @override
  Widget build(BuildContext context) {
    final status = application.isPending
        ? 'Pending'
        : application.isRejected
        ? 'Rejected'
        : 'Approved';
    final icon = application.isPending
        ? LucideIcons.clock3
        : application.isRejected
        ? LucideIcons.circleAlert
        : LucideIcons.circleCheck;
    final color = application.isPending
        ? Colors.orange
        : application.isRejected
        ? Colors.red
        : Colors.green;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Card(
        key: ValueKey(status),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                application.isPending
                    ? 'Your application is being reviewed.'
                    : application.isRejected
                    ? 'Your application was not approved.'
                    : 'Your application has been approved.',
              ),
              const Divider(height: 28),
              _line('Product', application.productName),
              _line(
                'Requested amount',
                '${formatMoney(application.principal)} ${application.currency}',
              ),
              _line('Destination', application.destinationAccountNumber),
              _line('Term', '${application.termMonths} months'),
              _line(
                'Interest',
                '${application.annualInterestRate.toStringAsFixed(2)}%',
              ),
              _line(
                'Monthly payment',
                '${formatMoney(application.estimatedMonthlyPayment)} ${application.currency}',
              ),
              if (application.isRejected &&
                  (application.adminNote?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Text('Reason', style: Theme.of(context).textTheme.labelLarge),
                Text(application.adminNote!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
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
}

class ActiveLoanCard extends StatelessWidget {
  const ActiveLoanCard({
    super.key,
    required this.loan,
    required this.onDetails,
    required this.onPay,
  });
  final LoanModel loan;
  final VoidCallback onDetails, onPay;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    child: Card(
      key: ValueKey(loan.loanId),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  loan.isCompleted
                      ? LucideIcons.circleCheck
                      : LucideIcons.handCoins,
                ),
                const SizedBox(width: 10),
                Text(
                  loan.isCompleted ? 'Completed Loan' : 'Active Loan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Outstanding Balance'),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                '${formatMoney(loan.outstandingPrincipal)} ${loan.currency}',
                key: ValueKey(loan.outstandingPrincipal),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 30),
            _summaryLine(
              'Monthly Payment',
              '${formatMoney(loan.monthlyPayment)} ${loan.currency}',
            ),
            _summaryLine(
              'Interest Rate',
              '${loan.annualInterestRate.toStringAsFixed(2)}%',
            ),
            _summaryLine(
              'Next Payment',
              loan.nextPaymentDateUtc == null
                  ? 'Repaid'
                  : _shortDate(loan.nextPaymentDateUtc!),
            ),
            _summaryLine(
              'Remaining',
              '${loan.remainingInstallments} installments',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetails,
                    child: const Text('View Details'),
                  ),
                ),
                if (!loan.isCompleted) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPay,
                      child: const Text('Pay Installment'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget _summaryLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
