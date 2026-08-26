import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/theme_controller.dart';
import '../admin_shell/admin_shell_screen.dart';
import '../settings/admin_settings_controller.dart';
import 'auth_session.dart';
import 'widgets/admin_auth_widgets.dart';
import 'admin_password_reset_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.session,
    required this.themeController,
    required this.settingsController,
  });

  final AuthSession session;
  final ThemeController themeController;
  final AdminSettingsController settingsController;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(34),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF303244) : AppTheme.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/bankpick_logo.png',
                    width: 66,
                    height: 66,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Admin Sign In',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Desktop access is restricted to administrators.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 30),
                  AdminAuthField(
                    controller: _emailController,
                    label: 'Email Address',
                    iconAsset: 'assets/icons/auth/email.png',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 18),
                  AdminAuthField(
                    controller: _passwordController,
                    label: 'Password',
                    iconAsset: 'assets/icons/auth/password.png',
                    obscureText: !_isPasswordVisible,
                    validator: _validatePassword,
                    suffix: IconButton(
                      onPressed: () {
                        setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        );
                      },
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      tooltip: _isPasswordVisible
                          ? 'Hide password'
                          : 'Show password',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AdminErrorText(message: _errorMessage!),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminPasswordResetScreen(),
                        ),
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AdminPrimaryButton(
                    label: 'Sign In',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.session.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await widget.settingsController.load(widget.session.token!);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminShellScreen(
            session: widget.session,
            themeController: widget.themeController,
            settingsController: widget.settingsController,
          ),
        ),
      );
    } on ApiException catch (exception) {
      setState(() => _errorMessage = exception.message);
    } catch (_) {
      setState(
        () => _errorMessage =
            'API nije dostupan. Provjerite da backend radi i da je API_BASE_URL ispravan.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Unesite email adresu.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Unesite validnu email adresu, npr. admin@example.com.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Unesite lozinku.';
    }
    return null;
  }
}
