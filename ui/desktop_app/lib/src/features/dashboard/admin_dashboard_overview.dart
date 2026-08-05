import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import 'admin_dashboard_models.dart';
import 'admin_dashboard_service.dart';

class AdminDashboardOverview extends StatefulWidget {
  const AdminDashboardOverview({
    super.key,
    required this.token,
    required this.onViewTransactions,
    required this.onViewReviews,
    required this.onViewCardRequests,
  });

  final String token;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewReviews;
  final VoidCallback onViewCardRequests;

  @override
  State<AdminDashboardOverview> createState() => _AdminDashboardOverviewState();
}

class _AdminDashboardOverviewState extends State<AdminDashboardOverview> {
  late final AdminDashboardService _service;
  late Future<AdminDashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    _service = AdminDashboardService(ApiClient());
    _future = _service.getSummary(token: widget.token);
  }

  void _refresh() {
    setState(() => _future = _service.getSummary(token: widget.token));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardSummary>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _DashboardLoading();
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle, size: 42),
                const SizedBox(height: 12),
                const Text('Dashboard data could not be loaded.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.requireData;
        return LayoutBuilder(
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
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _DashboardStat(
                      width: cardWidth,
                      icon: LucideIcons.users,
                      label: 'Total customers',
                      value: '${data.totalCustomers}',
                    ),
                    _DashboardStat(
                      width: cardWidth,
                      icon: LucideIcons.receipt,
                      label: 'Total transactions',
                      value: '${data.totalTransactions}',
                    ),
                    _DashboardStat(
                      width: cardWidth,
                      icon: LucideIcons.circleDollarSign,
                      label: 'Total transferred',
                      value: '\$${data.totalTransferred.toStringAsFixed(2)}',
                    ),
                    _DashboardStat(
                      width: cardWidth,
                      icon: LucideIcons.shieldAlert,
                      label: 'Pending reviews',
                      value: '${data.pendingReviews}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, inner) {
                    final recent = _RecentTransactions(
                      data: data,
                      onViewAll: widget.onViewTransactions,
                    );
                    final attention = _AttentionRequired(
                      data: data,
                      onReviews: widget.onViewReviews,
                      onCards: widget.onViewCardRequests,
                    );
                    if (inner.maxWidth < 900) {
                      return Column(
                        children: [
                          recent,
                          const SizedBox(height: 16),
                          attention,
                        ],
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
        );
      },
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });
  final double width;
  final IconData icon;
  final String label;
  final String value;

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
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
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

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.data, required this.onViewAll});
  final AdminDashboardSummary data;
  final VoidCallback onViewAll;
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
                  item.destinationCustomerName ??
                      item.destinationAccountNumber ??
                      '-',
                ),
                trailing: Text('\$${item.amount.toStringAsFixed(2)}'),
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
  });
  final AdminDashboardSummary data;
  final VoidCallback onReviews;
  final VoidCallback onCards;
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
            icon: LucideIcons.xCircle,
            label: 'Failed transactions',
            count: data.failedTransactions,
            onTap: onReviews,
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    leading: Icon(icon, size: 20),
    title: Text(label),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        const Icon(LucideIcons.chevronRight, size: 17),
      ],
    ),
  );
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
