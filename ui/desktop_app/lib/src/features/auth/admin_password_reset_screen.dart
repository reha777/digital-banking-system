import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/app_theme.dart';
import 'password_reset_service.dart';
import 'widgets/admin_auth_widgets.dart';

class AdminPasswordResetScreen extends StatefulWidget {
  const AdminPasswordResetScreen({super.key, this.service});
  final PasswordResetService? service;
  @override
  State<AdminPasswordResetScreen> createState() =>
      _AdminPasswordResetScreenState();
}

class _AdminPasswordResetScreenState extends State<AdminPasswordResetScreen> {
  static const _demoEnabled = bool.fromEnvironment(
    'DEMO_AUTH_ENABLED',
    defaultValue: kDebugMode,
  );
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final token = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool reset = false,
      loading = false,
      visible = false,
      completed = false,
      resending = false;
  String? message, error;

  @override
  void dispose() {
    email.dispose();
    token.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(34),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkSurface
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Text(
                    reset ? 'Reset password' : 'Forgot password',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reset
                        ? 'Check your email for the reset code.'
                        : _demoEnabled
                        ? 'Enter an email address where you want to receive the reset code.'
                        : 'Enter your email address to receive reset instructions.',
                  ),
                  if (!reset && _demoEnabled) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'This demo sends the reset code to the email address you provide.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!reset)
                    AdminAuthField(
                      controller: email,
                      label: 'Email Address',
                      iconAsset: 'assets/icons/auth/email.png',
                      validator: (value) =>
                          (value?.contains('@') ?? false) &&
                              (value?.contains('.') ?? false)
                          ? null
                          : 'Enter a valid email address.',
                    ),
                  if (reset) ...[
                    AdminAuthField(
                      controller: token,
                      label: 'Reset code',
                      iconAsset: 'assets/icons/auth/password.png',
                      validator: (value) => value?.trim().isEmpty ?? true
                          ? 'Enter the reset code.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    AdminAuthField(
                      controller: password,
                      label: 'New Password',
                      iconAsset: 'assets/icons/auth/password.png',
                      obscureText: !visible,
                      suffix: IconButton(
                        onPressed: () => setState(() => visible = !visible),
                        icon: Icon(
                          visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 6
                          ? 'Use at least 6 characters.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    AdminAuthField(
                      controller: confirm,
                      label: 'Confirm Password',
                      iconAsset: 'assets/icons/auth/password.png',
                      obscureText: !visible,
                      validator: (value) => value != password.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                  ],
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        message!,
                        key: const ValueKey('password-reset-message'),
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: AdminErrorText(message: error!),
                    ),
                  const SizedBox(height: 24),
                  AdminPrimaryButton(
                    label: completed
                        ? 'Back to Login'
                        : reset
                        ? 'Reset password'
                        : 'Send reset instructions',
                    isLoading: loading,
                    onPressed: completed
                        ? () => Navigator.pop(context)
                        : _submit,
                  ),
                  if (!reset && message != null)
                    TextButton(
                      onPressed: () => setState(() => reset = true),
                      child: const Text('Enter reset code'),
                    ),
                  if (reset && !completed)
                    TextButton(
                      onPressed: resending ? null : _resend,
                      child: Text(resending ? 'Sending...' : 'Resend code'),
                    ),
                ],
              ),
            ),
          ),
        ),
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
      final service = widget.service ?? PasswordResetService();
      if (reset) {
        await service.reset(token.text.trim(), password.text);
        if (mounted) {
          setState(() {
            completed = true;
            message = 'Password successfully reset.';
          });
        }
      } else {
        final value = await service.forgot(
          email.text.trim(),
          demoAccount: _demoEnabled ? 'admin' : null,
        );
        if (mounted) setState(() => message = value);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = reset
              ? 'Reset code is invalid or expired.'
              : 'Unable to send reset instructions. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _resend() async {
    if (resending) return;
    setState(() {
      resending = true;
      error = null;
    });
    try {
      final value = await (widget.service ?? PasswordResetService()).forgot(
        email.text.trim(),
        demoAccount: _demoEnabled ? 'admin' : null,
      );
      if (mounted) setState(() => message = value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Unable to resend the code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => resending = false);
    }
  }
}
