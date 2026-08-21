import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../loan_service.dart';
import '../models/loan_models.dart';
import '../widgets/loan_widgets.dart';

class LoanApplicationPage extends StatefulWidget {
  const LoanApplicationPage({
    super.key,
    required this.token,
    required this.product,
    required this.accounts,
    required this.repository,
  });
  final String token;
  final LoanProductModel product;
  final List<Account> accounts;
  final LoanRepository repository;
  @override
  State<LoanApplicationPage> createState() => _LoanApplicationPageState();
}

class _LoanApplicationPageState extends State<LoanApplicationPage> {
  final _amount = TextEditingController();
  Timer? _debounce;
  LoanQuoteModel? _quote;
  LoanApplicationModel? _submitted;
  Account? _account;
  late int _term;
  int _quoteVersion = 0;
  bool _quoteLoading = false, _submitting = false;
  String? _quoteError, _submitError, _clientRequestId;
  List<Account> get _accounts => widget.accounts
      .where(
        (a) =>
            a.currency.toUpperCase() == widget.product.currency.toUpperCase(),
      )
      .toList();
  double? get _principal =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));
  bool get _amountValid {
    final value = _principal;
    return value != null &&
        value >= widget.product.minPrincipal &&
        value <= widget.product.maxPrincipal &&
        RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(_amount.text.trim());
  }

  bool get _canContinue =>
      _amountValid &&
      _account != null &&
      _quote != null &&
      !_quoteLoading &&
      !_submitting;
  @override
  void initState() {
    super.initState();
    _term = widget.product.minTermMonths;
    if (_accounts.isNotEmpty) _account = _accounts.first;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    final version = ++_quoteVersion;
    setState(() {
      _quote = null;
      _quoteError = null;
      _clientRequestId = null;
    });
    if (!_amountValid) return;
    setState(() => _quoteLoading = true);
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadQuote(version),
    );
  }

  Future<void> _loadQuote(int version) async {
    try {
      final quote = await widget.repository.getQuote(
        widget.token,
        productId: widget.product.id,
        principal: _principal!,
        termMonths: _term,
      );
      if (!mounted || version != _quoteVersion) return;
      setState(() {
        _quote = quote;
        _quoteLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _quoteVersion) return;
      setState(() {
        _quoteError = error.toString();
        _quoteLoading = false;
      });
    }
  }

  Future<void> _review() async {
    final quote = _quote;
    if (!_canContinue || quote == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            4,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review application',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your application will be sent for review. This quote is not an approval.',
              ),
              const SizedBox(height: 16),
              _reviewLine('Loan product', widget.product.name),
              _reviewLine(
                'Loan amount',
                '${formatMoney(quote.principal)} ${quote.currency}',
              ),
              _reviewLine('Destination', _masked(_account!.accountNumber)),
              _reviewLine('Term', '${quote.termMonths} months'),
              _reviewLine(
                'Interest rate',
                '${quote.annualInterestRate.toStringAsFixed(2)}%',
              ),
              _reviewLine(
                'Monthly payment',
                '${formatMoney(quote.monthlyPayment)} ${quote.currency}',
              ),
              _reviewLine(
                'Total interest',
                '${formatMoney(quote.totalInterest)} ${quote.currency}',
              ),
              _reviewLine(
                'Total repayment',
                '${formatMoney(quote.totalRepayment)} ${quote.currency}',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          Navigator.pop(sheetContext);
                          _submit();
                        },
                  child: const Text('Submit Application'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  Future<void> _submit() async {
    if (_submitting || !_canContinue) return;
    _clientRequestId ??= _uuid();
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await widget.repository.submitApplication(
        widget.token,
        productId: widget.product.id,
        destinationAccountId: _account!.id,
        principal: _principal!,
        termMonths: _term,
        clientRequestId: _clientRequestId!,
      );
      if (mounted) {
        setState(() {
          _submitted = result;
          _submitting = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitError = error.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted != null) return _success();
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Loan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.landmark),
              title: Text(widget.product.name),
              subtitle: Text(
                '${widget.product.annualInterestRate.toStringAsFixed(2)}% APR • ${widget.product.currency}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Loan Amount', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => _changed(),
            decoration: InputDecoration(
              prefixText: '${widget.product.currency}  ',
              hintText: formatMoney(widget.product.minPrincipal),
              helperText:
                  '${formatMoney(widget.product.minPrincipal)} – ${formatMoney(widget.product.maxPrincipal)} ${widget.product.currency}',
              errorText: _amount.text.isNotEmpty && !_amountValid
                  ? 'Enter an amount within the product limits (max 2 decimals).'
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Repayment Term',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in widget.product.termOptions)
                ChoiceChip(
                  label: Text('$term months'),
                  selected: _term == term,
                  onSelected: (_) {
                    _term = term;
                    _changed();
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Destination Account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_accounts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(LucideIcons.circleAlert),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You need an ${widget.product.currency} account to receive this loan.',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final account in _accounts)
              LoanAccountTile(
                account: account,
                selected: _account?.id == account.id,
                onTap: () => setState(() => _account = account),
              ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _quoteLoading
                ? const Center(
                    key: ValueKey('loading'),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _quote != null
                ? LoanQuoteCard(key: const ValueKey('quote'), quote: _quote!)
                : _quoteError != null
                ? Card(
                    key: const ValueKey('error'),
                    child: ListTile(
                      title: Text(_quoteError!),
                      trailing: IconButton(
                        icon: const Icon(LucideIcons.refreshCw),
                        onPressed: () => _changed(),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _submitError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canContinue ? _review : null,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _success() => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Application submitted'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.circleCheck, color: Colors.green, size: 70),
          const SizedBox(height: 20),
          Text(
            'Your loan application is under review.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          LoanStatusCard(application: _submitted!),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    ),
  );
}

String _masked(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  final end = digits.length > 4
      ? digits.substring(digits.length - 4)
      : digits.padLeft(4, '0');
  return '•••• $end';
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
