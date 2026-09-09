import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/document_opener.dart';
import '../../core/document_print_result.dart';
import '../../core/document_printer.dart';
import '../../core/supported_currencies.dart';
import '../../widgets/app_date_range_picker.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_status_badge.dart';
import 'report_models.dart';
import 'report_service.dart';

/// Sends already generated report bytes to the platform print workflow.
typedef ReportPrinter =
    Future<PrintOutcome> Function({
      required Uint8List bytes,
      required String fileName,
      required String contentType,
    });

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.token,
    this.dateFormatter,
    this.printer,
    this.service,
  });
  final String token;

  /// Injectable so widget tests drive the list without real network calls.
  final ReportService? service;

  /// The admin's configured date/time formatter, shared with the rest of the app.
  final String Function(DateTime)? dateFormatter;

  /// Injectable so widget tests never reach the real OS print dialog.
  final ReportPrinter? printer;

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

  /// Recent reports filter: '' is all report types.
  String recentType = '';
  String? _printingJobId;

  ReportPrinter get _printer => widget.printer ?? printDocumentBytes;

  List<ReportJobModel> get _visibleJobs => recentType.isEmpty
      ? jobs
      : jobs.where((job) => job.typeKey == recentType).toList();

  /// `DD.MM.YYYY HH:mm` through the same formatter the rest of the admin app
  /// uses, instead of slicing a raw DateTime string.
  String _requestedAt(ReportJobModel job) {
    final formatter = widget.dateFormatter;
    if (formatter != null) return formatter(job.requestedAtUtc.toUtc());
    final local = job.requestedAtUtc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  void initState() {
    super.initState();
    service = widget.service ?? ReportService(ApiClient());
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _download(ReportJobModel job) async {
    try {
      final bytes = await service.download(widget.token, job.id);
      final result = await openDocumentBytes(
        bytes: Uint8List.fromList(bytes),
        fileName: job.fileName ?? 'report.pdf',
        contentType: 'application/pdf',
      );
      if (!result.opened) {
        _notify(
          result.savedPath == null
              ? 'Report could not be opened.'
              : 'Report was saved to ${result.savedPath}, but could not be opened.',
        );
      }
    } catch (_) {
      _notify('Report could not be downloaded.');
    }
  }

  /// Sends the already generated PDF to the system print workflow. Independent
  /// of Download: it neither regenerates nor re-downloads a different report.
  Future<void> _print(ReportJobModel job) async {
    if (_printingJobId != null) return;
    setState(() => _printingJobId = job.id);
    try {
      final bytes = await service.download(widget.token, job.id);
      final outcome = await _printer(
        bytes: Uint8List.fromList(bytes),
        fileName: job.fileName ?? 'report.pdf',
        contentType: 'application/pdf',
      );
      _notify(switch (outcome) {
        PrintOutcome.printed => 'Report sent to the printer.',
        PrintOutcome.cancelled => 'Printing was cancelled.',
        PrintOutcome.unavailable =>
          'Printing is not available on this system. Use Download instead.',
      });
    } catch (_) {
      _notify('Report could not be printed.');
    } finally {
      if (mounted) setState(() => _printingJobId = null);
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
                        {'': 'All currencies', ...supportedCurrencyOptions},
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
              _drop(
                'Filter by type',
                recentType,
                const {
                  '': 'All report types',
                  'transactions': 'Transaction Report',
                  'loans': 'Loan Portfolio Report',
                },
                (value) => setState(() => recentType = value),
              ),
              const SizedBox(width: 12),
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
    final visible = _visibleJobs;
    if (visible.isEmpty) {
      // A filter that matches nothing is an empty result, never an error.
      final filtered = jobs.isNotEmpty;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.fileText, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    filtered ? 'No matching reports' : 'No reports yet',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    filtered
                        ? 'No reports match your filters.'
                        : 'Generated reports will appear here.',
                    textAlign: TextAlign.center,
                  ),
                  if (filtered) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => setState(() => recentType = ''),
                      icon: const Icon(LucideIcons.rotateCcw, size: 18),
                      label: const Text('Clear filters'),
                    ),
                  ],
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
              rows: visible
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
                        DataCell(Text(_requestedAt(job))),
                        DataCell(
                          Tooltip(
                            message: job.errorMessage ?? job.statusLabel,
                            child: AppStatusBadge(status: job.statusLabel),
                          ),
                        ),
                        DataCell(
                          job.downloadAvailable
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _download(job),
                                      icon: const Icon(Icons.download),
                                      label: const Text('Download'),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton.icon(
                                      onPressed: _printingJobId != null
                                          ? null
                                          : () => _print(job),
                                      icon: _printingJobId == job.id
                                          ? const SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.print),
                                      label: const Text('Print'),
                                    ),
                                  ],
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
