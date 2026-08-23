import 'package:flutter/material.dart';
import '../widgets/settings_section_card.dart';
import '../settings_validation.dart';
import '../../../widgets/app_dropdown_field.dart';

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
                validator: SettingsValidation.timeout,
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
                validator: (value) =>
                    SettingsValidation.warning(value, controllers[6].text),
              ),
            ),
            SizedBox(
              width: width,
              child: AppDropdownField<int>(
                value: itemsPerPage,
                label: 'Items Per Page (Default)',
                items: const [
                  AppDropdownItem(value: 10, label: '10'),
                  AppDropdownItem(value: 20, label: '20'),
                  AppDropdownItem(value: 50, label: '50'),
                ],
                onChanged: onItemsChanged,
              ),
            ),
          ],
        );
      },
    ),
  );
}
