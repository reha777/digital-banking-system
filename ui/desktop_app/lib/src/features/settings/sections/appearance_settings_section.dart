import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../admin_settings_models.dart';
import '../widgets/settings_section_card.dart';
import '../../../widgets/app_segmented_control.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final AdminPreferences value;
  final ValueChanged<AdminPreferences> onChanged;
  AdminPreferences _copy({String? theme}) => AdminPreferences(
    themeMode: theme ?? value.themeMode,
    sidebarStyle: value.sidebarStyle,
    dateFormat: value.dateFormat,
    timeFormat: value.timeFormat,
    firstDayOfWeek: value.firstDayOfWeek,
    numberFormat: value.numberFormat,
    defaultItemsPerPage: value.defaultItemsPerPage,
    timezone: value.timezone,
  );
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    title: 'Appearance',
    subtitle: 'Customize the look and feel of the admin panel.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 620
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 20,
          children: [
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Mode'),
                  const SizedBox(height: 8),
                  AppSegmentedControl<String>(
                    segments: const [
                      AppSegment(
                        value: 'light',
                        icon: LucideIcons.sun,
                        label: 'Light',
                      ),
                      AppSegment(
                        value: 'dark',
                        icon: LucideIcons.moon,
                        label: 'Dark',
                      ),
                      AppSegment(
                        value: 'system',
                        icon: LucideIcons.monitor,
                        label: 'System',
                      ),
                    ],
                    value: value.themeMode,
                    onChanged: (selection) =>
                        onChanged(_copy(theme: selection)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
