import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../widgets/mobile_shell.dart';
import '../../auth/auth_session.dart';
import '../transaction_models.dart';
import '../transaction_service.dart';
import '../widgets/transaction_document_upload.dart';
import '../widgets/transaction_list.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
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

    if (!mounted) {
      return;
    }
    setState(() => _isInitialLoading = false);
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || _page >= _totalPages) {
      return;
    }

    setState(() => _isLoadingMore = true);
    await _loadPage(_page + 1);

    if (!mounted) {
      return;
    }
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadPage(int page) async {
    final token = widget.session.token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sesija je istekla. Prijavite se ponovo.';
        });
      }
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

    if (_scrollController.position.extentAfter < 260) {
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

  Future<void> _refreshAfterDocumentUpload() async {
    await _loadFirstPage();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Document uploaded.')));
  }

  void _handleMissingSession() {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = 'Sesija je istekla. Prijavite se ponovo.';
    });
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
                  Text('Today', style: Theme.of(context).textTheme.titleMedium),
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
      return _HistoryError(message: _errorMessage!, onRetry: _loadFirstPage);
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

    return TransactionList(
      transactions: _transactions,
      scrollController: _scrollController,
      isLoadingMore: _isLoadingMore,
      onRefresh: _loadFirstPage,
      documentUploadBuilder: (transaction) => TransactionDocumentUpload(
        transaction: transaction,
        token: widget.session.token,
        transactionService: _transactionService,
        onUploaded: _refreshAfterDocumentUpload,
        onMissingSession: _handleMissingSession,
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

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

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
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
