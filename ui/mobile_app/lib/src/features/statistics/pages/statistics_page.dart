import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatting/account_number_formatters.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../auth/auth_session.dart';
import '../../transactions/transaction_models.dart';
import '../models/statistics_models.dart';
import '../statistics_service.dart';
import '../widgets/statistics_chart.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.session,
    this.onSeeAll,
    this.service,
  });
  final AuthSession session;
  final ValueChanged<StatisticsHistoryRequest>? onSeeAll;
  final StatisticsService? service;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final StatisticsService _service =
      widget.service ?? StatisticsService(ApiClient());
  StatisticsData? _data;
  String? _accountId, _currency, _error;
  bool _loading = true;
  StatisticsMetric _metric = StatisticsMetric.spending;
  int _monthIndex = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _from {
    final n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month - 5);
  }

  DateTime get _to {
    final n = DateTime.now().toUtc();
    return DateTime.utc(n.year, n.month + 1);
  }

  Future<void> _load() async {
    final token = widget.session.token;
    if (token == null) {
      setState(() {
        _error = 'Sesija je istekla. Prijavite se ponovo.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var data = await _service.getStatistics(
        token: token,
        from: _from,
        to: _to,
        accountId: _accountId,
      );
      if (!mounted) return;
      if (_accountId == null && data.accounts.isNotEmpty) {
        _accountId = data.accounts.first.id;
        data = await _service.getStatistics(
          token: token,
          from: _from,
          to: _to,
          accountId: _accountId,
        );
        if (!mounted) return;
      }
      setState(() {
        _data = data;
        _currency = data.currencySeries.any((e) => e.currency == _currency)
            ? _currency
            : (data.currencySeries.isEmpty
                  ? null
                  : data.currencySeries.first.currency);
        final count = data.currencySeries.isEmpty
            ? 0
            : data.currencySeries.first.months.length;
        _monthIndex = count == 0 ? 0 : count - 1;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException
              ? e.message
              : 'API nije dostupan. Provjerite backend i pokusajte ponovo.';
          _loading = false;
        });
      }
    }
  }

  CurrencyStatistics? get _series {
    final list = _data?.currencySeries ?? const <CurrencyStatistics>[];
    for (final item in list) {
      if (item.currency == _currency) return item;
    }
    return list.isEmpty ? null : list.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const _StatisticsLoading();
    if (_error != null && _data == null) {
      return _StatisticsError(message: _error!, onRetry: _load);
    }
    if ((_data?.accounts.isEmpty ?? true)) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No accounts available.')),
          ],
        ),
      );
    }
    final series = _series;
    if (series == null || series.months.isEmpty) {
      return _StatisticsError(
        message: 'No statistics available for this period.',
        onRetry: _load,
      );
    }
    _monthIndex = _monthIndex.clamp(0, series.months.length - 1);
    final selected = series.months[_monthIndex];
    final values = series.months
        .map(
          (m) => _metric == StatisticsMetric.spending ? m.spending : m.income,
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 32),
        children: [
          _accountSelector(),
          const SizedBox(height: 18),
          Text(
            'Current Balance',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${series.currency} ${formatMoney(series.balance)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if ((_data?.currencySeries.length ?? 0) > 1) ...[
            const SizedBox(height: 12),
            _currencySelector(),
          ],
          const SizedBox(height: 18),
          _metricSelector(),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: StatisticsChart(
              values: values,
              selectedIndex: _monthIndex,
              onSelected: (v) => setState(() => _monthIndex = v),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              series.months.length,
              (i) => Expanded(
                child: _MonthButton(
                  month: series.months[i],
                  selected: i == _monthIndex,
                  onTap: () => setState(() => _monthIndex = i),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${_metric == StatisticsMetric.spending ? 'Spending' : 'Income'} • ${_monthName(selected.month)} ${selected.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '${series.currency} ${formatMoney(values[_monthIndex])}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Spent',
                  value: selected.spending,
                  currency: series.currency,
                  color: const Color(0xFFFF5A66),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Income',
                  value: selected.income,
                  currency: series.currency,
                  color: const Color(0xFF27AE60),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  label: 'Net',
                  value: selected.net,
                  currency: series.currency,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'Transactions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onSeeAll == null
                    ? null
                    : () => widget.onSeeAll!(
                        StatisticsHistoryRequest(
                          accountId: _accountId,
                          from: selected.start,
                          to: selected.end,
                        ),
                      ),
                child: const Text('See All'),
              ),
            ],
          ),
          if (selected.recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No transactions this month.')),
            )
          else
            ...selected.recentTransactions.map(
              (t) => _StatisticsTransaction(
                transaction: t,
                currency: series.currency,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _accountSelector() {
    final account = _data!.accounts.firstWhere(
      (item) => item.id == _accountId,
      orElse: () => _data!.accounts.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: const CircleAvatar(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              child: Icon(LucideIcons.walletCards, size: 20),
            ),
            title: Text(
              'Account ${maskedNumericAccount(account.accountNumber)}',
            ),
            subtitle: Text(account.currency),
            trailing: Text(
              '${account.currency} ${formatMoney(account.balance)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('change-statistics-account'),
            onPressed: _pickAccount,
            icon: const Icon(LucideIcons.walletCards, size: 17),
            label: const Text('Change account'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAccount() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose account',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              ..._data!.accounts.map(
                (account) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: account.id == _accountId
                        ? AppTheme.primary.withValues(alpha: .12)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      onTap: () => Navigator.pop(context, account.id),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: const CircleAvatar(
                        child: Icon(LucideIcons.walletCards),
                      ),
                      title: Text(
                        'Account ${maskedNumericAccount(account.accountNumber)}',
                      ),
                      subtitle: Text(account.currency),
                      trailing: Text(
                        '${account.currency} ${formatMoney(account.balance)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != _accountId && mounted) {
      setState(() => _accountId = selected);
      await _load();
    }
  }

  Widget _currencySelector() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    children: _data!.currencySeries
        .map(
          (s) => ChoiceChip(
            label: Text('${s.currency} ${formatMoney(s.balance)}'),
            selected: s.currency == _currency,
            onSelected: (_) => setState(() {
              _currency = s.currency;
              _monthIndex = s.months.length - 1;
            }),
          ),
        )
        .toList(),
  );
  Widget _metricSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Expanded(
          child: _metricButton(
            StatisticsMetric.spending,
            'Spending',
            LucideIcons.trendingDown,
          ),
        ),
        Expanded(
          child: _metricButton(
            StatisticsMetric.income,
            'Income',
            LucideIcons.trendingUp,
          ),
        ),
      ],
    ),
  );

  Widget _metricButton(StatisticsMetric value, String label, IconData icon) {
    final selected = _metric == value;
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: ValueKey('statistics-${value.name}'),
        onTap: () => setState(() => _metric = value),
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : AppTheme.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.month,
    required this.selected,
    required this.onTap,
  });
  final MonthlyStatistics month;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: selected ? AppTheme.primary : Colors.transparent,
      foregroundColor: selected ? Colors.white : AppTheme.textMuted,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    ),
    child: Text(_monthName(month.month).substring(0, 3)),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.currency,
    required this.color,
  });
  final String label, currency;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        FittedBox(
          child: Text(
            '$currency ${formatMoney(value)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _StatisticsTransaction extends StatelessWidget {
  const _StatisticsTransaction({
    required this.transaction,
    required this.currency,
  });
  final BankTransaction transaction;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final incoming = transaction.amount > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (incoming ? AppTheme.primary : AppTheme.textMuted)
            .withValues(alpha: .1),
        child: Icon(
          incoming ? LucideIcons.arrowDown : LucideIcons.arrowUp,
          color: incoming ? AppTheme.primary : AppTheme.textMuted,
        ),
      ),
      title: Text(
        transaction.description.toString().trim().isEmpty
            ? 'Money Transfer'
            : transaction.description,
      ),
      subtitle: Text(transaction.status),
      trailing: Text(
        '${incoming ? '+' : '-'} $currency ${formatMoney(transaction.amount.abs())}',
        style: TextStyle(
          color: incoming ? AppTheme.primary : null,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatisticsLoading extends StatelessWidget {
  const _StatisticsLoading();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: List.generate(
      5,
      (i) => Container(
        height: i == 2 ? 180 : 54,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.textMuted.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}

class _StatisticsError extends StatelessWidget {
  const _StatisticsError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.chartNoAxesCombined,
            size: 42,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month.clamp(1, 12) - 1];
