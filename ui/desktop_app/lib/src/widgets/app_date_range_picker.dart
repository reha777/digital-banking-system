import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/app_theme.dart';

class AppDateRangePicker extends StatelessWidget {
  const AppDateRangePicker({
    super.key,
    required this.dateFrom,
    required this.dateTo,
    required this.onApply,
    required this.onClear,
    this.firstDate,
    this.lastDate,
    this.enabled = true,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<DateTimeRange> onApply;
  final VoidCallback onClear;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasRange = dateFrom != null && dateTo != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: OutlinedButton.icon(
        onPressed: enabled ? () => _open(context) : null,
        icon: const Icon(LucideIcons.calendarRange, size: 19),
        label: Expanded(
          child: Text(
            hasRange
                ? '${_formatDate(dateFrom!)} - ${_formatDate(dateTo!)}'
                : 'Select date range',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<_DateRangeResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DateRangePickerDialog(
        initialFrom: dateFrom,
        initialTo: dateTo,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? _today(),
      ),
    );

    if (result == null) return;
    if (result.clear) {
      onClear();
    } else if (result.range case final range?) {
      onApply(range);
    }
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  const _DateRangePickerDialog({
    required this.initialFrom,
    required this.initialTo,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime? initialFrom;
  final DateTime? initialTo;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _dateFrom = widget.initialFrom;
    _dateTo = widget.initialTo;
  }

  Future<void> _pickFrom() async {
    final selected = await _pickDate(
      initialDate: _dateFrom ?? _dateTo ?? widget.lastDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: 'ODABERITE DATUM OD',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _dateFrom = selected;
      if (_dateTo != null && _dateTo!.isBefore(selected)) {
        _dateTo = null;
      }
    });
  }

  Future<void> _pickTo() async {
    final from = _dateFrom;
    if (from == null) return;
    final selected = await _pickDate(
      initialDate: _dateTo != null && !_dateTo!.isBefore(from)
          ? _dateTo!
          : from,
      firstDate: from,
      lastDate: widget.lastDate,
      helpText: 'ODABERITE DATUM DO',
    );
    if (selected == null || !mounted) return;
    setState(() => _dateTo = selected);
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required String helpText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: 'ODUSTANI',
      confirmText: 'ODABERI',
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: Theme(
            data: Theme.of(context).copyWith(
              datePickerTheme: DatePickerThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
            ),
            child: child!,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canApply =
        _dateFrom != null && _dateTo != null && !_dateTo!.isBefore(_dateFrom!);
    final width = MediaQuery.sizeOf(context).width;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(width < 600 ? 18 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: const Icon(
                      LucideIcons.calendarRange,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Odaberite razdoblje',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Prvo odaberite početni, zatim završni datum.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x),
                    tooltip: 'Odustani',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    _DateSelectionField(
                      label: 'Datum od',
                      value: _dateFrom,
                      onPressed: _pickFrom,
                    ),
                    _DateSelectionField(
                      label: 'Datum do',
                      value: _dateTo,
                      onPressed: _dateFrom == null ? null : _pickTo,
                    ),
                  ];
                  if (constraints.maxWidth < 430) {
                    return Column(
                      children: [
                        fields.first,
                        const SizedBox(height: 12),
                        fields.last,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: fields.first),
                      const SizedBox(width: 12),
                      Expanded(child: fields.last),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                _dateFrom == null
                    ? 'Odaberite datum od prije završnog datuma.'
                    : _dateTo == null
                    ? 'Završni datum može biti ${_formatDate(_dateFrom!)} ili kasnije.'
                    : 'Uključeni su početni i završni datum.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _DateRangeResult.clear()),
                    child: const Text('Očisti'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Odustani'),
                  ),
                  FilledButton.icon(
                    onPressed: canApply
                        ? () => Navigator.of(context).pop(
                            _DateRangeResult.range(
                              DateTimeRange(start: _dateFrom!, end: _dateTo!),
                            ),
                          )
                        : null,
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Primijeni'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSelectionField extends StatelessWidget {
  const _DateSelectionField({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(LucideIcons.calendarDays),
          suffixIcon: const Icon(LucideIcons.chevronDown),
          enabled: onPressed != null,
        ),
        child: Text(value == null ? 'dd.mm.gggg' : _formatDate(value!)),
      ),
    );
  }
}

class _DateRangeResult {
  const _DateRangeResult.range(this.range) : clear = false;
  const _DateRangeResult.clear() : range = null, clear = true;

  final DateTimeRange? range;
  final bool clear;
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _formatDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.'
      '${value.year}.';
}
