import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/app_error_message.dart';
import '../../core/app_theme.dart';
import '../../widgets/app_date_range_picker.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_page_states.dart';
import '../../widgets/app_pagination.dart';
import '../../widgets/app_table_row_hover.dart';
import 'audit_log_models.dart';
import 'audit_log_service.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({
    super.key,
    required this.token,
    required this.defaultPageSize,
    required this.dateFormatter,
    this.service,
  });
  final String token;
  final int defaultPageSize;
  final String Function(DateTime) dateFormatter;
  final AuditLogService? service;
  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final _search = TextEditingController();
  late final AuditLogService _service;
  late Future<AuditLogPageModel> _future;
  Timer? _debounce;
  int _page = 1;
  late int _pageSize;
  String? _action, _entity;
  DateTimeRange? _dates;
  static const actions = [
    'CustomerUpdated',
    'CustomerStatusChanged',
    'CustomerDeleted',
    'TransactionApproved',
    'TransactionRejected',
    'TransactionDocumentsRequested',
    'CardRequestApproved',
    'CardRequestRejected',
    'CardDocumentsRequested',
    'LoanApproved',
    'LoanRejected',
    'AdminSettingsUpdated',
    'AdminProfileUpdated',
  ];
  static const entities = [
    'Customer',
    'Transaction',
    'CardRequest',
    'LoanApplication',
    'AdminSettings',
    'AdminProfile',
  ];

  bool get _filtered =>
      _search.text.trim().isNotEmpty ||
      _action != null ||
      _entity != null ||
      _dates != null;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.defaultPageSize;
    _service = widget.service ?? AuditLogService(ApiClient());
    _future = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<AuditLogPageModel> _load() => _service.getLogs(
    token: widget.token,
    page: _page,
    pageSize: _pageSize,
    search: _search.text,
    action: _action,
    entityType: _entity,
    dateFrom: _dates?.start,
    dateTo: _dates?.end
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1)),
  );
  void _refresh({bool reset = false}) {
    if (reset) _page = 1;
    setState(() {
      _future = _load();
    });
  }

  void _clear() {
    _search.clear();
    _action = null;
    _entity = null;
    _dates = null;
    _refresh(reset: true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppPageHeader(
        icon: LucideIcons.scrollText,
        title: 'Audit Logs',
        subtitle: 'Review administrative activity across the banking system.',
        action: IconButton.filledTonal(
          onPressed: _refresh,
          tooltip: 'Refresh audit logs',
          icon: const Icon(LucideIcons.refreshCw, size: 18),
        ),
      ),
      const SizedBox(height: 20),
      _filters(),
      const SizedBox(height: 18),
      Expanded(child: _content()),
    ],
  );

  Widget _filters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _border(context)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth < 330 ? constraints.maxWidth : 330,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.search, size: 18),
                labelText: 'Search audit logs',
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) _refresh(reset: true);
                });
              },
            ),
          ),
          _dropdown('Action', _action, actions, (value) {
            _action = value;
            _refresh(reset: true);
          }),
          _dropdown('Entity type', _entity, entities, (value) {
            _entity = value;
            _refresh(reset: true);
          }),
          SizedBox(
            width: 245,
            child: AppDateRangePicker(
              dateFrom: _dates?.start,
              dateTo: _dates?.end,
              onApply: (value) {
                _dates = value;
                _refresh(reset: true);
              },
              onClear: () {
                _dates = null;
                _refresh(reset: true);
              },
            ),
          ),
          IconButton.filledTonal(
            onPressed: _refresh,
            tooltip: 'Refresh data',
            icon: const Icon(LucideIcons.refreshCw, size: 18),
          ),
          IconButton.filledTonal(
            onPressed: _clear,
            tooltip: 'Reset filters',
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
          ),
        ],
      ),
    ),
  );

  Widget _content() => FutureBuilder<AuditLogPageModel>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppLoadingState();
      }
      if (snapshot.hasError) {
        return AppErrorState(
          message: AppErrorMessage.from(snapshot.error!),
          onRetry: _refresh,
        );
      }
      final data = snapshot.requireData;
      if (data.items.isEmpty) {
        return AppEmptyState(
          icon: LucideIcons.scrollText,
          title: 'No audit activity',
          message: _filtered
              ? 'No audit logs match the selected filters.'
              : 'Administrative actions will appear here.',
          onReset: _filtered ? _clear : null,
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: constraints.maxWidth <= 800
                  ? ListView.separated(
                      itemCount: data.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _AuditCompactRow(
                        entry: data.items[index],
                        date: widget.dateFormatter(
                          data.items[index].createdAtUtc,
                        ),
                        onView: () => _details(data.items[index]),
                      ),
                    )
                  : _AuditTable(
                      entries: data.items,
                      dateFormatter: widget.dateFormatter,
                      onView: _details,
                    ),
            ),
            const SizedBox(height: 12),
            AppPagination(
              currentPage: data.page,
              totalPages: data.totalPages,
              pageSize: data.pageSize,
              shownCount: data.items.length,
              totalCount: data.totalCount,
              itemLabel: 'events',
              onPageSelected: (value) {
                _page = value;
                _refresh();
              },
              onPageSizeChanged: (value) {
                _pageSize = value;
                _refresh(reset: true);
              },
            ),
          ],
        ),
      );
    },
  );

  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 210,
    child: AppDropdownField<String?>(
      label: label,
      value: value,
      items: [
        const AppDropdownItem(value: null, label: 'All'),
        ...values.map(
          (value) => AppDropdownItem(value: value, label: _displayValue(value)),
        ),
      ],
      onChanged: changed,
    ),
  );

  void _details(AuditLogEntry entry) => showDialog<void>(
    context: context,
    builder: (_) => _AuditLogDetailsDialog(
      entry: entry,
      formattedDate: widget.dateFormatter(entry.createdAtUtc),
    ),
  );
}

