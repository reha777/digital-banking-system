import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/mobile_shell.dart';
import '../accounts/account_models.dart';
import '../auth/auth_session.dart';
import '../cards/card_models.dart';
import '../cards/card_service.dart';
import '../cards/widgets/card_carousel.dart';
import 'pages/add_recipient_page.dart';
import 'transaction_models.dart';
import 'transaction_service.dart';
import 'widgets/recipient_selector.dart';
import 'widgets/send_money_amount_field.dart';
import 'widgets/transfer_confirmation_sheet.dart';
import 'widgets/transfer_result_view.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({
    super.key,
    required this.session,
    required this.sourceAccount,
    this.transactionService,
    this.initialCards,
  });

  final AuthSession session;
  final Account sourceAccount;
  final TransactionService? transactionService;
  final List<BankCardModel>? initialCards;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final TransactionService _service =
      widget.transactionService ?? TransactionService(ApiClient());
  late Future<List<RecentRecipient>> _recipientsFuture;
  late final CardService _cardService = CardService(ApiClient());
  late Future<List<BankCardModel>> _cardsFuture;
  BankCardModel? _selectedCard;
  RecentRecipient? _selectedRecipient;
  String? _error;
  MoneyTransferResult? _result;
  String? _transferCurrency;
  MoneyTransferQuote? _quote;
  Timer? _quoteDebounce;
  bool _quoteLoading = false;
  String? _quoteError;

  bool get _canSubmit =>
      _selectedRecipient != null &&
      (double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ??
              0) >
          0;
  bool get _sourceAllowed => _selectedCard?.canTransfer ?? false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_fieldChanged);
    final token = widget.session.token;
    _recipientsFuture = token == null
        ? Future.value([])
        : _service.getRecentRecipients(token);
    _cardsFuture = widget.initialCards != null
        ? Future.value(widget.initialCards)
        : token == null
        ? Future.value([])
        : _cardService.getMyCards(token);
  }

  void _fieldChanged() {
    setState(() {});
    _scheduleQuote();
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _scheduleQuote() {
    _quoteDebounce?.cancel();
    setState(() {
      _quote = null;
      _quoteError = null;
    });
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (_selectedCard == null ||
        _selectedRecipient == null ||
        _transferCurrency == null ||
        amount == null ||
        amount <= 0) {
      return;
    }
    _quoteDebounce = Timer(const Duration(milliseconds: 350), _loadQuote);
  }

  Future<void> _loadQuote() async {
    final token = widget.session.token;
    final card = _selectedCard;
    final recipient = _selectedRecipient;
    final currency = _transferCurrency;
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (token == null ||
        card == null ||
        recipient == null ||
        currency == null ||
        amount == null) {
      return;
    }
    setState(() => _quoteLoading = true);
    try {
      final value = await _service.getTransferQuote(
        token: token,
        sourceAccountId: card.accountId,
        destinationAccountNumber: recipient.accountNumber,
        amount: amount,
        currency: currency,
      );
      if (mounted) setState(() => _quote = value);
    } on ApiException catch (error) {
      if (mounted) setState(() => _quoteError = error.message);
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Future<void> _changeCurrency() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer Currency',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              ...const ['USD', 'EUR', 'BAM'].map(
                (currency) => ListTile(
                  key: ValueKey('currency-$currency'),
                  leading: const Icon(LucideIcons.coins),
                  title: Text(currency),
                  trailing: currency == _transferCurrency
                      ? const Icon(LucideIcons.check, color: AppTheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, currency),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _transferCurrency = selected);
      _scheduleQuote();
    }
  }

  Future<void> _addRecipient() async {
    final recipient = await Navigator.of(context).push<RecentRecipient>(
      MaterialPageRoute<RecentRecipient>(
        builder: (_) => AddRecipientPage(
          session: widget.session,
          service: _service,
          sourceAccountNumber:
              _selectedCard?.accountNumber ??
              widget.sourceAccount.accountNumber,
        ),
      ),
    );
    if (recipient != null && mounted) {
      setState(() => _selectedRecipient = recipient);
      _scheduleQuote();
    }
  }

  Future<MoneyTransferResult> _performTransfer() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Session expired. Please sign in again.', 401);
    }
    return _service.sendMoney(
      token: token,
      sourceAccountId: _selectedCard!.accountId,
      destinationAccountNumber: _selectedRecipient!.accountNumber,
      amount: double.parse(_amountController.text.trim().replaceAll(',', '.')),
      currency: _transferCurrency!,
      description: _descriptionController.text.trim(),
    );
  }

  Future<void> _sendMoney() async {
    if (_selectedRecipient == null || !_formKey.currentState!.validate()) {
      return;
    }
    final result = await showModalBottomSheet<MoneyTransferResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransferConfirmationSheet(
        card: _selectedCard!,
        recipient: _selectedRecipient!,
        amount: double.parse(
          _amountController.text.trim().replaceAll(',', '.'),
        ),
        description: _descriptionController.text.trim(),
        quote: _quote!,
        onConfirm: _performTransfer,
      ),
    );
    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) => MobileShell(
    currentIndex: 0,
    onSelected: (_) {},
    child: SafeArea(
      child: _result != null && _selectedRecipient != null
          ? TransferResultView(
              result: _result!,
              recipient: _selectedRecipient!,
              onDone: () => Navigator.of(context).pop(true),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: LucideIcons.arrowLeft,
                        onPressed: () => Navigator.of(context).pop(false),
                        tooltip: 'Back',
                      ),
                      Expanded(
                        child: Text(
                          'Send Money',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 26),
                  FutureBuilder<List<BankCardModel>>(
                    future: _cardsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const SizedBox(
                          height: 210,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text('Cards could not be loaded.'),
                          ),
                        );
                      }
                      final cards = snapshot.data ?? [];
                      if (cards.isEmpty) {
                        return const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'No card is available for sending money.',
                            ),
                          ),
                        );
                      }
                      _selectedCard ??= cards.firstWhere(
                        (card) => card.accountId == widget.sourceAccount.id,
                        orElse: () => cards.first,
                      );
                      _transferCurrency ??= _selectedCard!.currency;
                      return Column(
                        children: [
                          CardCarousel(
                            cards: cards,
                            initialIndex: cards
                                .indexWhere(
                                  (card) => card.id == _selectedCard!.id,
                                )
                                .clamp(0, cards.length - 1),
                            onCardChanged: (index) {
                              setState(() => _selectedCard = cards[index]);
                              _scheduleQuote();
                            },
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _selectedCard!.canTransfer
                                ? Text(
                                    '${_selectedCard!.currency} ${_selectedCard!.balance.toStringAsFixed(2)} available',
                                    key: ValueKey(_selectedCard!.id),
                                  )
                                : Text(
                                    '${_selectedCard!.status} card cannot be used for transfers.',
                                    key: ValueKey(_selectedCard!.id),
                                    style: const TextStyle(
                                      color: AppTheme.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  FutureBuilder<List<RecentRecipient>>(
                    future: _recipientsFuture,
                    builder: (context, snapshot) => RecipientSelector(
                      recipients: snapshot.data ?? const [],
                      selected: _selectedRecipient,
                      loading: snapshot.connectionState != ConnectionState.done,
                      hasError: snapshot.hasError,
                      onAdd: _addRecipient,
                      onSelected: (recipient) {
                        setState(() => _selectedRecipient = recipient);
                        _scheduleQuote();
                      },
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    alignment: Alignment.topCenter,
                    child: _selectedRecipient == null
                        ? const SizedBox(key: ValueKey('no-payment-details'))
                        : Column(
                            key: const ValueKey('payment-details'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.check,
                                      size: 18,
                                      color: AppTheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_selectedRecipient!.displayName} • ${_selectedRecipient!.accountNumber}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                key: const ValueKey('send-description'),
                                controller: _descriptionController,
                                maxLength: 250,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'What is this payment for?',
                                  prefixIcon: Icon(
                                    LucideIcons.messageSquareText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  SendMoneyAmountField(
                    currency:
                        _transferCurrency ??
                        _selectedCard?.currency ??
                        widget.sourceAccount.currency,
                    controller: _amountController,
                    availableBalance:
                        _selectedCard?.balance ?? widget.sourceAccount.balance,
                    debitAmount: _quote?.debitAmount,
                    onChangeCurrency: _changeCurrency,
                  ),
                  if (_quoteLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_quote?.requiresConversion == true)
                    _QuoteSummary(quote: _quote!),
                  if (_quoteError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _quoteError!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 72),
                  ElevatedButton(
                    key: const ValueKey('send-money-submit'),
                    onPressed:
                        _canSubmit &&
                            _sourceAllowed &&
                            _quote != null &&
                            !_quoteLoading
                        ? _sendMoney
                        : null,
                    child: const Text('Send Money'),
                  ),
                ],
              ),
            ),
    ),
  );
}

class _QuoteSummary extends StatelessWidget {
  const _QuoteSummary({required this.quote});
  final MoneyTransferQuote quote;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    child: Container(
      key: ValueKey('${quote.transferCurrency}-${quote.sourceCurrency}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _line(
            'You send',
            '${quote.amount.toStringAsFixed(2)} ${quote.transferCurrency}',
          ),
          _line(
            'Exchange rate',
            '1 ${quote.transferCurrency} = ${quote.exchangeRate.toStringAsFixed(4)} ${quote.sourceCurrency}',
          ),
          _line(
            'Debited',
            '${quote.debitAmount.toStringAsFixed(2)} ${quote.sourceCurrency}',
          ),
          _line(
            'Recipient gets',
            '${quote.destinationAmount.toStringAsFixed(2)} ${quote.destinationCurrency}',
          ),
        ],
      ),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
