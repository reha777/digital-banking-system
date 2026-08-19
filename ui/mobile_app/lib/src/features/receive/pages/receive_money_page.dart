import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/mobile_shell.dart';
import '../../accounts/account_models.dart';
import '../../accounts/account_service.dart';
import '../../auth/auth_session.dart';
import '../../cards/card_models.dart';
import '../../cards/card_service.dart';
import '../../cards/widgets/card_carousel.dart';
import '../receive_qr_payload.dart';

class ReceiveMoneyPage extends StatefulWidget {
  const ReceiveMoneyPage({
    super.key,
    required this.session,
    this.accountService,
    this.cardService,
    this.initialSummary,
    this.initialCards,
  });

  final AuthSession session;
  final AccountService? accountService;
  final CardService? cardService;
  final AccountBalanceSummary? initialSummary;
  final List<BankCardModel>? initialCards;

  @override
  State<ReceiveMoneyPage> createState() => _ReceiveMoneyPageState();
}

class _ReceiveMoneyPageState extends State<ReceiveMoneyPage> {
  late final AccountService _accountService =
      widget.accountService ?? AccountService(ApiClient());
  late final CardService _cardService =
      widget.cardService ?? CardService(ApiClient());
  late Future<_ReceiveData> _future;
  int _selectedCard = 0;
  int _selectedAccount = 0;
  bool _copied = false;
  Timer? _copyResetTimer;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Future<_ReceiveData> _load() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Session expired. Please sign in again.', 401);
    }
    final summaryFuture = widget.initialSummary != null
        ? Future.value(widget.initialSummary!)
        : _accountService.getBalanceSummary(token);
    final cardsFuture = widget.initialCards != null
        ? Future.value(widget.initialCards!)
        : _cardService.getMyCards(token);
    final values = await Future.wait<Object>([summaryFuture, cardsFuture]);
    return _ReceiveData(
      summary: values[0] as AccountBalanceSummary,
      cards: values[1] as List<BankCardModel>,
    );
  }

  void _retry() => setState(() {
    _selectedCard = 0;
    _selectedAccount = 0;
    _future = _load();
  });

  Future<void> _copy(String accountNumber) async {
    await Clipboard.setData(ClipboardData(text: accountNumber));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account number copied')));
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _share(Account account) async {
    final user = widget.session.user;
    final name = '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Receive money',
        text:
            'Receive money\n\n'
            'Name: ${name.isEmpty ? 'Bank customer' : name}\n'
            'Account: ${account.accountNumber}\n'
            'Currency: ${account.currency}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<_ReceiveData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ReceiveError(onRetry: _retry);
          }
          final data = snapshot.requireData;
          if (data.summary.accounts.isEmpty) {
            return const _ReceiveEmpty();
          }
          return _buildContent(data);
        },
      ),
    ),
  );

  Widget _buildContent(_ReceiveData data) {
    final cards = data.cards
        .where((card) => data.accountById.containsKey(card.accountId))
        .toList();
    final Account account;
    if (cards.isNotEmpty) {
      final card = cards[_selectedCard.clamp(0, cards.length - 1)];
      account = data.accountById[card.accountId]!;
    } else {
      account =
          data.summary.accounts[_selectedAccount.clamp(
            0,
            data.summary.accounts.length - 1,
          )];
    }
    final payload = ReceiveQrPayload(
      accountNumber: account.accountNumber,
      currency: account.currency.toUpperCase(),
    ).encode();
    final user = widget.session.user;
    final holder = '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: [
        Row(
          children: [
            CircleIconButton(
              icon: LucideIcons.arrowLeft,
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            Expanded(
              child: Text(
                'Receive Money',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 24),
        Text('Receive to', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (cards.isNotEmpty)
          CardCarousel(
            cards: cards,
            initialIndex: _selectedCard.clamp(0, cards.length - 1),
            onCardChanged: (index) => setState(() {
              _selectedCard = index;
              _copied = false;
            }),
          )
        else
          _AccountSelector(
            accounts: data.summary.accounts,
            selectedIndex: _selectedAccount,
            onChanged: (index) => setState(() {
              _selectedAccount = index;
              _copied = false;
            }),
          ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Container(
            key: ValueKey('qr-${account.id}'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x18000000), blurRadius: 24),
              ],
            ),
            child: QrImageView(
              key: ValueKey(payload),
              data: payload,
              version: QrVersions.auto,
              size: 220,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF111322),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF111322),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _AccountDetails(
            key: ValueKey('details-${account.id}'),
            holder: holder.isEmpty ? 'Bank customer' : holder,
            account: account,
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          key: const ValueKey('copy-account-number'),
          onPressed: () => _copy(account.accountNumber),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              _copied ? LucideIcons.check : LucideIcons.copy,
              key: ValueKey(_copied),
            ),
          ),
          label: const Text('Copy Account Number'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          key: const ValueKey('share-payment-details'),
          onPressed: () => _share(account),
          icon: const Icon(LucideIcons.share2),
          label: const Text('Share Payment Details'),
        ),
        const SizedBox(height: 18),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shieldCheck, size: 16, color: AppTheme.textMuted),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Share this QR code or account number to receive money.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiveData {
  const _ReceiveData({required this.summary, required this.cards});
  final AccountBalanceSummary summary;
  final List<BankCardModel> cards;
  Map<String, Account> get accountById => {
    for (final account in summary.accounts) account.id: account,
  };
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({
    super.key,
    required this.holder,
    required this.account,
  });
  final String holder;
  final Account account;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(holder, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text('${account.currency} Account'),
      const SizedBox(height: 8),
      SelectableText(
        account.accountNumber,
        key: const ValueKey('receive-account-number'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .6),
      ),
    ],
  );
}

class _AccountSelector extends StatelessWidget {
  const _AccountSelector({
    required this.accounts,
    required this.selectedIndex,
    required this.onChanged,
  });
  final List<Account> accounts;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 145,
        child: PageView.builder(
          itemCount: accounts.length,
          controller: PageController(
            initialPage: selectedIndex,
            viewportFraction: accounts.length > 1 ? .92 : 1,
          ),
          onPageChanged: onChanged,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.landmark),
                    const Spacer(),
                    Text(
                      account.accountNumber,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('${account.currency} Account'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _ReceiveError extends StatelessWidget {
  const _ReceiveError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleAlert, size: 42),
          const SizedBox(height: 14),
          const Text('Receive details could not be loaded.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ReceiveEmpty extends StatelessWidget {
  const _ReceiveEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.landmark, size: 44),
          SizedBox(height: 14),
          Text('No account available to receive money.'),
        ],
      ),
    ),
  );
}
