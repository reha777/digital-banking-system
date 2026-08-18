import 'package:flutter/material.dart';

import '../settings_service.dart';
import '../widgets/settings_widgets.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final CustomerProfile profile;
  final Future<CustomerProfile> Function({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  })
  onSave;

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.profile.firstName);
  late final _lastName = TextEditingController(text: widget.profile.lastName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber);
  late CustomerProfile _savedProfile = widget.profile;
  bool _saving = false;

  bool get _dirty =>
      _firstName.text.trim() != _savedProfile.firstName ||
      _lastName.text.trim() != _savedProfile.lastName ||
      _phone.text.trim() != _savedProfile.phoneNumber;

  @override
  void initState() {
    super.initState();
    for (final controller in [_firstName, _lastName, _phone]) {
      controller.addListener(_fieldChanged);
    }
  }

  void _fieldChanged() => setState(() {});

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_dirty || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.onSave(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phoneNumber: _phone.text,
      );
      if (!mounted) return;
      _savedProfile = updated;
      _firstName.text = updated.firstName;
      _lastName.text = updated.lastName;
      _phone.text = updated.phoneNumber;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile could not be updated. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const SettingsHeader(title: 'Personal Information'),
          const SizedBox(height: 28),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _ProfileField(
                  key: const ValueKey('profile-first-name'),
                  label: 'First Name',
                  controller: _firstName,
                ),
                _ProfileField(
                  key: const ValueKey('profile-last-name'),
                  label: 'Last Name',
                  controller: _lastName,
                ),
                TextFormField(
                  initialValue: widget.profile.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText: 'Email changes require a verification flow.',
                  ),
                ),
                _ProfileField(
                  key: const ValueKey('profile-phone'),
                  label: 'Phone Number',
                  controller: _phone,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  key: const ValueKey('profile-save'),
                  onPressed: _dirty && !_saving ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    super.key,
    required this.label,
    required this.controller,
  });
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return 'Required';
      if (text.length > (label == 'Phone Number' ? 30 : 100)) {
        return 'Value is too long';
      }
      return null;
    },
  );
}
