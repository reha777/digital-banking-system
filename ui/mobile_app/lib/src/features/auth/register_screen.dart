import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme_controller.dart';
import '../dashboard/mobile_dashboard_screen.dart';
import 'auth_session.dart';
import 'login_screen.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.session,
    required this.themeController,
  });

  final AuthSession session;
  final ThemeController themeController;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
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
            Text('Sign Up', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 28),
            AuthTextField(
              controller: _fullNameController,
              label: 'Full Name',
              iconAsset: 'assets/icons/auth/email.png',
              textInputAction: TextInputAction.next,
              validator: _validateFullName,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _phoneController,
              label: 'Phone Number',
              iconAsset: 'assets/icons/auth/phone.png',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator: _validatePhoneNumber,
            ),
            const SizedBox(height: 16),
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
              label: 'Sign Up',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 22),
            AuthSwitchPrompt(
              text: 'Already have an account.',
              displayActionText: 'Sign In',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => LoginScreen(
                      session: widget.session,
                      themeController: widget.themeController,
                    ),
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

    final nameParts = _fullNameController.text.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '-';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.session.register(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MobileDashboardScreen(
            session: widget.session,
            themeController: widget.themeController,
          ),
        ),
      );
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = exception.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
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

  String? _validateFullName(String? value) {
    final fullName = value?.trim() ?? '';
    if (fullName.isEmpty) {
      return 'Unesite ime i prezime.';
    }
    if (!fullName.contains(' ')) {
      return 'Unesite ime i prezime odvojeno razmakom.';
    }
    return null;
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

  String? _validatePhoneNumber(String? value) {
    final phoneNumber = value?.trim() ?? '';
    if (phoneNumber.isEmpty) {
      return 'Unesite broj telefona.';
    }
    if (!RegExp(r'^\+?[0-9 ]{7,20}$').hasMatch(phoneNumber)) {
      return 'Unesite validan broj telefona u formatu: +38761234567.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 6) {
      return 'Lozinka mora imati najmanje 6 karaktera.';
    }
    return null;
  }
}
