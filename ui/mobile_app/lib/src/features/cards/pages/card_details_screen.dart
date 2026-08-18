import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../auth/auth_session.dart';
import '../../transactions/transaction_models.dart';
import '../../transactions/transaction_service.dart';
import '../../transactions/pages/transaction_history_screen.dart';
import '../../transactions/widgets/transaction_tile.dart';
import '../card_models.dart';
import '../card_service.dart';
import '../widgets/bank_card.dart';

class CardDetailsScreen extends StatefulWidget {
  const CardDetailsScreen({
    super.key,
    required this.session,
    required this.card,
    this.cardService,
    this.initialTransactions,
  });
  final AuthSession session;
  final BankCardModel card;
  final CardService? cardService;
  final List<BankTransaction>? initialTransactions;

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  late BankCardModel _card = widget.card;
  late final CardService _cards =
      widget.cardService ?? CardService(ApiClient());
  late final TransactionService _transactions = TransactionService(ApiClient());
  late final Future<List<BankTransaction>> _recent = _loadRecent();
  bool _revealed = false;
  bool _busy = false;
  String? _number;
  String? _cvv;

  Future<List<BankTransaction>> _loadRecent() async {
    if (widget.initialTransactions != null) return widget.initialTransactions!;
    final token = widget.session.token;
    if (token == null) return [];
    return (await _transactions.getTransactions(
      token: token,
      page: 1,
      pageSize: 4,
      accountId: _card.accountId,
    )).items;
  }

  Future<void> _toggleReveal() async {
    if (_revealed) {
      return setState(() {
        _revealed = false;
        _number = null;
        _cvv = null;
      });
    }
    final token = widget.session.token;
    if (token == null) return;
    setState(() => _busy = true);
    try {
      final value = await _cards.revealSensitiveData(
        token: token,
        cardId: _card.id,
      );
      if (mounted) {
        setState(() {
          _number = value.cardNumber;
          _cvv = value.cvv;
          _revealed = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleFrozen() async {
    final token = widget.session.token;
    if (token == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _cards.setFrozen(
        token: token,
        cardId: _card.id,
        frozen: !_card.isFrozen,
      );
      if (mounted) setState(() => _card = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context, _card),
                icon: const Icon(LucideIcons.arrowLeft),
              ),
              Expanded(
                child: Text(
                  'Card Details',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _toggleReveal,
                icon: Icon(_revealed ? LucideIcons.eyeOff : LucideIcons.eye),
              ),
            ],
          ),
          const SizedBox(height: 22),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _busy ? .72 : 1,
            child: BankCard(
              card: _card,
              revealed: _revealed,
              sensitiveCardNumber: _number,
              sensitiveCvv: _cvv,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 18,
            children: [
              _Info(
                'Available balance',
                '${_card.currency} ${formatMoney(_card.balance)}',
              ),
              _Info('Account number', _card.accountNumber),
              _Info('Status', _card.status),
              _Info('Cardholder', _card.cardholderName),
              _Info(
                'Card number',
                _revealed ? (_number ?? '') : _card.maskedCardNumber,
              ),
              _Info('CVV', _revealed ? (_cvv ?? '') : '•••'),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _busy || _card.status == 'Expired'
                ? null
                : _toggleFrozen,
            icon: Icon(
              _card.isFrozen ? LucideIcons.snowflake : LucideIcons.pause,
            ),
            label: Text(_card.isFrozen ? 'Unfreeze Card' : 'Freeze Card'),
          ),
          const SizedBox(height: 28),
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          FutureBuilder<List<BankTransaction>>(
            future: _recent,
            builder: (_, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('No transactions for this card account yet.'),
                );
              }
              return Column(
                children: [
                  ...items.map(
                    (item) => TransactionHistoryTile(transaction: item),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => TransactionHistoryScreen(
                          session: widget.session,
                          accountId: _card.accountId,
                        ),
                      ),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
