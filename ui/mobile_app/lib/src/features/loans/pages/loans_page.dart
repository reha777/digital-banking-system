import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../accounts/account_models.dart';
import '../../accounts/account_service.dart';
import '../../auth/auth_session.dart';
import '../loan_service.dart';
import '../models/loan_models.dart';
import '../widgets/loan_widgets.dart';
import 'loan_application_page.dart';
import 'loan_details_page.dart';
import 'loan_payment_page.dart';

typedef LoanAccountsLoader =
    Future<AccountBalanceSummary> Function(String token);

class LoansPage extends StatefulWidget {
  const LoansPage({
    super.key,
    required this.session,
    this.repository,
    this.accountsLoader,
  });
  final AuthSession session;
  final LoanRepository? repository;
  final LoanAccountsLoader? accountsLoader;
  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansData {
  const _LoansData(
    this.products,
    this.application,
    this.accounts,
    this.activeLoan,
    this.recentLoan,
    this.recommendations,
    this.recommendationFailed,
  );
  final List<LoanProductModel> products;
  final LoanApplicationModel? application;
  final List<Account> accounts;
  final LoanModel? activeLoan;
  final LoanModel? recentLoan;
  final LoanRecommendationsModel recommendations;
  final bool recommendationFailed;
}

class _RecommendationLoad {
  const _RecommendationLoad(this.value, this.failed);
  final LoanRecommendationsModel value;
  final bool failed;
}

class _LoansPageState extends State<LoansPage> {
  late final LoanRepository _repository;
  late Future<_LoansData> _future;
  bool _applyAgain = false;
  String get _token => widget.session.token ?? '';
  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    _repository = widget.repository ?? LoanService(client);
    _future = _load();
  }

  Future<_LoansData> _load() async {
    if (_token.isEmpty) throw ApiException('Session expired.', 401);
    final loader =
        widget.accountsLoader ?? AccountService(ApiClient()).getBalanceSummary;
    final values = await Future.wait<Object?>([
      _repository.getProducts(_token),
      _repository.getCurrentApplication(_token),
      loader(_token),
      _repository.getCurrentLoan(_token),
      _repository.getRecentLoan(_token),
      _loadRecommendations(),
    ]);
    return _LoansData(
      values[0] as List<LoanProductModel>,
      values[1] as LoanApplicationModel?,
      (values[2] as AccountBalanceSummary).accounts,
      values[3] as LoanModel?,
      values[4] as LoanModel?,
      (values[5] as _RecommendationLoad).value,
      (values[5] as _RecommendationLoad).failed,
    );
  }

  Future<_RecommendationLoad> _loadRecommendations() async {
    try {
      return _RecommendationLoad(
        await _repository.getRecommendations(_token),
        false,
      );
    } catch (_) {
      return const _RecommendationLoad(
        LoanRecommendationsModel(
          canApply: true,
          disclaimer:
              'Recommendation is informational and does not represent loan approval.',
          recommendations: [],
        ),
        true,
      );
    }
  }

