import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/settings_section_card.dart';

class SecuritySettingsSection extends StatefulWidget {
  const SecuritySettingsSection({
    super.key,
    required this.controllers,
    required this.saving,
    required this.onSubmit,
    required this.onChanged,
  });
  final List<TextEditingController> controllers;
  final bool saving;
  final Future<void> Function() onSubmit;
  final VoidCallback onChanged;
  @override
  State<SecuritySettingsSection> createState() =>
      _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends State<SecuritySettingsSection> {
  final _formKey = GlobalKey<FormState>();
  final _visible = [false, false, false];
  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: SettingsSectionCard(
      title: 'Change Password',
      subtitle: 'Use at least 8 characters and confirm the new password.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 840
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _field('Current Password', 0, width),
                  _field('New Password', 1, width),
                  _field('Confirm Password', 2, width),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: widget.saving
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) widget.onSubmit();
                    },
              icon: widget.saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.keyRound, size: 17),
              label: Text(widget.saving ? 'Changing...' : 'Change Password'),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _field(String label, int index, double width) => SizedBox(
    width: width,
    child: TextFormField(
      controller: widget.controllers[index],
      onChanged: (_) => widget.onChanged(),
      obscureText: !_visible[index],
      validator: (value) {
        if ((value ?? '').isEmpty) {
          return 'Required';
        }
        if (index > 0 && value!.length < 8) {
          return 'Use at least 8 characters';
        }
        if (index == 2 && value != widget.controllers[1].text) {
          return 'Passwords do not match';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: _visible[index] ? 'Hide password' : 'Show password',
          onPressed: () => setState(() => _visible[index] = !_visible[index]),
          icon: Icon(
            _visible[index] ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 18,
          ),
        ),
      ),
    ),
  );
}
