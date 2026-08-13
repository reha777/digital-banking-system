import 'package:flutter/material.dart';
import '../widgets/settings_section_card.dart';

class SessionSettingsSection extends StatelessWidget {
  const SessionSettingsSection({
    super.key,
    required this.controllers,
    required this.itemsPerPage,
    required this.enableDataCaching,
    required this.onItemsChanged,
    required this.onCachingChanged,
    required this.onChanged,
  });
  final List<TextEditingController> controllers;
  final int itemsPerPage;
  final bool enableDataCaching;
  final ValueChanged<int> onItemsChanged;
  final ValueChanged<bool> onCachingChanged;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    title: 'Session & Performance',
    subtitle: 'Configure session timeout and performance settings.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width,
              child: TextFormField(
                controller: controllers[6],
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Session Timeout (minutes)',
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: TextFormField(
                controller: controllers[7],
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Auto Logout Warning (minutes)',
                ),
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<int>(
                initialValue: itemsPerPage,
                decoration: const InputDecoration(
                  labelText: 'Items Per Page (Default)',
                ),
                items: const [10, 20, 50]
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onItemsChanged(v);
                },
              ),
            ),
            SizedBox(
              width: width,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text(
                  'Enable Data Caching',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Cache frequently used data.',
                  style: TextStyle(fontSize: 11),
                ),
                value: enableDataCaching,
                onChanged: onCachingChanged,
              ),
            ),
          ],
        );
      },
    ),
  );
}
