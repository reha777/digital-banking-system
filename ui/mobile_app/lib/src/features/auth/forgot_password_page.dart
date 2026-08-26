import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'password_reset_service.dart';
import 'reset_password_page.dart';
import 'widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.service});
  final PasswordResetService? service;
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _demoEnabled = bool.fromEnvironment(
    'DEMO_AUTH_ENABLED',
    defaultValue: kDebugMode,
  );
  final form = GlobalKey<FormState>(), email = TextEditingController();
  bool loading = false;
  String demoAccount = 'customer-primary';
  String? message, error;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const AuthBackButton(),
          const SizedBox(height: 30),
          Text(
            'Forgot password',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _demoEnabled
                ? 'Enter an email address where you want to receive the reset code.'
                : 'Enter your email address to receive reset instructions.',
          ),
          if (_demoEnabled) ...[
            const SizedBox(height: 8),
            const Text(
              'This demo sends the reset code to the email address you provide.',
            ),
          ],
          const SizedBox(height: 28),
          if (_demoEnabled) ...[
            DropdownButtonFormField<String>(
              initialValue: demoAccount,
              decoration: const InputDecoration(labelText: 'Demo account'),
              items: const [
                DropdownMenuItem(
                  value: 'customer-primary',
                  child: Text('Mobile Customer 1'),
                ),
                DropdownMenuItem(
                  value: 'customer-secondary',
                  child: Text('Mobile Customer 2'),
                ),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null) setState(() => demoAccount = value);
                    },
            ),
            const SizedBox(height: 14),
          ],
          AuthTextField(
            controller: email,
            label: 'Email Address',
            iconAsset: 'assets/icons/auth/email.png',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final x = v?.trim() ?? '';
              return x.contains('@') && x.contains('.')
                  ? null
                  : 'Enter a valid email address.';
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AuthErrorText(message: error!),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message!, key: const ValueKey('forgot-success')),
                  const SizedBox(height: 6),
                  const Text('Check your email for the reset code.'),
                ],
              ),
            ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Send reset instructions',
            isLoading: loading,
            onPressed: _submit,
          ),
          if (message != null)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ResetPasswordPage(
                    email: email.text.trim(),
                    demoAccount: _demoEnabled ? demoAccount : null,
                    service: widget.service,
                  ),
                ),
              ),
              child: const Text('Enter reset code'),
            ),
        ],
      ),
    ),
  );
  Future<void> _submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await (widget.service ?? PasswordResetService()).forgot(
        email.text.trim(),
        demoAccount: _demoEnabled ? demoAccount : null,
      );
      if (mounted) setState(() => message = value);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Unable to send reset instructions. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}
