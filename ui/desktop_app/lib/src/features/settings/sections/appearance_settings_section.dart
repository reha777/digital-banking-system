import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../admin_settings_models.dart';
import '../widgets/settings_section_card.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final AdminPreferences value;
  final ValueChanged<AdminPreferences> onChanged;
  AdminPreferences _copy({String? theme, String? sidebar}) => AdminPreferences(
    themeMode: theme ?? value.themeMode,
    sidebarStyle: sidebar ?? value.sidebarStyle,
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
        final width = constraints.maxWidth >= 780
            ? (constraints.maxWidth - 32) / 3
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
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'light',
                        icon: Icon(LucideIcons.sun, size: 17),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        icon: Icon(LucideIcons.moon, size: 17),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: 'system',
                        icon: Icon(LucideIcons.monitor, size: 17),
                        label: Text('System'),
                      ),
                    ],
                    selected: {value.themeMode},
                    onSelectionChanged: (selection) =>
                        onChanged(_copy(theme: selection.first)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sidebar Style'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'compact',
                        icon: Icon(LucideIcons.panelLeftClose, size: 17),
                        label: Text('Compact'),
                      ),
                      ButtonSegment(
                        value: 'expanded',
                        icon: Icon(LucideIcons.panelLeftOpen, size: 17),
                        label: Text('Expanded'),
                      ),
                    ],
                    selected: {value.sidebarStyle},
                    onSelectionChanged: (selection) =>
                        onChanged(_copy(sidebar: selection.first)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Primary Color'),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        SizedBox.square(
                          dimension: 30,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFF0066FF),
                              borderRadius: BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('#0066FF  Banking brand')),
                      ],
                    ),
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
