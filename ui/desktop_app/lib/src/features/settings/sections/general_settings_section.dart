import 'package:flutter/material.dart';
import '../widgets/settings_section_card.dart';

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({
    super.key,
    required this.controllers,
    required this.onChanged,
  });
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    title: 'System Information',
    subtitle: 'Configure basic information about your banking system.',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var index = 0; index < 6; index++)
              SizedBox(
                width: width,
                child: TextFormField(
                  controller: controllers[index],
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: const [
                      'System Name',
                      'System Short Name',
                      'Company Name',
                      'Company Email',
                      'Company Phone',
                      'Timezone',
                    ][index],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
