import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../accounts/account_models.dart';
import '../../accounts/account_service.dart';
import '../../auth/auth_session.dart';
import '../../cards/card_service.dart';
import '../../cards/card_models.dart';
import '../../transactions/transaction_service.dart';
import '../../transactions/transaction_models.dart';
import '../dashboard_data.dart';
import '../widgets/home_balance_card.dart';
import '../widgets/recent_transactions.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onSendMoney,
    required this.onReceiveMoney,
    required this.onTransfer,
    required this.onLoan,
    required this.onTransactionHistory,
    required this.onLogout,
    required this.onProfileTap,
    required this.onCardTap,
    required this.onNotificationsTap,
  });

  final AuthSession session;
  final ValueChanged<Account> onSendMoney;
  final VoidCallback onReceiveMoney;
  final VoidCallback onTransfer;
  final VoidCallback onLoan;
  final ValueChanged<String?> onTransactionHistory;
  final VoidCallback onLogout;
  final VoidCallback onProfileTap;
  final ValueChanged<BankCardModel> onCardTap;
  final Future<void> Function() onNotificationsTap;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final AccountService _accountService;
  late final TransactionService _transactionService;
  late final CardService _cardService;
  late Future<DashboardData> _dashboardFuture;
  List<BankTransaction> _recentTransactions = const [];
  String? _activeAccountId;
  String? _recentError;
  bool _recentLoading = false;
  int _recentRequestId = 0;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _accountService = AccountService(apiClient);
    _transactionService = TransactionService(apiClient);
    _cardService = CardService(apiClient);
    _dashboardFuture = _loadDashboard();
  }

  Future<DashboardData> _loadDashboard() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    final balance = await _accountService.getBalanceSummary(token);
    final cards = await _cardService.getMyCards(token);
    final activeCard =
        cards.where((card) => card.accountId == _activeAccountId).firstOrNull ??
        (cards.isEmpty ? null : cards.first);
    final accountId = activeCard?.accountId;
    final requestId = ++_recentRequestId;
    try {
      final transactions = accountId == null
          ? await _transactionService.getRecentTransactions(token)
          : (await _transactionService.getTransactions(
              token: token,
              page: 1,
              pageSize: 4,
              accountId: accountId,
            )).items;
      if (requestId == _recentRequestId) {
        _activeAccountId = accountId;
        _recentTransactions = transactions.take(4).toList();
        _recentError = null;
        _recentLoading = false;
      }
    } catch (_) {
      if (requestId == _recentRequestId) {
        _activeAccountId = accountId;
        _recentTransactions = const [];
        _recentError = 'Transactions could not be loaded.';
        _recentLoading = false;
      }
    }
    return DashboardData(
      balance: balance,
      transactions: _recentTransactions,
      cards: cards,
    );
  }

  Future<void> _selectCard(BankCardModel card) async {
    if (_activeAccountId == card.accountId) return;
    final token = widget.session.token;
    if (token == null) return;
    final requestId = ++_recentRequestId;
    setState(() {
      _activeAccountId = card.accountId;
      _recentLoading = true;
      _recentError = null;
    });
    try {
      final page = await _transactionService.getTransactions(
        token: token,
        page: 1,
        pageSize: 4,
        accountId: card.accountId,
      );
      if (!mounted || requestId != _recentRequestId) return;
      setState(() {
        _recentTransactions = page.items.take(4).toList();
        _recentLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _recentRequestId) return;
      setState(() {
        _recentTransactions = const [];
        _recentLoading = false;
        _recentError = 'Transactions could not be loaded.';
      });
    }
  }

  Future<void> _retryRecent() async {
    final data = await _dashboardFuture;
    final card = data.cards
        .where((item) => item.accountId == _activeAccountId)
        .firstOrNull;
    if (card != null) {
      await _selectCardAfterRetry(card);
      return;
    }
    final token = widget.session.token;
    if (token == null) return;
    final requestId = ++_recentRequestId;
    setState(() {
      _recentLoading = true;
      _recentError = null;
    });
    try {
      final items = await _transactionService.getRecentTransactions(token);
      if (!mounted || requestId != _recentRequestId) return;
      setState(() {
        _recentTransactions = items.take(4).toList();
        _recentLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _recentRequestId) return;
      setState(() {
        _recentTransactions = const [];
        _recentLoading = false;
        _recentError = 'Transactions could not be loaded.';
      });
    }
  }

  Future<void> _selectCardAfterRetry(BankCardModel card) async {
    _activeAccountId = null;
    await _selectCard(card);
  }

  void refresh() {
    if (mounted) {
      setState(() => _dashboardFuture = _loadDashboard());
    }
  }

  Future<void> _refreshAsync() async {
    final future = _loadDashboard();
    setState(() => _dashboardFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _HomeError(
            message: snapshot.error.toString(),
            onRetry: refresh,
            onLogout: widget.onLogout,
          );
        }

        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: _refreshAsync,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            children: [
              HomeBalanceCard(
                firstName: widget.session.user?.firstName ?? 'Customer',
                lastName: widget.session.user?.lastName ?? '',
                summary: data.balance,
                cards: data.cards,
                onSendMoney: (card) => widget.onSendMoney(
                  Account(
                    id: card.accountId,
                    accountNumber: card.accountNumber,
                    balance: card.balance,
                    currency: card.currency,
                  ),
                ),
                onReceiveMoney: widget.onReceiveMoney,
                onTransfer: widget.onTransfer,
                onLoan: widget.onLoan,
                onCardTap: widget.onCardTap,
                onActiveCardChanged: _selectCard,
                hasProfilePhoto: widget.session.user?.hasProfilePhoto ?? false,
                accessToken: widget.session.token,
                profilePhotoUpdatedAtUtc:
                    widget.session.user?.profilePhotoUpdatedAtUtc,
                onProfileTap: widget.onProfileTap,
                session: widget.session,
                onNotificationsTap: widget.onNotificationsTap,
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: RecentTransactions(
                  key: ValueKey(
                    'recent-${_activeAccountId ?? 'all'}-$_recentLoading-$_recentError',
                  ),
                  transactions: _recentTransactions,
                  loading: _recentLoading,
                  error: _recentError,
                  onRetry: _retryRecent,
                  onSeeAll: () => widget.onTransactionHistory(_activeAccountId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          TextButton(onPressed: onLogout, child: const Text('Sign out')),
        ],
      ),
    );
  }
}
