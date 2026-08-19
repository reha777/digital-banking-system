import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatting/account_number_formatters.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../../accounts/account_service.dart';
import '../../auth/auth_session.dart';
import '../../cards/card_models.dart';
import '../../cards/card_service.dart';
import '../../cards/widgets/card_carousel.dart';
import '../../transactions/transaction_models.dart';
import '../../transactions/transaction_service.dart';
import '../../transactions/widgets/send_money_amount_field.dart';

class AccountTransferPage extends StatefulWidget {
  const AccountTransferPage({
    super.key,
    required this.session,
    this.transactionService,
    this.accountService,
    this.cardService,
    this.initialSummary,
    this.initialCards,
  });

  final AuthSession session;
  final TransactionService? transactionService;
  final AccountService? accountService;
  final CardService? cardService;
  final AccountBalanceSummary? initialSummary;
  final List<BankCardModel>? initialCards;

  @override
  State<AccountTransferPage> createState() => _AccountTransferPageState();
}

class _AccountTransferPageState extends State<AccountTransferPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final TransactionService _transactionService =
      widget.transactionService ?? TransactionService(ApiClient());
  late final AccountService _accountService =
      widget.accountService ?? AccountService(ApiClient());
  late final CardService _cardService =
      widget.cardService ?? CardService(ApiClient());
  late Future<void> _loadFuture;
  List<Account> _accounts = const [];
  List<BankCardModel> _cards = const [];
  Account? _source;
  Account? _destination;
  MoneyTransferQuote? _quote;
  MoneyTransferResult? _result;
  Timer? _quoteDebounce;
  int _quoteRequestId = 0;
  bool _quoteLoading = false;
  bool _submitting = false;
  String? _quoteError;
  String? _loadError;

  double? get _amount =>
      double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
  bool get _amountValid {
    final value = _amount;
    return value != null && value > 0 && value <= (_source?.balance ?? 0);
  }

  bool get _canContinue =>
      _source != null &&
      _destination != null &&
      _amountValid &&
      _quote != null &&
      !_quoteLoading &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_scheduleQuote);
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Session expired. Please sign in again.', 401);
    }
    try {
      final summary =
          widget.initialSummary ??
          await _accountService.getBalanceSummary(token);
      final cards = widget.initialCards ?? await _cardService.getMyCards(token);
      if (!mounted) return;
      setState(() {
        _accounts = summary.accounts;
        _cards = cards;
        if (_accounts.isNotEmpty) _source = _accounts.first;
        if (_accounts.length > 1) _destination = _accounts[1];
      });
    } on ApiException catch (error) {
      _loadError = error.message;
      rethrow;
    }
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectSource(Account account) {
    setState(() {
      _source = account;
      if (_destination?.id == account.id) {
        _destination = _accounts
            .where((item) => item.id != account.id)
            .firstOrNull;
      }
    });
    _scheduleQuote();
  }

  void _selectDestination(Account account) {
    setState(() => _destination = account);
    _scheduleQuote();
  }

  Future<void> _pickSource() async {
    final selected = await _pickAccount(
      title: 'Choose source account',
      accounts: _accounts,
      selectedId: _source?.id,
    );
    if (selected != null && mounted) _selectSource(selected);
  }

  Future<void> _pickDestination() async {
    final source = _source;
    if (source == null) return;
    final selected = await _pickAccount(
      title: 'Choose destination account',
      accounts: _accounts.where((account) => account.id != source.id).toList(),
      selectedId: _destination?.id,
    );
    if (selected != null && mounted) _selectDestination(selected);
  }

  Future<Account?> _pickAccount({
    required String title,
    required List<Account> accounts,
    required String? selectedId,
  }) => showModalBottomSheet<Account>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ...accounts.map(
              (account) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AccountTile(
                  account: account,
                  selected: account.id == selectedId,
                  onTap: () => Navigator.pop(context, account),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _swap() {
    final source = _source;
    final destination = _destination;
    if (source == null || destination == null) return;
    setState(() {
      _source = destination;
      _destination = source;
      _quote = null;
      _quoteError = null;
    });
    _scheduleQuote();
  }

  void _scheduleQuote() {
    _quoteDebounce?.cancel();
    _quoteRequestId++;
    if (mounted) {
      setState(() {
        _quote = null;
        _quoteError = null;
      });
    }
    if (_source == null || _destination == null || !_amountValid) return;
    _quoteDebounce = Timer(const Duration(milliseconds: 350), _loadQuote);
  }

  Future<void> _loadQuote() async {
    final requestId = _quoteRequestId;
    final token = widget.session.token;
    final source = _source;
    final destination = _destination;
    final amount = _amount;
    if (token == null ||
        source == null ||
        destination == null ||
        amount == null) {
      return;
    }
    setState(() => _quoteLoading = true);
    try {
      final quote = await _transactionService.getInternalTransferQuote(
        token: token,
        sourceAccountId: source.id,
        destinationAccountId: destination.id,
        amount: amount,
      );
      if (mounted &&
          requestId == _quoteRequestId &&
          source.id == _source?.id &&
          destination.id == _destination?.id) {
        setState(() => _quote = quote);
      }
    } on ApiException catch (error) {
      if (mounted && requestId == _quoteRequestId) {
        setState(() => _quoteError = error.message);
      }
    } finally {
      if (mounted && requestId == _quoteRequestId) {
        setState(() => _quoteLoading = false);
      }
    }
  }

  Future<void> _continue() async {
    final quote = _quote;
    final source = _source;
    final destination = _destination;
    if (!_canContinue ||
        quote == null ||
        source == null ||
        destination == null) {
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConfirmationSheet(
        source: source,
        destination: destination,
        quote: quote,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    if (confirmed == true && mounted) await _submit();
  }

  Future<void> _submit() async {
    final token = widget.session.token;
    final source = _source;
    final destination = _destination;
    final amount = _amount;
    if (token == null ||
        source == null ||
        destination == null ||
        amount == null) {
      return;
    }
    setState(() {
      _submitting = true;
      _quoteError = null;
    });
    try {
      final result = await _transactionService.internalTransfer(
        token: token,
        sourceAccountId: source.id,
        destinationAccountId: destination.id,
        amount: amount,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
      if (mounted) setState(() => _result = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _quoteError = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _SuccessView(
        result: _result!,
        destination: _destination!,
        onDone: () => Navigator.pop(context, true),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _StateMessage(
              icon: LucideIcons.wifiOff,
              title: 'Accounts unavailable',
              message: _loadError ?? 'Could not load your accounts.',
            );
          }
          if (_accounts.isEmpty) {
            return const _StateMessage(
              icon: LucideIcons.walletCards,
              title: 'No accounts available',
              message: 'You need an account before making a transfer.',
            );
          }
          if (_accounts.length == 1) {
            return const _StateMessage(
              icon: LucideIcons.arrowRightLeft,
              title: 'Another account is required',
              message:
                  'Open a second account to transfer between your accounts.',
            );
          }
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildForm() {
    final source = _source!;
    final cardAccounts = _cards
        .where(
          (card) => _accounts.any((account) => account.id == card.accountId),
        )
        .toList();
    final selectedCardIndex = cardAccounts.indexWhere(
      (card) => card.accountId == source.id,
    );
    final amount = _amount;
    final localAmountError = amount != null && amount > source.balance
        ? 'Insufficient balance.'
        : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('From', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (cardAccounts.isNotEmpty && selectedCardIndex >= 0)
            CardCarousel(
              key: ValueKey('source-cards-${source.id}'),
              cards: cardAccounts,
              initialIndex: selectedCardIndex,
              onCardChanged: (index) {
                final account = _accounts.firstWhere(
                  (item) => item.id == cardAccounts[index].accountId,
                );
                _selectSource(account);
              },
            )
          else
            _AccountTile(account: source, selected: true, onTap: null),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('change-source-account'),
              onPressed: _pickSource,
              icon: const Icon(LucideIcons.walletCards, size: 18),
              label: const Text('Change account'),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: IconButton.filledTonal(
              key: const ValueKey('swap-accounts'),
              tooltip: 'Swap accounts',
              onPressed: _swap,
              icon: const Icon(LucideIcons.arrowDownUp),
            ),
          ),
          Text('To', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _AccountTile(
            account: _destination!,
            selected: true,
            onTap: _pickDestination,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('transfer-description'),
            controller: _descriptionController,
            maxLength: 250,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What is this transfer for? (optional)',
              prefixIcon: Icon(LucideIcons.messageSquareText),
            ),
          ),
          const SizedBox(height: 16),
          SendMoneyAmountField(
            currency: source.currency,
            controller: _amountController,
            availableBalance: source.balance,
            debitAmount: _quote?.debitAmount,
            trailingLabel: 'Account Currency',
            fieldKey: const ValueKey('transfer-amount'),
            errorText: localAmountError ?? _quoteError,
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _quoteLoading
                  ? const LinearProgressIndicator(
                      key: ValueKey('quote-loading'),
                    )
                  : _quote == null
                  ? const SizedBox.shrink(key: ValueKey('quote-empty'))
                  : _QuoteCard(quote: _quote!),
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            key: const ValueKey('continue-transfer'),
            onPressed: _canContinue ? _continue : null,
            child: Text(_submitting ? 'Transferring...' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final Account account;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppTheme.primary.withValues(alpha: .12)
        : Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(14),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: const CircleAvatar(child: Icon(LucideIcons.walletCards)),
      title: Text('Account ${maskedNumericAccount(account.accountNumber)}'),
      subtitle: Text(account.currency),
      trailing: Text(
        '${account.currency} ${formatMoney(account.balance)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final MoneyTransferQuote quote;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('internal-transfer-quote'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.primary.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        _row(
          'Debit',
          '${quote.sourceCurrency} ${formatMoney(quote.debitAmount)}',
        ),
        const SizedBox(height: 8),
        _row(
          'Recipient gets',
          '${quote.destinationCurrency} ${formatMoney(quote.destinationAmount)}',
        ),
        if (quote.requiresConversion) ...[
          const SizedBox(height: 8),
          _row(
            'Exchange rate',
            '1 ${quote.sourceCurrency} = ${quote.exchangeRate.toStringAsFixed(4)} ${quote.destinationCurrency}',
          ),
        ],
      ],
    ),
  );

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label),
      Flexible(child: Text(value, textAlign: TextAlign.end)),
    ],
  );
}

class _ConfirmationSheet extends StatelessWidget {
  const _ConfirmationSheet({
    required this.source,
    required this.destination,
    required this.quote,
    required this.onConfirm,
  });
  final Account source;
  final Account destination;
  final MoneyTransferQuote quote;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm transfer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Text('From  ${_maskedAccount(source.accountNumber)}'),
          const SizedBox(height: 10),
          Text('To      ${_maskedAccount(destination.accountNumber)}'),
          const SizedBox(height: 18),
          _QuoteCard(quote: quote),
          const SizedBox(height: 22),
          ElevatedButton(
            key: const ValueKey('confirm-transfer'),
            onPressed: onConfirm,
            child: const Text('Confirm Transfer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.result,
    required this.destination,
    required this.onDone,
  });
  final MoneyTransferResult result;
  final Account destination;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 38,
              backgroundColor: Color(0xFFDBF8E8),
              child: Icon(
                LucideIcons.check,
                color: Color(0xFF159455),
                size: 38,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Transfer successful',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '${result.currency} ${formatMoney(result.amount)} was transferred to ${_maskedAccount(destination.accountNumber)}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Reference ${result.referenceNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

String _maskedAccount(String value) {
  return maskedNumericAccount(value);
}
