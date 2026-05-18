import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../dashboard/mobile_dashboard_screen.dart';
import 'auth_session.dart';
import 'register_screen.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'mobile@bankingapp.local');
  final _passwordController = TextEditingController(text: 'test');
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
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 54),
            Text('Sign In', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 28),
            AuthTextField(
              controller: _emailController,
              label: 'Email Address',
              iconAsset: 'assets/icons/auth/email.png',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              iconAsset: 'assets/icons/auth/password.png',
              obscureText: !_isPasswordVisible,
              suffix: AuthPasswordVisibilityButton(
                isVisible: _isPasswordVisible,
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              ),
              validator: _validatePassword,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              AuthErrorText(message: _errorMessage!),
            ],
            const SizedBox(height: 40),
            AuthPrimaryButton(
              label: 'Sign In',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 22),
            AuthSwitchPrompt(
              text: "I'm a new user.",
              displayActionText: 'Sign Up',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => RegisterScreen(session: widget.session),
                  ),
                );
              },
            ),
          ],
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

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MobileDashboardScreen(session: widget.session),
        ),
      );
    } on ApiException catch (exception) {
      setState(() => _errorMessage = exception.message);
    } on SocketException {
      setState(
        () => _errorMessage =
            'API nije dostupan. Provjerite da backend radi i da je API_BASE_URL ispravan.',
      );
    } catch (_) {
      setState(() => _errorMessage = 'Doslo je do greske prilikom prijave.');
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
      return 'Unesite validnu email adresu, npr. name@example.com.';
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