  Future<void> _details(LoanModel loan, List<Account> accounts) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanDetailsPage(
          token: _token,
          loanId: loan.loanId,
          accounts: accounts,
          repository: _repository,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _pay(LoanModel loan, List<Account> accounts) async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoanPaymentPage(
          token: _token,
          loan: loan,
          accounts: accounts,
          repository: _repository,
        ),
      ),
    );
    if (paid == true && mounted) await _refresh();
  }

  Future<void> _refresh() async {
    final value = _load();
    setState(() {
      _future = value;
      _applyAgain = false;
    });
    await value;
  }

  Future<void> _open(LoanProductModel product, List<Account> accounts) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoanApplicationPage(
          token: _token,
          product: product,
          accounts: accounts,
          repository: _repository,
        ),
      ),
    );
    if (submitted == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Loans'),
      leading: _applyAgain
          ? IconButton(
              tooltip: 'Back',
              onPressed: () => setState(() => _applyAgain = false),
              icon: const Icon(Icons.arrow_back),
            )
          : null,
    ),
    body: FutureBuilder<_LoansData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _error(snapshot.error.toString());
        final data = snapshot.requireData;
        final application = data.application;
        final activeLoan = data.activeLoan;
        final pendingApplication = application?.isPending == true;
        final completedLoan = data.recentLoan?.isCompleted == true
            ? data.recentLoan
            : null;
        final isStartingNewApplication =
            _applyAgain && activeLoan == null && !pendingApplication;
        final showCompletedLoan =
            activeLoan == null &&
            !pendingApplication &&
            completedLoan != null &&
            !isStartingNewApplication;
        final showProducts =
            activeLoan == null &&
            !pendingApplication &&
            (isStartingNewApplication ||
                (completedLoan == null &&
                    (application == null ||
                        (application.isRejected && _applyAgain))));
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (activeLoan != null) ...[
                ActiveLoanCard(
                  loan: activeLoan,
                  onDetails: () => _details(activeLoan, data.accounts),
                  onPay: () => _pay(activeLoan, data.accounts),
                ),
              ] else if (pendingApplication) ...[
                LoanStatusCard(application: application!),
              ] else if (showCompletedLoan) ...[
                ActiveLoanCard(
                  loan: completedLoan,
                  onDetails: () => _details(completedLoan, data.accounts),
                  onPay: () => _pay(completedLoan, data.accounts),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => setState(() => _applyAgain = true),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Apply for another Loan'),
                ),
              ] else if (!showProducts) ...[
                LoanStatusCard(application: application!),
                if (application.isRejected) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() => _applyAgain = true),
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('Apply Again'),
                  ),
                ],
              ] else ...[
                const Icon(LucideIcons.landmark, size: 42),
                const SizedBox(height: 12),
                Text(
                  application?.isRejected == true
                      ? 'Choose another loan'
                      : 'Find the right loan for you',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select a product, choose an amount and get a live repayment quote.',
                ),
                const SizedBox(height: 20),
                if (data.recommendationFailed) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recommendation is temporarily unavailable.',
                        ),
                      ),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else if (data.recommendations.recommendations.isNotEmpty) ...[
                  _RecommendedLoanCard(
                    recommendation: data.recommendations.recommendations.first,
                    product: data.products.firstWhere(
                      (product) =>
                          product.id ==
                          data.recommendations.recommendations.first.productId,
                    ),
                    onApply: (product) => _open(product, data.accounts),
                  ),
                  const SizedBox(height: 16),
                ] else if (data.recommendations.canApply &&
                    data.products.isNotEmpty) ...[
                  const Text(
                    'No suitable loan products are currently available for your accounts.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (data.products.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No loan products are currently available.'),
                    ),
                  )
                else
                  for (final product in data.products)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: LoanProductCard(
                        product: product,
                        onTap: () => _open(product, data.accounts),
                      ),
                    ),
              ],
            ],
          ),
        );
      },
    ),
  );
  Widget _error(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleAlert, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _RecommendedLoanCard extends StatelessWidget {
  const _RecommendedLoanCard({
    required this.recommendation,
    required this.product,
    required this.onApply,
  });

  final LoanRecommendationModel recommendation;
  final LoanProductModel product;
  final ValueChanged<LoanProductModel> onApply;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: .45),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.sparkles, size: 18),
              SizedBox(width: 8),
              Text('Recommended for you'),
            ],
          ),
          const SizedBox(height: 12),
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          Text('${product.annualInterestRate.toStringAsFixed(2)}% interest'),
          const SizedBox(height: 12),
          const Text('Why this fits:'),
          for (final reason in recommendation.reasons.take(2))
            Text('• $reason'),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => onApply(product),
            child: const Text('Apply'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Recommendation is informational and does not represent loan approval.',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
