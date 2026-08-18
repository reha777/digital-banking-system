import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api_client.dart';
import '../../../widgets/mobile_shell.dart';
import '../../auth/auth_session.dart';
import '../transaction_models.dart';
import '../transaction_service.dart';

class AddRecipientPage extends StatefulWidget {
  const AddRecipientPage({
    super.key,
    required this.session,
    required this.service,
    required this.sourceAccountNumber,
  });

  final AuthSession session;
  final TransactionService service;
  final String sourceAccountNumber;

  @override
  State<AddRecipientPage> createState() => _AddRecipientPageState();
}

class _AddRecipientPageState extends State<AddRecipientPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  RecentRecipient? _verified;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _accountController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    final token = widget.session.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _verified = null;
    });
    try {
      final recipient = await widget.service.lookupRecipient(
        token: token,
        accountNumber: _accountController.text,
      );
      if (!mounted) return;
      _firstNameController.text = recipient.firstName;
      _lastNameController.text = recipient.lastName;
      setState(() => _verified = recipient);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          children: [
            Row(
              children: [
                CircleIconButton(
                  icon: LucideIcons.arrowLeft,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'New Recipient',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 28),
            TextFormField(
              key: const ValueKey('recipient-account'),
              controller: _accountController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Account Number',
                prefixIcon: Icon(LucideIcons.landmark),
              ),
              onChanged: (_) => setState(() {
                _verified = null;
                _firstNameController.clear();
                _lastNameController.clear();
              }),
              validator: (value) {
                final number = value?.trim() ?? '';
                if (number.isEmpty) {
                  return 'Account number is required.';
                }
                if (number == widget.sourceAccountNumber) {
                  return 'You cannot send money to the source account.';
                }
                if (number.length > 34) {
                  return 'Account number is too long.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _firstNameController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'First Name',
                helperText: 'Verified by the bank',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastNameController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 28),
            ElevatedButton(
              key: const ValueKey('verify-recipient'),
              onPressed: _loading
                  ? null
                  : (_verified == null
                        ? _verify
                        : () => Navigator.of(context).pop(_verified)),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _verified == null ? 'Verify Recipient' : 'Use Recipient',
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
