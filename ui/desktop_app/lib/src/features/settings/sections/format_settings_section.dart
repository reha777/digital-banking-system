import 'package:flutter/material.dart';
import '../admin_settings_models.dart';
import '../widgets/settings_section_card.dart';
import '../../../widgets/app_dropdown_field.dart';

class FormatSettingsSection extends StatelessWidget {
  const FormatSettingsSection({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final AdminPreferences value;
  final ValueChanged<AdminPreferences> onChanged;
  AdminPreferences _copy({
    String? date,
    String? time,
    String? week,
    String? number,
    int? rows,
  }) => AdminPreferences(
    themeMode: value.themeMode,
    sidebarStyle: value.sidebarStyle,
    dateFormat: date ?? value.dateFormat,
    timeFormat: time ?? value.timeFormat,
    firstDayOfWeek: week ?? value.firstDayOfWeek,
    numberFormat: number ?? value.numberFormat,
    defaultItemsPerPage: rows ?? value.defaultItemsPerPage,
    timezone: value.timezone,
  );
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    title: 'Date & Number Format',
    subtitle: 'Configure how dates and numbers are displayed.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _dropdown(width, 'Date Format', value.dateFormat, const [
              'DD.MM.YYYY',
              'DD/MM/YYYY',
              'MM/DD/YYYY',
              'YYYY-MM-DD',
            ], (v) => onChanged(_copy(date: v))),
            _dropdown(width, 'Time Format', value.timeFormat, const [
              '24h',
              '12h',
            ], (v) => onChanged(_copy(time: v))),
            _dropdown(
              width,
              'Number Format',
              value.numberFormat,
              const ['1,234.56', '1.234,56'],
              (v) => onChanged(_copy(number: v)),
            ),
          ],
        );
      },
    ),
  );
  Widget _dropdown(
    double width,
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: width,
    child: AppDropdownField<String>(
      value: value,
      label: label,
      items: values.map((v) => AppDropdownItem(value: v, label: v)).toList(),
      onChanged: changed,
    ),
  );
}
