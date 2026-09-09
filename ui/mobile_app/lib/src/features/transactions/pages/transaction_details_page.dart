import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/formatting/account_number_formatters.dart';
import '../../../core/formatting/date_formatters.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../auth/auth_session.dart';
import '../transaction_models.dart';
import '../transaction_service.dart';
import '../widgets/transaction_status_badge.dart';

/// Detail of a single transaction, loaded from `GET /api/transactions/{id}`.
///
/// The history list carries a summary; this screen re-fetches by id so the
/// customer sees the full record the detail endpoint returns.
class TransactionDetailsPage extends StatefulWidget {
  const TransactionDetailsPage({
    super.key,
    required this.session,
    required this.transactionId,
    this.transactionService,
  });

  final AuthSession session;
  final String transactionId;
  final TransactionService? transactionService;

  @override
  State<TransactionDetailsPage> createState() => _TransactionDetailsPageState();
}

class _TransactionDetailsPageState extends State<TransactionDetailsPage> {
  late final TransactionService _service =
      widget.transactionService ?? TransactionService(ApiClient());
  BankTransaction? _transaction;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = widget.session.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Your session has expired.';
      });
      return;
    }
    try {
      final value = await _service.getTransactionById(
        token: token,
        id: widget.transactionId,
      );
      if (mounted) setState(() => _transaction = value);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Transaction details could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transaction Details')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : _details(context, _transaction!),
  );

  Widget _details(BuildContext context, BankTransaction value) {
    final isIncoming = value.amount > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              Text(
                '${isIncoming ? '+' : '-'}${formatMoney(value.amount.abs())} ${value.currency}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              TransactionStatusBadge(label: value.status),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _Row(label: 'Type', value: _typeLabel(value.type)),
        _Row(label: 'Status', value: value.status),
        _Row(label: 'Date', value: formatLocalDateTime(value.createdAtUtc)),
        if (value.referenceNumber.isNotEmpty)
          _Row(label: 'Reference', value: value.referenceNumber),
        if (value.description.trim().isNotEmpty)
          _Row(label: 'Description', value: value.description),
        _Row(
          label: 'Account',
          value: maskedNumericAccount(value.accountNumber),
        ),
        if (value.sourceAccountNumber != null &&
            value.sourceAccountNumber!.isNotEmpty)
          _Row(
            label: 'From',
            value: maskedNumericAccount(value.sourceAccountNumber!),
          ),
        if (value.destinationAccountNumber != null &&
            value.destinationAccountNumber!.isNotEmpty)
          _Row(
            label: 'To',
            value: maskedNumericAccount(value.destinationAccountNumber!),
          ),
        if (value.topUpSourceDescription != null &&
            value.topUpSourceDescription!.isNotEmpty)
          _Row(label: 'Top up source', value: value.topUpSourceDescription!),
        if (value.documentsRequestNote != null &&
            value.documentsRequestNote!.isNotEmpty)
          _Row(
            label: 'Requested documents',
            value: value.documentsRequestNote!,
          ),
      ],
    );
  }

  static String _typeLabel(BankTransactionType type) => switch (type) {
    BankTransactionType.transfer => 'Transfer',
    BankTransactionType.internalTransfer => 'Internal Transfer',
    BankTransactionType.loanDisbursement => 'Loan Disbursement',
    BankTransactionType.loanRepayment => 'Loan Repayment',
    BankTransactionType.topUp => 'Top Up',
  };
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
