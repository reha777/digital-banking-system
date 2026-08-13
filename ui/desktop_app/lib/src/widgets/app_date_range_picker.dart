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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 270),
          child: OutlinedButton.icon(
            onPressed: enabled ? () => _open(context) : null,
            icon: const Icon(LucideIcons.calendarRange, size: 18),
            label: Text(
              hasRange
                  ? '${_format(dateFrom!)} - ${_format(dateTo!)}'
                  : 'Select date range',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (hasRange) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: enabled ? onClear : null,
            tooltip: 'Clear date range',
            icon: const Icon(LucideIcons.x, size: 17),
          ),
        ],
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<_RangeResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CalendarRangeDialog(
        initialStart: dateFrom,
        initialEnd: dateTo,
        firstDate: DateUtils.dateOnly(firstDate ?? DateTime(2020)),
        lastDate: DateUtils.dateOnly(lastDate ?? DateTime.now()),
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

class _CalendarRangeDialog extends StatefulWidget {
  const _CalendarRangeDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;
  @override
  State<_CalendarRangeDialog> createState() => _CalendarRangeDialogState();
}

class _CalendarRangeDialogState extends State<_CalendarRangeDialog> {
  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart == null
        ? null
        : DateUtils.dateOnly(widget.initialStart!);
    _end = widget.initialEnd == null
        ? null
        : DateUtils.dateOnly(widget.initialEnd!);
    final anchor = _start ?? DateUtils.dateOnly(DateTime.now());
    final bounded = anchor.isBefore(widget.firstDate)
        ? widget.firstDate
        : anchor.isAfter(widget.lastDate)
        ? widget.lastDate
        : anchor;
    _visibleMonth = DateTime(bounded.year, bounded.month);
  }

  bool get _canPrevious => DateTime(
    _visibleMonth.year,
    _visibleMonth.month - 1,
    1,
  ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month - 1, 1));
  bool get _canNext => DateTime(
    _visibleMonth.year,
    _visibleMonth.month + 1,
    1,
  ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month + 1, 1));

  void _select(DateTime date) {
    if (date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate)) {
      return;
    }
    setState(() {
      if (_start == null || _end != null) {
        _start = date;
        _end = null;
      } else if (date.isBefore(_start!)) {
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: size.height - 40),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 20,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                color: AppTheme.primary,
                padding: const EdgeInsets.fromLTRB(24, 20, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.calendarRange,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'SELECT DATES',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Close',
                          icon: const Icon(LucideIcons.x, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Text(
                        _rangeLabel(),
                        key: ValueKey('$_start-$_end'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _monthLabel(_visibleMonth),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: _canPrevious
                                ? () => setState(
                                    () => _visibleMonth = DateTime(
                                      _visibleMonth.year,
                                      _visibleMonth.month - 1,
                                    ),
                                  )
                                : null,
                            tooltip: 'Previous month',
                            icon: const Icon(LucideIcons.chevronLeft),
                          ),
                          IconButton(
                            onPressed: _canNext
                                ? () => setState(
                                    () => _visibleMonth = DateTime(
                                      _visibleMonth.year,
                                      _visibleMonth.month + 1,
                                    ),
                                  )
                                : null,
                            tooltip: 'Next month',
                            icon: const Icon(LucideIcons.chevronRight),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                            Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _MonthGrid(
                        month: _visibleMonth,
                        start: _start,
                        end: _end,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        onSelect: _select,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, const _RangeResult.clear()),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _start != null && _end != null
                          ? () => Navigator.pop(
                              context,
                              _RangeResult.range(
                                DateTimeRange(start: _start!, end: _end!),
                              ),
                            )
                          : null,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _rangeLabel() => _start == null
      ? 'Start date - End date'
      : _end == null
      ? '${_format(_start!)} - End date'
      : '${_format(_start!)} - ${_format(_end!)}';
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
    required this.onSelect,
  });
  final DateTime month;
  final DateTime? start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 44,
      ),
      itemCount: 42,
      itemBuilder: (_, index) {
        final number = index - leading + 1;
        if (number < 1 || number > days) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, number);
        final disabled = date.isBefore(firstDate) || date.isAfter(lastDate);
        final selected = _same(date, start) || _same(date, end);
        final within =
            start != null &&
            end != null &&
            date.isAfter(start!) &&
            date.isBefore(end!);
        final today = _same(date, DateUtils.dateOnly(DateTime.now()));
        return Center(
          child: InkWell(
            onTap: disabled ? null : () => onSelect(date),
            borderRadius: BorderRadius.circular(22),
            hoverColor: AppTheme.primary.withValues(alpha: .08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary
                    : within
                    ? AppTheme.primary.withValues(alpha: .12)
                    : null,
                shape: BoxShape.circle,
                border: today && !selected
                    ? Border.all(color: AppTheme.primary)
                    : null,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  color: disabled
                      ? Theme.of(context).disabledColor
                      : selected
                      ? Colors.white
                      : null,
                  fontWeight: selected || today
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RangeResult {
  const _RangeResult.range(this.range) : clear = false;
  const _RangeResult.clear() : range = null, clear = true;
  final DateTimeRange? range;
  final bool clear;
}

bool _same(DateTime value, DateTime? other) =>
    other != null &&
    value.year == other.year &&
    value.month == other.month &&
    value.day == other.day;

String _monthLabel(DateTime value) {
  const months = [
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
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _format(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
