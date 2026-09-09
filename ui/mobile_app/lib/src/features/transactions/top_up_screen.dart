import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api_client.dart';
import '../accounts/account_models.dart';
import '../accounts/account_service.dart';
import '../auth/auth_session.dart';
import 'transaction_service.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({
    super.key,
    required this.session,
    this.accountService,
    this.transactionService,
  });

  final AuthSession session;
  final AccountService? accountService;
  final TransactionService? transactionService;

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _source = TextEditingController();
  late final AccountService _accounts;
  late final TransactionService _transactions;
  late Future<List<Account>> _accountsFuture;
  Account? _selected;
  String _sourceType = 'ExternalBankCard';
  bool _submitting = false;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    final api = ApiClient();
    _accounts = widget.accountService ?? AccountService(api);
    _transactions = widget.transactionService ?? TransactionService(api);
    _accountsFuture = _loadAccounts();
  }

  Future<List<Account>> _loadAccounts() async {
    final token = widget.session.token;
    if (token == null) throw StateError('Your session has expired.');
    final accounts = (await _accounts.getBalanceSummary(token)).accounts;
    if (accounts.isNotEmpty) _selected ??= accounts.first;
    return accounts;
  }

  @override
  void dispose() {
    _amount.dispose();
    _source.dispose();
    super.dispose();
  }

  String get _sourceLabel => switch (_sourceType) {
    'ExternalBankCard' => 'Last 4 digits',
    'CashDeposit' => 'Deposit location or reference',
    _ => 'Bank transfer reference',
  };

  Future<void> _submit() async {
    if (_submitting ||
        !_formKey.currentState!.validate() ||
        _selected == null) {
      return;
    }
    final token = widget.session.token;
    if (token == null) return;
    setState(() => _submitting = true);
    _requestId ??= _uuid();
    try {
      final result = await _transactions.topUp(
        token: token,
        accountId: _selected!.id,
        amount: double.parse(_amount.text.trim().replaceAll(',', '.')),
        currency: _selected!.currency,
        sourceType: _sourceType,
        sourceDescription: _source.text.trim(),
        clientRequestId: _requestId!,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: const Text('Top up completed'),
          content: Text(
            '${result.amount.toStringAsFixed(2)} ${result.currency} was added to your account.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      _requestId = null;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Top Up')),
    body: FutureBuilder<List<Account>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _accountsFuture = _loadAccounts()),
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Try again'),
            ),
          );
        }
        final accounts = snapshot.data ?? const <Account>[];
        if (accounts.isEmpty) {
          return const Center(child: Text('No active accounts available.'));
        }
        return SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Simulated external deposit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose an account and a safe source descriptor. Never enter a full card number or CVV.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<Account>(
                  initialValue: _selected,
                  decoration: const InputDecoration(
                    labelText: 'Destination account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts
                      .map(
                        (account) => DropdownMenuItem(
                          value: account,
                          child: Text(
                            '${_masked(account.accountNumber)} • ${account.currency} ${account.balance.toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _selected = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,5}([.,]\d{0,2})?'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    suffixText: _selected?.currency,
                  ),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount.';
                    }
                    if (amount > 10000) return 'Maximum Top Up is 10,000.00.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _sourceType,
                  decoration: const InputDecoration(
                    labelText: 'Source type',
                    prefixIcon: Icon(LucideIcons.landmark),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ExternalBankCard',
                      child: Text('External bank card'),
                    ),
                    DropdownMenuItem(
                      value: 'CashDeposit',
                      child: Text('Cash deposit'),
                    ),
                    DropdownMenuItem(
                      value: 'BankTransfer',
                      child: Text('Bank transfer'),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() {
                            _sourceType = value ?? 'ExternalBankCard';
                            _source.clear();
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _source,
                  maxLength: _sourceType == 'ExternalBankCard' ? 4 : 100,
                  keyboardType: _sourceType == 'ExternalBankCard'
                      ? TextInputType.number
                      : TextInputType.text,
                  inputFormatters: _sourceType == 'ExternalBankCard'
                      ? [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ]
                      : [LengthLimitingTextInputFormatter(100)],
                  decoration: InputDecoration(
                    labelText: _sourceLabel,
                    prefixIcon: Icon(
                      _sourceType == 'ExternalBankCard'
                          ? LucideIcons.creditCard
                          : Icons.receipt_long_outlined,
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (_sourceType == 'ExternalBankCard' &&
                        !RegExp(r'^\d{4}$').hasMatch(text)) {
                      return 'Enter exactly the last 4 digits.';
                    }
                    if (_sourceType != 'ExternalBankCard' && text.length < 2) {
                      return 'Enter a source reference.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_submitting ? 'Processing…' : 'Confirm Top Up'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _masked(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final last = digits.length <= 4
      ? digits
      : digits.substring(digits.length - 4);
  return '•••• ${last.padLeft(4, '0')}';
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
