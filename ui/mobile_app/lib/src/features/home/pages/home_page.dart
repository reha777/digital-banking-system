import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../accounts/account_models.dart';
import '../../accounts/account_service.dart';
import '../../auth/auth_session.dart';
import '../../cards/card_service.dart';
import '../../transactions/transaction_service.dart';
import '../dashboard_data.dart';
import '../widgets/home_balance_card.dart';
import '../widgets/recent_transactions.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onSendMoney,
    required this.onTransactionHistory,
    required this.onLogout,
  });

  final AuthSession session;
  final ValueChanged<Account> onSendMoney;
  final VoidCallback onTransactionHistory;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late final AccountService _accountService;
  late final TransactionService _transactionService;
  late final CardService _cardService;
  late Future<DashboardData> _dashboardFuture;

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
    final transactions = await _transactionService.getRecentTransactions(token);
    final cards = await _cardService.getMyCards(token);
    return DashboardData(
      balance: balance,
      transactions: transactions,
      cards: cards,
    );
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
                card: data.primaryCard,
                onSendMoney: data.balance.primaryAccount == null
                    ? null
                    : () => widget.onSendMoney(data.balance.primaryAccount!),
              ),
              const SizedBox(height: 24),
              RecentTransactions(
                transactions: data.transactions.take(4).toList(),
                onSeeAll: widget.onTransactionHistory,
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
