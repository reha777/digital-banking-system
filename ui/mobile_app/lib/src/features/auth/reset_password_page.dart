import 'package:flutter/material.dart';
import 'password_reset_service.dart';
import 'widgets/auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.email,
    this.demoAccount,
    this.service,
  });
  final String email;
  final String? demoAccount;
  final PasswordResetService? service;
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final form = GlobalKey<FormState>(),
      token = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool loading = false, visible = false, resending = false;
  String? error, resendMessage;
  bool done = false;
  @override
  void dispose() {
    token.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 36),
          const AuthBackButton(),
          const SizedBox(height: 24),
          Text('Reset password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Check your email for the reset code.'),
          const SizedBox(height: 24),
          AuthTextField(
            controller: token,
            label: 'Reset code',
            iconAsset: 'assets/icons/auth/password.png',
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Enter the reset code.' : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: password,
            label: 'New Password',
            iconAsset: 'assets/icons/auth/password.png',
            obscureText: !visible,
            suffix: AuthPasswordVisibilityButton(
              isVisible: visible,
              onPressed: () => setState(() => visible = !visible),
            ),
            validator: (v) => (v?.length ?? 0) < 6
                ? 'Password must contain at least 6 characters.'
                : null,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: confirm,
            label: 'Confirm Password',
            iconAsset: 'assets/icons/auth/password.png',
            obscureText: !visible,
            validator: (v) =>
                v != password.text ? 'Passwords do not match.' : null,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AuthErrorText(message: error!),
            ),
          if (done)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Password successfully reset.',
                key: ValueKey('reset-success'),
              ),
            ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: done ? 'Back to Login' : 'Reset password',
            isLoading: loading,
            onPressed: done
                ? () => Navigator.popUntil(context, (route) => route.isFirst)
                : _submit,
          ),
          if (!done)
            TextButton(
              onPressed: resending ? null : _resend,
              child: Text(resending ? 'Sending...' : 'Resend code'),
            ),
          if (resendMessage != null)
            Text(resendMessage!, textAlign: TextAlign.center),
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
      await (widget.service ?? PasswordResetService()).reset(
        token.text.trim(),
        password.text,
      );
      if (mounted) setState(() => done = true);
    } catch (_) {
      if (mounted) setState(() => error = 'Reset code is invalid or expired.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    if (resending) return;
    setState(() {
      resending = true;
      error = null;
      resendMessage = null;
    });
    try {
      final value = await (widget.service ?? PasswordResetService()).forgot(
        widget.email,
        demoAccount: widget.demoAccount,
      );
      if (mounted) setState(() => resendMessage = value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to resend the code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }
}
