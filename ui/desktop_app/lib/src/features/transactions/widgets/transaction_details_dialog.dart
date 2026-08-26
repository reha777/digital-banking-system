import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../widgets/app_page_states.dart';
import '../../../widgets/app_status_badge.dart';
import '../../settings/admin_formatters.dart';
import '../admin_transaction_models.dart';
import '../admin_transaction_service.dart';

class TransactionDetailsDialog extends StatefulWidget {
  const TransactionDetailsDialog({
    super.key,
    required this.token,
    required this.transactionId,
    required this.dateFormatter,
    required this.service,
  });

  final String token;
  final String transactionId;
  final String Function(DateTime) dateFormatter;
  final AdminTransactionService service;

  @override
  State<TransactionDetailsDialog> createState() =>
      _TransactionDetailsDialogState();
}

class _TransactionDetailsDialogState extends State<TransactionDetailsDialog> {
  late Future<AdminTransaction> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.getDetails(
      token: widget.token,
      id: widget.transactionId,
    );
  }

  void _retry() => setState(() {
    _future = widget.service.getDetails(
      token: widget.token,
      id: widget.transactionId,
    );
  });

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(LucideIcons.receipt),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Transaction Details',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<AdminTransaction>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const AppLoadingState();
                  }
                  if (snapshot.hasError) return AppErrorState(onRetry: _retry);
                  final item = snapshot.requireData;
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(
                          title: 'General',
                          values: [
                            ('Reference', item.referenceNumber),
                            ('Type', item.type.label),
                            ('Status', item.status),
                            (
                              'Created',
                              widget.dateFormatter(item.createdAtUtc),
                            ),
                          ],
                          status: item.status,
                        ),
                        _Section(
                          title: 'Financial',
                          values: [
                            ('Amount', AdminFormatters.number(item.amount)),
                            ('Currency', item.currency),
                          ],
                        ),
                        _Section(
                          title: 'Source',
                          values: [
                            (
                              'Account',
                              item.sourceAccountNumber ?? item.accountNumber,
                            ),
                            (
                              'Customer',
                              item.sourceCustomerName ?? 'Not available',
                            ),
                          ],
                        ),
                        _Section(
                          title: 'Destination',
                          values: [
                            (
                              'Account',
                              item.destinationAccountNumber ?? 'Not available',
                            ),
                            (
                              'Customer',
                              item.destinationCustomerName ?? 'Not available',
                            ),
                          ],
                        ),
                        _Section(
                          title: 'Description',
                          values: [
                            (
                              'Description',
                              item.description.isEmpty
                                  ? 'Not provided'
                                  : item.description,
                            ),
                          ],
                        ),
                        if (item.isHighRiskReview)
                          _Section(
                            title: 'Review',
                            values: [
                              (
                                'Risk reason',
                                item.reviewReason ?? 'Not provided',
                              ),
                              ('Admin note', item.adminNote ?? 'Not provided'),
                              (
                                'Reviewed',
                                item.reviewedAtUtc == null
                                    ? 'Not reviewed'
                                    : widget.dateFormatter(item.reviewedAtUtc!),
                              ),
                              (
                                'Documents request',
                                item.documentsRequestNote ?? 'Not requested',
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.values, this.status});
  final String title;
  final List<(String, String)> values;
  final String? status;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: values
              .map(
                (value) => SizedBox(
                  width: 310,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.$1,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (value.$1 == 'Status' && status != null)
                        AppStatusBadge(status: status!)
                      else
                        SelectableText(value.$2),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
