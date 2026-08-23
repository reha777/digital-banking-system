import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../widgets/app_dropdown_field.dart';

enum SettingsSection { general, profile, security }

class SettingsNavigation extends StatelessWidget {
  const SettingsNavigation({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });
  final SettingsSection value;
  final ValueChanged<SettingsSection> onChanged;
  final bool compact;
  static const items = <(SettingsSection, IconData, String, String)>[
    (
      SettingsSection.general,
      LucideIcons.settings,
      'General',
      'System information',
    ),
    (
      SettingsSection.profile,
      LucideIcons.user,
      'Profile',
      'Administrator profile',
    ),
    (
      SettingsSection.security,
      LucideIcons.shieldCheck,
      'Security',
      'Change password',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return AppDropdownField<SettingsSection>(
        value: value,
        label: 'Settings section',
        items: items
            .map(
              (item) => AppDropdownItem(
                value: item.$1,
                icon: item.$2,
                label: item.$3,
              ),
            )
            .toList(),
        onChanged: onChanged,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [for (final item in items) _item(context, item)],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    (SettingsSection, IconData, String, String) item,
  ) {
    final active = item.$1 == value;
    return ListTile(
      selected: active,
      selectedColor: Theme.of(context).colorScheme.primary,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(item.$2, size: 20),
      title: Text(item.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(item.$4, style: const TextStyle(fontSize: 11)),
      onTap: () => onChanged(item.$1),
    );
  }
}
