import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/app_error_message.dart';
import '../../core/app_theme.dart';
import 'admin_dashboard_models.dart';
import 'admin_dashboard_service.dart';
import '../settings/admin_formatters.dart';
import '../../core/currency_amount.dart';

class AdminDashboardOverview extends StatefulWidget {
  const AdminDashboardOverview({
    super.key,
    required this.token,
    required this.onViewTransactions,
    required this.onViewReviews,
    required this.onViewCardRequests,
    required this.onViewLoans,
    this.service,
    this.dateFormatter,
  });

  final String token;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewReviews;
  final VoidCallback onViewCardRequests;
  final VoidCallback onViewLoans;
  final AdminDashboardService? service;
  final String Function(DateTime)? dateFormatter;

  @override
  State<AdminDashboardOverview> createState() => _AdminDashboardOverviewState();
}

class _AdminDashboardOverviewState extends State<AdminDashboardOverview> {
  late final AdminDashboardService _service;
  AdminDashboardSummary? _data;
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  int _periodDays = 7;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AdminDashboardService(ApiClient());
    _load(initial: true);
  }

  Future<void> _load({bool initial = false}) async {
    final requestedPeriod = _periodDays;
    setState(() {
      _error = null;
      if (initial) {
        _loading = true;
      } else {
        _refreshing = true;
      }
    });
    try {
      final value = await _service.getDashboard(
        token: widget.token,
        periodDays: requestedPeriod,
      );
      if (!mounted || requestedPeriod != _periodDays) return;
      setState(() {
        _data = value;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted || requestedPeriod != _periodDays) return;
      setState(() {
        _error = error;
        _loading = false;
        _refreshing = false;
      });
      if (_data != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppErrorMessage.from(error))));
      }
    }
  }

  void _changePeriod(int value) {
    if (value == _periodDays) return;
    setState(() => _periodDays = value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const _DashboardLoading();
    if (_error != null && _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle, size: 42),
            const SizedBox(height: 12),
            Text(
              AppErrorMessage.from(
                _error!,
                fallback: 'Dashboard data could not be loaded.',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final data = _data!;
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 260),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1180
              ? 4
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          final cardWidth =
              (constraints.maxWidth - ((columns - 1) * 14)) / columns;
          return ListView(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton.filledTonal(
                  onPressed: _refreshing ? null : _load,
                  tooltip: 'Refresh dashboard',
                  icon: _refreshing
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.refreshCw, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _DashboardStat(
                    width: cardWidth,
                    icon: LucideIcons.users,
                    label: 'Customers · ${data.activeCustomers} active',
                    value: '${data.totalCustomers}',
                  ),
                  _DashboardStat(
                    width: cardWidth,
                    icon: LucideIcons.receipt,
                    label:
                        'Transactions · ${data.completedTransactions} completed',
                    value: '${data.totalTransactions}',
                  ),
                  _DashboardStat(
                    width: cardWidth,
                    icon: LucideIcons.shieldAlert,
                    label: 'Pending reviews',
                    value: '${data.pendingReviews}',
                  ),
                  _DashboardStat(
                    width: cardWidth,
                    icon: LucideIcons.coins,
                    label: 'Loans · ${data.pendingLoanApplications} pending',
                    value: '${data.activeLoans}',
                    suffix: ' active',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CompletedVolume(amounts: data.transferredByCurrency),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, analytics) {
                  final activity = _TransactionActivityCard(
                    points: data.transactionActivity,
                    periodDays: _periodDays,
                    onPeriodChanged: _changePeriod,
                    dateFormatter: widget.dateFormatter ?? _dashboardDate,
                  );
                  final operations = _OperationalOverview(
                    data: data,
                    onReviews: widget.onViewReviews,
                    onCards: widget.onViewCardRequests,
                    onLoans: widget.onViewLoans,
                    onTransactions: widget.onViewTransactions,
                  );
                  if (analytics.maxWidth < 980) {
                    return Column(
                      children: [
                        activity,
                        const SizedBox(height: 16),
                        operations,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: activity),
                      const SizedBox(width: 16),
                      Expanded(child: operations),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, inner) {
                  final recent = _RecentTransactions(
                    data: data,
                    onViewAll: widget.onViewTransactions,
                    dateFormatter: widget.dateFormatter ?? _dashboardDate,
                  );
                  final attention = _AttentionRequired(
                    data: data,
                    onReviews: widget.onViewReviews,
                    onCards: widget.onViewCardRequests,
                    onLoans: widget.onViewLoans,
                    onTransactions: widget.onViewTransactions,
                  );
                  if (inner.maxWidth < 900) {
                    return Column(
                      children: [recent, const SizedBox(height: 16), attention],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: recent),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: attention),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.suffix = '',
  });
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, _) => Text(
                      '${animatedValue.round()}$suffix',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CompletedVolume extends StatelessWidget {
  const _CompletedVolume({required this.amounts});
  final List<CurrencyAmount> amounts;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.barChart3,
              color: AppTheme.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Completed volume',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: amounts.isEmpty
                  ? [
                      Text(
                        'No completed volume yet',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]
                  : amounts
                        .map(
                          (amount) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: .5),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '${amount.currency} ${AdminFormatters.number(amount.amount)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TransactionActivityCard extends StatelessWidget {
  const _TransactionActivityCard({
    required this.points,
    required this.periodDays,
    required this.onPeriodChanged,
    required this.dateFormatter,
  });
  final List<TransactionActivityPoint> points;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;
  final String Function(DateTime) dateFormatter;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction activity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Daily transaction count',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _PeriodButton(
                label: '7D',
                selected: periodDays == 7,
                onTap: () => onPeriodChanged(7),
              ),
              const SizedBox(width: 5),
              _PeriodButton(
                label: '30D',
                selected: periodDays == 30,
                onTap: () => onPeriodChanged(30),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 240,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _ActivityChart(
                key: ValueKey(periodDays),
                points: points,
                dateFormatter: dateFormatter,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.primary.withValues(alpha: .11)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? AppTheme.primary
              : Theme.of(context).textTheme.bodySmall?.color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _OperationalOverview extends StatelessWidget {
  const _OperationalOverview({
    required this.data,
    required this.onReviews,
    required this.onCards,
    required this.onLoans,
    required this.onTransactions,
  });
  final AdminDashboardSummary data;
  final VoidCallback onReviews, onCards, onLoans, onTransactions;
  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, int, VoidCallback)>[
      (
        LucideIcons.shieldAlert,
        'Pending reviews',
        data.pendingReviews,
        onReviews,
      ),
      (
        LucideIcons.fileClock,
        'Documents requested',
        data.documentsRequested,
        onReviews,
      ),
      (
        LucideIcons.creditCard,
        'Card requests',
        data.pendingCardRequests,
        onCards,
      ),
      (
        LucideIcons.landmark,
        'Loan applications',
        data.pendingLoanApplications,
        onLoans,
      ),
      (LucideIcons.alertTriangle, 'Overdue loans', data.overdueLoans, onLoans),
      (
        LucideIcons.xCircle,
        'Failed transactions',
        data.failedTransactions,
        onTransactions,
      ),
    ];
    final maximum = items.fold<int>(
      1,
      (value, item) => item.$3 > value ? item.$3 : value,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operational overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 3),
            Text(
              'Items requiring operational attention',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final item in items)
              _OperationBar(
                icon: item.$1,
                label: item.$2,
                count: item.$3,
                fraction: item.$3 / maximum,
                onTap: item.$4,
              ),
          ],
        ),
      ),
    );
  }
}

class _OperationBar extends StatelessWidget {
  const _OperationBar({
    required this.icon,
    required this.label,
    required this.count,
    required this.fraction,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final double fraction;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActivityChart extends StatefulWidget {
  const _ActivityChart({
    super.key,
    required this.points,
    required this.dateFormatter,
  });
  final List<TransactionActivityPoint> points;
  final String Function(DateTime) dateFormatter;
  @override
  State<_ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<_ActivityChart> {
  int? _hovered;
  @override
  Widget build(BuildContext context) {
    final empty = widget.points.every((point) => point.count == 0);
    return LayoutBuilder(
      builder: (context, constraints) => MouseRegion(
        onExit: (_) => setState(() => _hovered = null),
        onHover: (event) {
          if (widget.points.isEmpty) return;
          final usable = constraints.maxWidth - 32;
          final position = ((event.localPosition.dx - 16) / usable).clamp(0, 1);
          setState(
            () => _hovered = (position * (widget.points.length - 1)).round(),
          );
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 560),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CustomPaint(
            painter: _ActivityPainter(
              points: widget.points,
              progress: progress,
              hovered: _hovered,
              dateFormatter: widget.dateFormatter,
              color: AppTheme.primary,
              gridColor: Theme.of(context).dividerColor.withValues(alpha: .55),
              textColor:
                  Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
              surfaceColor: Theme.of(context).colorScheme.surface,
            ),
            child: empty
                ? Center(
                    child: Text(
                      'No transaction activity in this period.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({
    required this.points,
    required this.progress,
    required this.hovered,
    required this.dateFormatter,
    required this.color,
    required this.gridColor,
    required this.textColor,
    required this.surfaceColor,
  });
  final List<TransactionActivityPoint> points;
  final double progress;
  final int? hovered;
  final String Function(DateTime) dateFormatter;
  final Color color, gridColor, textColor, surfaceColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 16.0, right = 16.0, top = 16.0, bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxCount = points.fold<int>(
      1,
      (value, point) => point.count > value ? point.count : value,
    );
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }
    Offset pointAt(int index) => Offset(
      chart.left +
          chart.width * index / (points.length - 1).clamp(1, points.length),
      chart.bottom - chart.height * (points[index].count / maxCount) * progress,
    );
    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      final previous = pointAt(i - 1), current = pointAt(i);
      final midpoint = (previous.dx + current.dx) / 2;
      line.cubicTo(
        midpoint,
        previous.dy,
        midpoint,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final area = Path.from(line)
      ..lineTo(chart.right, chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .2), color.withValues(alpha: .01)],
        ).createShader(chart),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final index in [0, points.length - 1]) {
      final label = _label(dateFormatter(points[index].dateUtc), textColor);
      label.paint(
        canvas,
        Offset(
          pointAt(index).dx - (index == 0 ? 0 : label.width),
          chart.bottom + 8,
        ),
      );
    }
    if (hovered case final index?) {
      final point = pointAt(index);
      canvas.drawCircle(point, 5, Paint()..color = surfaceColor);
      canvas.drawCircle(point, 3.2, Paint()..color = color);
      final tooltip = _label(
        '${dateFormatter(points[index].dateUtc)}  ·  ${points[index].count}',
        surfaceColor,
        bold: true,
      );
      final rect = Rect.fromLTWH(
        (point.dx - tooltip.width / 2 - 8).clamp(
          0,
          size.width - tooltip.width - 16,
        ),
        (point.dy - 38).clamp(0, size.height - 30),
        tooltip.width + 16,
        28,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(7)),
        Paint()..color = textColor,
      );
      tooltip.paint(canvas, Offset(rect.left + 8, rect.top + 7));
    }
  }

  TextPainter _label(String text, Color color, {bool bold = false}) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
  @override
  bool shouldRepaint(covariant _ActivityPainter old) =>
      old.points != points ||
      old.progress != progress ||
      old.hovered != hovered ||
      old.color != color;
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.data,
    required this.onViewAll,
    required this.dateFormatter,
  });
  final AdminDashboardSummary data;
  final VoidCallback onViewAll;
  final String Function(DateTime) dateFormatter;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View all transactions'),
              ),
            ],
          ),
          const Divider(),
          if (data.recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No recent transactions.')),
            )
          else
            ...data.recentTransactions.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.sourceCustomerName ?? item.accountNumber),
                subtitle: Text(
                  '${item.referenceNumber} · ${item.type.label} · ${item.status} · ${dateFormatter(item.createdAtUtc)}',
                ),
                trailing: Text(
                  '${item.currency} ${AdminFormatters.number(item.amount)}',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AttentionRequired extends StatelessWidget {
  const _AttentionRequired({
    required this.data,
    required this.onReviews,
    required this.onCards,
    required this.onLoans,
    required this.onTransactions,
  });
  final AdminDashboardSummary data;
  final VoidCallback onReviews;
  final VoidCallback onCards;
  final VoidCallback onLoans;
  final VoidCallback onTransactions;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attention required',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),
          _AttentionItem(
            icon: LucideIcons.shieldAlert,
            label: 'High-risk reviews',
            count: data.pendingReviews,
            onTap: onReviews,
          ),
          _AttentionItem(
            icon: LucideIcons.fileClock,
            label: 'Documents requested',
            count: data.documentsRequested,
            onTap: onReviews,
          ),
          _AttentionItem(
            icon: LucideIcons.creditCard,
            label: 'Pending card requests',
            count: data.pendingCardRequests,
            onTap: onCards,
          ),
          _AttentionItem(
            icon: LucideIcons.fileClock,
            label: 'Pending loan applications',
            count: data.pendingLoanApplications,
            onTap: onLoans,
          ),
          _AttentionItem(
            icon: LucideIcons.alertTriangle,
            label: 'Overdue loans',
            count: data.overdueLoans,
            onTap: onLoans,
          ),
          _AttentionItem(
            icon: LucideIcons.xCircle,
            label: 'Failed transactions',
            count: data.failedTransactions,
            onTap: onTransactions,
          ),
        ],
      ),
    ),
  );
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => count == 0
      ? const SizedBox.shrink()
      : ListTile(
          key: ValueKey(label),
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          leading: Icon(icon, size: 20),
          title: Text(label),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronRight, size: 17),
            ],
          ),
        );
}

String _dashboardDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}.';
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          for (var index = 0; index < 4; index++) ...[
            if (index > 0) const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 18),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: .32),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ],
  );
}
