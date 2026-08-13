import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class CardRequestForm extends StatelessWidget {
  const CardRequestForm({
    super.key,
    required this.formKey,
    required this.holderName,
    required this.selectedCurrency,
    required this.documentController,
    required this.addressController,
    required this.noteController,
    required this.isLoading,
    required this.errorMessage,
    required this.onCurrencyChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final String holderName;
  final String selectedCurrency;
  final TextEditingController documentController;
  final TextEditingController addressController;
  final TextEditingController noteController;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _RequestTextField(
            label: 'Cardholder Name',
            initialValue: holderName,
            icon: Icons.person_outline,
            readOnly: true,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedCurrency,
            decoration: const InputDecoration(
              labelText: 'Requested currency',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
            items: const ['USD', 'EUR', 'BAM']
                .map(
                  (currency) => DropdownMenuItem<String>(
                    value: currency,
                    child: Text(currency),
                  ),
                )
                .toList(),
            onChanged: (currency) {
              if (currency != null) {
                onCurrencyChanged(currency);
              }
            },
          ),
          const SizedBox(height: 14),
          _RequestTextField(
            controller: documentController,
            label: 'Document ID Number',
            icon: Icons.badge_outlined,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          _RequestTextField(
            controller: addressController,
            label: 'Delivery Address',
            icon: Icons.location_on_outlined,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          _RequestTextField(
            controller: noteController,
            label: 'Request Note',
            icon: Icons.notes_outlined,
            maxLines: 2,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send Request'),
          ),
        ],
      ),
    );
  }
}

class _RequestTextField extends StatelessWidget {
  const _RequestTextField({
    required this.label,
    required this.icon,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final String? initialValue;
  final bool readOnly;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'This field is required.';
  }
  return null;
}
