import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../loan_service.dart';
import '../models/loan_models.dart';

class LoanPaymentPage extends StatefulWidget {
  const LoanPaymentPage({
    super.key,
    required this.token,
    required this.loan,
    required this.accounts,
    required this.repository,
  });
  final String token;
  final LoanModel loan;
  final List<Account> accounts;
  final LoanRepository repository;
  @override
  State<LoanPaymentPage> createState() => _LoanPaymentPageState();
}

class _LoanPaymentPageState extends State<LoanPaymentPage> {
  late Future<LoanPaymentQuoteModel> _quote;
  Account? _selected;
  bool _submitting = false;
  String? _requestId;
  List<Account> get _accounts => widget.accounts
      .where(
        (a) => a.currency.toUpperCase() == widget.loan.currency.toUpperCase(),
      )
      .toList();
  @override
  void initState() {
    super.initState();
    _selected = _accounts.isEmpty ? null : _accounts.first;
    _quote = widget.repository.getPaymentQuote(
      widget.token,
      widget.loan.loanId,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pay Installment')),
    body: FutureBuilder<LoanPaymentQuoteModel>(
      future: _quote,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final quote = snapshot.requireData;
        final insufficient =
            _selected != null && _selected!.balance < quote.amount;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(LucideIcons.receiptText, size: 34),
                    const SizedBox(height: 10),
                    Text(
                      'Installment #${quote.installmentNumber}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('Due ${_date(quote.dueDateUtc)}'),
                    const SizedBox(height: 18),
                    Text(
                      '${formatMoney(quote.amount)} ${quote.currency}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Divider(height: 28),
                    _line(
                      'Principal',
                      '${formatMoney(quote.principalAmount)} ${quote.currency}',
                    ),
                    _line(
                      'Interest',
                      '${formatMoney(quote.interestAmount)} ${quote.currency}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'From Account',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_accounts.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(LucideIcons.circleAlert),
                  title: Text('No matching account'),
                  subtitle: Text('You need an account in the loan currency.'),
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('loan-source-account'),
                initialValue: _selected?.id,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                          '${_mask(a.accountNumber)} · ${formatMoney(a.balance)} ${a.currency}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(
                  () => _selected = _accounts.singleWhere((a) => a.id == id),
                ),
              ),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Available Balance  ${formatMoney(_selected!.balance)} ${_selected!.currency}',
                ),
              ),
            if (insufficient)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Insufficient balance',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 28),
            FilledButton(
              key: const ValueKey('continue-loan-payment'),
              onPressed: _selected == null || insufficient || _submitting
                  ? null
                  : () => _confirm(quote),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    ),
  );
  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
  Future<void> _confirm(LoanPaymentQuoteModel quote) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Confirm Payment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _line('Loan', widget.loan.productName),
            _line('Installment', '#${quote.installmentNumber}'),
            _line('From', _mask(_selected!.accountNumber)),
            _line('Payment', '${formatMoney(quote.amount)} ${quote.currency}'),
            _line(
              'Principal',
              '${formatMoney(quote.principalAmount)} ${quote.currency}',
            ),
            _line(
              'Interest',
              '${formatMoney(quote.interestAmount)} ${quote.currency}',
            ),
            _line(
              'Remaining principal after',
              '${formatMoney(quote.outstandingAfter)} ${quote.currency}',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('confirm-loan-payment'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm Payment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || _submitting) return;
    setState(() => _submitting = true);
    _requestId ??= _uuid();
    try {
      final result = await widget.repository.payInstallment(
        widget.token,
        widget.loan.loanId,
        sourceAccountId: _selected!.id,
        clientRequestId: _requestId!,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(
            result.isCompleted
                ? LucideIcons.circleCheck
                : LucideIcons.handCoins,
          ),
          title: Text(
            result.isCompleted
                ? 'Loan repaid successfully'
                : 'Payment successful',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${formatMoney(result.amount)} ${result.currency}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Installment #${result.installmentNumber} paid'),
              const SizedBox(height: 12),
              Text(
                'Outstanding principal ${formatMoney(result.outstandingPrincipal)} ${result.currency}',
              ),
              Text(
                result.nextPaymentDateUtc == null
                    ? 'Loan Status: Completed'
                    : 'Next payment ${_date(result.nextPaymentDateUtc!)}',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
String _mask(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final end = digits.length > 4
      ? digits.substring(digits.length - 4)
      : digits.padLeft(4, '0');
  return '**** $end';
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
