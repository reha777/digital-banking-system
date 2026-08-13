import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../widgets/admin_modal.dart';
import '../admin_customer_models.dart';

class CustomerEditRequest {
  const CustomerEditRequest({
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
  });

  final String firstName;
  final String lastName;
  final String phoneNumber;
}

class CustomerEditDialog extends StatefulWidget {
  const CustomerEditDialog({super.key, required this.customer});

  final AdminCustomer customer;

  @override
  State<CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<CustomerEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.customer.firstName,
    );
    _lastNameController = TextEditingController(text: widget.customer.lastName);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    return value == null || value.trim().isEmpty
        ? 'This field is required.'
        : null;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop(
      CustomerEditRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AdminModal(
        title: 'Edit customer',
        primaryLabel: 'Save',
        onPrimary: _save,
        children: [
          AdminModalField(
            controller: _firstNameController,
            label: 'First name',
            icon: LucideIcons.user,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          AdminModalField(
            controller: _lastNameController,
            label: 'Last name',
            icon: LucideIcons.user,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 14),
          AdminModalField(
            controller: _phoneController,
            label: 'Phone number',
            icon: LucideIcons.phone,
            validator: _requiredValidator,
          ),
        ],
      ),
    );
  }
}