class _AuditTable extends StatelessWidget {
  const _AuditTable({
    required this.entries,
    required this.dateFormatter,
    required this.onView,
  });
  final List<AuditLogEntry> entries;
  final String Function(DateTime) dateFormatter;
  final ValueChanged<AuditLogEntry> onView;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 1020 ? 1020.0 : constraints.maxWidth;
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: Column(
              children: [
                const _AuditTableHeader(),
                Expanded(
                  child: ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: _border(context).withValues(alpha: .72),
                    ),
                    itemBuilder: (_, index) => _AuditTableRow(
                      entry: entries[index],
                      date: dateFormatter(entries[index].createdAtUtc),
                      onView: () => onView(entries[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AuditTableHeader extends StatelessWidget {
  const _AuditTableHeader();
  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF202033)
        : const Color(0xFFF8FAFC),
    child: const _AuditColumns(
      children: [
        _HeaderLabel('TIME'),
        _HeaderLabel('ADMIN'),
        _HeaderLabel('ACTION'),
        _HeaderLabel('TARGET'),
        _HeaderLabel('DESCRIPTION'),
        _HeaderLabel('VIEW'),
      ],
    ),
  );
}

class _AuditTableRow extends StatefulWidget {
  const _AuditTableRow({
    required this.entry,
    required this.date,
    required this.onView,
  });
  final AuditLogEntry entry;
  final String date;
  final VoidCallback onView;
  @override
  State<_AuditTableRow> createState() => _AuditTableRowState();
}

class _AuditTableRowState extends State<_AuditTableRow> {
  @override
  Widget build(BuildContext context) => AppTableRowHover(
    child: Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      color: Theme.of(context).cardColor,
      child: _AuditColumns(
        children: [
          Text(widget.date, maxLines: 2, overflow: TextOverflow.ellipsis),
          _PrimarySecondary(
            primary: widget.entry.actorName.isEmpty
                ? 'Unknown administrator'
                : widget.entry.actorName,
            secondary: widget.entry.actorRole,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _AuditActionBadge(entry: widget.entry),
          ),
          _Target(entry: widget.entry),
          Tooltip(
            message: widget.entry.description,
            child: Text(
              widget.entry.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton.filledTonal(
              key: ValueKey('audit-view-${widget.entry.id}'),
              tooltip: 'View details',
              onPressed: widget.onView,
              icon: const Icon(LucideIcons.eye, size: 18),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuditColumns extends StatelessWidget {
  const _AuditColumns({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < children.length; index++)
        Expanded(
          flex: const [2, 2, 3, 2, 4, 1][index],
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: children[index],
          ),
        ),
    ],
  );
}

class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF87A7FF)
          : const Color(0xFF5A77B8),
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .35,
    ),
  );
}

class _AuditCompactRow extends StatelessWidget {
  const _AuditCompactRow({
    required this.entry,
    required this.date,
    required this.onView,
  });
  final AuditLogEntry entry;
  final String date;
  final VoidCallback onView;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _AuditActionBadge(entry: entry),
                ),
              ),
              IconButton.filledTonal(
                key: ValueKey('audit-view-${entry.id}'),
                tooltip: 'View details',
                onPressed: onView,
                icon: const Icon(LucideIcons.eye, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _PrimarySecondary(
            primary: entry.actorName,
            secondary: entry.actorRole,
          ),
          const SizedBox(height: 8),
          _Target(entry: entry),
          const SizedBox(height: 8),
          Text(entry.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(date, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _AuditActionBadge extends StatelessWidget {
  const _AuditActionBadge({required this.entry});
  final AuditLogEntry entry;
  @override
  Widget build(BuildContext context) {
    final value = entry.action.toLowerCase();
    final color =
        value.contains('reject') ||
            value.contains('delete') ||
            value.contains('block')
        ? const Color(0xFFDC2626)
        : value.contains('document') || value.contains('statuschanged')
        ? const Color(0xFFD97706)
        : value.contains('approve') || value.contains('updated')
        ? const Color(0xFF059669)
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        entry.actionDisplayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Target extends StatelessWidget {
  const _Target({required this.entry});
  final AuditLogEntry entry;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: entry.entityId,
    child: _PrimarySecondary(
      primary: _displayValue(entry.entityType),
      secondary: _shortId(entry.entityId),
    ),
  );
}

class _PrimarySecondary extends StatelessWidget {
  const _PrimarySecondary({required this.primary, required this.secondary});
  final String primary, secondary;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        primary.isEmpty ? 'Not available' : primary,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      if (secondary.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(
          secondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    ],
  );
}

class _AuditLogDetailsDialog extends StatelessWidget {
  const _AuditLogDetailsDialog({
    required this.entry,
    required this.formattedDate,
  });
  final AuditLogEntry entry;
  final String formattedDate;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(24),
    child: Container(
      width: 720,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - 48,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.scrollText,
                    size: 19,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Log Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$formattedDate · ${entry.actionDisplayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border(context)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AuditActionBadge(entry: entry),
                  ),
                  const SizedBox(height: 18),
                  _DetailSection(
                    title: 'ACTOR & ACTION',
                    values: [
                      ('Admin', entry.actorName),
                      ('Role', entry.actorRole),
                      ('Action', entry.actionDisplayName),
                      ('Timestamp', formattedDate),
                    ],
                  ),
                  _DetailSection(
                    title: 'TARGET',
                    values: [
                      ('Entity type', _displayValue(entry.entityType)),
                      ('Entity ID', entry.entityId),
                    ],
                  ),
                  _TextSurface(title: 'DESCRIPTION', text: entry.description),
                  if (_present(entry.reason))
                    _TextSurface(
                      title: 'REASON',
                      text: entry.reason!,
                      warning: true,
                    ),
                  if (_present(entry.oldValue) || _present(entry.newValue))
                    _Changes(
                      oldValue: entry.oldValue,
                      newValue: entry.newValue,
                    ),
                  if (_present(entry.correlationId))
                    _TextSurface(
                      title: 'TECHNICAL DETAILS',
                      text: 'Correlation ID: ${entry.correlationId}',
                      subdued: true,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.values});
  final String title;
  final List<(String, String)> values;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 520
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: values
                  .where((value) => value.$2.trim().isNotEmpty)
                  .map(
                    (value) => Container(
                      width: width,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _PrimarySecondary(
                        primary: value.$2,
                        secondary: value.$1,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );
}

class _TextSurface extends StatelessWidget {
  const _TextSurface({
    required this.title,
    required this.text,
    this.warning = false,
    this.subdued = false,
  });
  final String title, text;
  final bool warning, subdued;
  @override
  Widget build(BuildContext context) {
    final color = warning
        ? const Color(0xFFD97706)
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: subdued
                  ? Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withValues(alpha: .3)
                  : color.withValues(alpha: .075),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: subdued
                    ? Theme.of(context).textTheme.bodySmall?.color
                    : null,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Changes extends StatelessWidget {
  const _Changes({required this.oldValue, required this.newValue});
  final String? oldValue, newValue;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('CHANGES'),
        const SizedBox(height: 9),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_present(oldValue))
              _ChangeValue(label: 'Previous', value: oldValue!),
            if (_present(oldValue) && _present(newValue))
              const Icon(LucideIcons.arrowRight, size: 18),
            if (_present(newValue))
              _ChangeValue(label: 'New', value: newValue!),
          ],
        ),
      ],
    ),
  );
}

class _ChangeValue extends StatelessWidget {
  const _ChangeValue({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(10),
    ),
    child: _PrimarySecondary(primary: value, secondary: label),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(
    value,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .55,
    ),
  );
}

bool _present(String? value) => value?.trim().isNotEmpty == true;
String _shortId(String value) =>
    value.length <= 14 ? value : '${value.substring(0, 12)}…';
String _displayValue(String value) {
  const known = {
    'CardRequest': 'Card Request',
    'LoanApplication': 'Loan Application',
    'AdminSettings': 'Settings',
    'AdminProfile': 'Admin Profile',
  };
  return known[value] ??
      value.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');
}

Color _border(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF303244)
    : AppTheme.border;
