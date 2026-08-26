import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/document_opener.dart';
import '../../widgets/app_date_range_picker.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_status_badge.dart';
import 'report_models.dart';
import 'report_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.token});
  final String token;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final ReportService service;
  List<ReportJobModel> jobs = const [];
  Timer? timer;
  bool loading = true, creating = false, overdueOnly = false;
  String type = 'transactions', currency = '', status = '', semanticType = '';
  DateTime? from, to;

  @override
  void initState() {
    super.initState();
    service = ReportService(ApiClient());
    _load();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final page = await service.list(widget.token);
      if (!mounted) return;
      setState(() {
        jobs = page.items;
        loading = false;
      });
      timer?.cancel();
      if (jobs.any((x) => x.active)) {
        timer = Timer(const Duration(seconds: 3), _load);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => creating = true);
    try {
      await service.create(widget.token, type, {
        'dateFrom': from?.toUtc().toIso8601String(),
        'dateTo': to?.toUtc().toIso8601String(),
        'currency': currency.trim().isEmpty
            ? null
            : currency.trim().toUpperCase(),
        'status': status.isEmpty ? null : int.parse(status),
        if (type == 'transactions')
          'transactionType': semanticType.isEmpty
              ? null
              : int.parse(semanticType),
        if (type == 'loans') 'overdueOnly': overdueOnly,
      });
      await _load();
    } finally {
      if (mounted) {
        setState(() => creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generate and download operational PDF reports.'),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _drop(
                        'Report type',
                        type,
                        const {
                          'transactions': 'Transaction Report',
                          'loans': 'Loan Portfolio Report',
                        },
                        (v) => setState(() {
                          type = v;
                          status = '';
                        }),
                      ),
                      _drop(
                        'Status',
                        status,
                        type == 'loans'
                            ? const {'': 'All', '1': 'Active', '2': 'Completed'}
                            : const {
                                '': 'All',
                                '1': 'Pending',
                                '2': 'Completed',
                                '3': 'Failed',
                                '4': 'Cancelled',
                                '5': 'Documents requested',
                              },
                        (v) => setState(() => status = v),
                      ),
                      if (type == 'transactions')
                        _drop(
                          'Transaction type',
                          semanticType,
                          const {
                            '': 'All',
                            '1': 'Transfer',
                            '2': 'Internal transfer',
                            '3': 'Loan disbursement',
                            '4': 'Loan repayment',
                          },
                          (v) => setState(() => semanticType = v),
                        ),
                      _drop(
                        'Currency',
                        currency,
                        const {
                          '': 'All currencies',
                          'BAM': 'BAM',
                          'EUR': 'EUR',
                          'USD': 'USD',
                        },
                        (value) => setState(() => currency = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 340,
                        child: AppDateRangePicker(
                          dateFrom: from,
                          dateTo: to,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          onApply: (range) => setState(() {
                            from = range.start;
                            to = DateTime(
                              range.end.year,
                              range.end.month,
                              range.end.day,
                              23,
                              59,
                              59,
                            );
                          }),
                          onClear: () => setState(() {
                            from = null;
                            to = null;
                          }),
                        ),
                      ),
                      if (type == 'loans')
                        FilterChip(
                          label: const Text('Overdue only'),
                          selected: overdueOnly,
                          onSelected: (v) => setState(() => overdueOnly = v),
                        ),
                      FilledButton.icon(
                        onPressed: creating ? null : _generate,
                        icon: creating
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Generate PDF'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Text(
                'Recent reports',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _jobsTable()),
        ],
      ),
    ),
  );

  Widget _drop(
    String label,
    String value,
    Map<String, String> values,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: 210,
    child: AppDropdownField<String>(
      label: label,
      value: value,
      items: values.entries
          .map((item) => AppDropdownItem(value: item.key, label: item.value))
          .toList(),
      onChanged: changed,
    ),
  );

  Widget _jobsTable() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (jobs.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.fileText, size: 42),
                  SizedBox(height: 12),
                  Text(
                    'No reports yet',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Generated reports will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              columnSpacing: 34,
              columns: const [
                DataColumn(label: Text('Report')),
                DataColumn(label: Text('Requested by')),
                DataColumn(label: Text('Requested')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('File')),
              ],
              rows: jobs
                  .map(
                    (job) => DataRow(
                      color: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.hovered)
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: .035)
                            : null,
                      ),
                      cells: [
                        DataCell(Text(job.typeLabel)),
                        DataCell(Text(job.requestedBy)),
                        DataCell(
                          Text(
                            job.requestedAtUtc.toLocal().toString().substring(
                              0,
                              16,
                            ),
                          ),
                        ),
                        DataCell(
                          Tooltip(
                            message: job.errorMessage ?? job.statusLabel,
                            child: AppStatusBadge(status: job.statusLabel),
                          ),
                        ),
                        DataCell(
                          job.downloadAvailable
                              ? TextButton.icon(
                                  onPressed: () async {
                                    final bytes = await service.download(
                                      widget.token,
                                      job.id,
                                    );
                                    try {
                                      final result = await openDocumentBytes(
                                        bytes: Uint8List.fromList(bytes),
                                        fileName: job.fileName ?? 'report.pdf',
                                        contentType: 'application/pdf',
                                      );
                                      if (!result.opened && context.mounted) {
                                        final message = result.savedPath == null
                                            ? 'Report could not be opened.'
                                            : 'Report was saved to ${result.savedPath}, but could not be opened.';
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      }
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Report could not be downloaded.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download'),
                                )
                              : const Text('—'),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}
