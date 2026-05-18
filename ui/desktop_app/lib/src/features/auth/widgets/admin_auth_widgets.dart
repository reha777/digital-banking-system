import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class AdminAuthField extends StatelessWidget {
  const AdminAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.iconAsset,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String iconAsset;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Image.asset(
            iconAsset,
            width: 18,
            height: 18,
            color: AppTheme.textMuted,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        suffixIcon: suffix,
      ),
    );
  }
}

class AdminPrimaryButton extends StatelessWidget {
  const AdminPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class AdminErrorText extends StatelessWidget {
  const AdminErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: AppTheme.error,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}
