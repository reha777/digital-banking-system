import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/mobile_shell.dart';
import '../auth/auth_session.dart';
import 'transaction_models.dart';
import 'transaction_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    required this.session,
  });

  final AuthSession session;

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  static const _pageSize = 20;

  late final TransactionService _transactionService;
  final _scrollController = ScrollController();
  final List<BankTransaction> _transactions = [];

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _transactionService = TransactionService(ApiClient());
    _scrollController.addListener(_loadMoreIfNeeded);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreIfNeeded);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isInitialLoading = true;
      _errorMessage = null;
      _page = 1;
      _totalPages = 1;
      _transactions.clear();
    });

    await _loadPage(1);

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || _page >= _totalPages) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    await _loadPage(_page + 1);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadPage(int page) async {
    final token = widget.session.token;
    if (token == null) {
      setState(() {
        _errorMessage = 'Sesija je istekla. Prijavite se ponovo.';
      });
      return;
    }

    try {
      final result = await _transactionService.getTransactions(
        token: token,
        page: page,
        pageSize: _pageSize,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = result.page;
        _totalPages = result.totalPages;
        _transactions.addAll(result.items);
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'API nije dostupan. Provjerite da backend radi i da je API_BASE_URL ispravan.',
        );
      }
    }
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients || _isInitialLoading || _isLoadingMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter < 260) {
      _loadNextPage();
    }
  }

  void _selectNavigation(int index) {
    if (index == 0) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(index);
  }

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      currentIndex: 0,
      onSelected: _selectNavigation,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Column(
            children: [
              _HistoryHeader(onRefresh: _loadFirstPage),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Today',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _loadFirstPage,
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _transactions.isEmpty) {
      return _HistoryError(
        message: _errorMessage!,
        onRetry: _loadFirstPage,
      );
    }

    if (_transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 140),
            Center(child: Text('No transactions yet.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _transactions.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _transactions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return TransactionHistoryTile(transaction: _transactions[index]);
        },
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        Expanded(
          child: Text(
            'Transaction History',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        CircleIconButton(
          icon: Icons.refresh,
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
      ],
    );
  }
}

class TransactionHistoryTile extends StatelessWidget {
  const TransactionHistoryTile({
    super.key,
    required this.transaction,
  });

  final BankTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncoming = transaction.amount > 0;
    final tone = isIncoming ? AppTheme.primary : _transactionTone(transaction);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
        child: Icon(_transactionIcon(transaction, isIncoming), color: tone, size: 18),
      ),
      title: Text(
        _transactionTitle(transaction),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        _transactionSubtitle(transaction),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Text(
        '${isIncoming ? '' : '- '}\$${_formatMoney(transaction.amount.abs())}',
        style: TextStyle(
          color: isIncoming ? AppTheme.primary : (isDark ? Colors.white : AppTheme.textDark),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

String _transactionTitle(BankTransaction transaction) {
  final description = transaction.description.trim();
  if (description.isEmpty || description.toLowerCase().contains('transfer')) {
    return 'Money Transfer';
  }

  return description;
}

String _transactionSubtitle(BankTransaction transaction) {
  final description = transaction.description.trim();
  if (description.isEmpty || description.toLowerCase().contains('transfer')) {
    return 'Transaction';
  }

  return transaction.status;
}

IconData _transactionIcon(BankTransaction transaction, bool isIncoming) {
  final text = transaction.description.toLowerCase();
  if (text.contains('grocery')) {
    return Icons.shopping_cart_outlined;
  }
  if (text.contains('spotify') || text.contains('music')) {
    return Icons.music_note;
  }
  if (text.contains('apple')) {
    return Icons.apple;
  }
  if (text.contains('netflix')) {
    return Icons.movie_creation_outlined;
  }

  return isIncoming ? Icons.arrow_downward : Icons.arrow_upward;
}

Color _transactionTone(BankTransaction transaction) {
  final text = transaction.description.toLowerCase();
  if (text.contains('grocery')) {
    return const Color(0xFFFF5A66);
  }
  if (text.contains('spotify') || text.contains('music')) {
    return const Color(0xFF1DB954);
  }
  if (text.contains('netflix')) {
    return const Color(0xFFE50914);
  }

  return AppTheme.textMuted;
}

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return '${buffer.toString()}.${parts.last}';
}
