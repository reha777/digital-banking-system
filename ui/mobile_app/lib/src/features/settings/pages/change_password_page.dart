import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../widgets/settings_widgets.dart';

typedef ChangePasswordAction =
    Future<void> Function(String currentPassword, String newPassword);

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.onSubmit});

  final ChangePasswordAction? onSubmit;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final action = widget.onSubmit;
    if (action == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password changes are not yet supported by the mobile API.',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await action(_currentController.text, _newController.text);
      if (!mounted) return;
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Password could not be changed. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const SettingsHeader(title: 'Change Password'),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _PasswordField(
                    key: const ValueKey('current-password'),
                    label: 'Current Password',
                    controller: _currentController,
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    key: const ValueKey('new-password'),
                    label: 'New Password',
                    controller: _newController,
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    key: const ValueKey('confirm-password'),
                    label: 'Confirm New Password',
                    controller: _confirmController,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (value != _newController.text) {
                        return 'Passwords must match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    key: const ValueKey('change-password-submit'),
                    onPressed: _submitting ? null : _submit,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _submitting
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Change Password'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    autofillHints: const [AutofillHints.password],
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
    validator:
        widget.validator ??
        (value) => value == null || value.isEmpty ? 'Required' : null,
  );
}
