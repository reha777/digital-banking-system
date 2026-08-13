import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/mobile_shell.dart';
import '../accounts/account_models.dart';
import '../auth/auth_session.dart';
import 'transaction_service.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({
    super.key,
    required this.session,
    required this.sourceAccount,
  });

  final AuthSession session;
  final Account sourceAccount;

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController(
    text: 'BA-000002-CHECKING',
  );
  final _amountController = TextEditingController(text: '36.00');
  final _descriptionController = TextEditingController(
    text: 'Mobile money transfer',
  );

  late final TransactionService _transactionService;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _transactionService = TransactionService(ApiClient());
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _sendMoney() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final token = widget.session.token;
    if (token == null) {
      setState(() {
        _errorMessage = 'Sesija je istekla. Prijavite se ponovo.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _transactionService.sendMoney(
        token: token,
        sourceAccountId: widget.sourceAccount.id,
        destinationAccountNumber: _destinationController.text.trim(),
        amount: double.parse(
          _amountController.text.trim().replaceAll(',', '.'),
        ),
        description: _descriptionController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transfer ${result.referenceNumber} je ${result.status}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (exception) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = exception.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      currentIndex: 0,
      onSelected: (_) {},
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.arrow_back_ios_new),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F6FA),
                      foregroundColor: AppTheme.textDark,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Send Money',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 28),
              _PaymentCard(account: widget.sourceAccount),
              const SizedBox(height: 24),
              _RecipientPanel(
                destinationController: _destinationController,
                descriptionController: _descriptionController,
              ),
              const SizedBox(height: 18),
              _AmountPanel(
                currency: widget.sourceAccount.currency,
                amountController: _amountController,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 72),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _sendMoney,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Money'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final tail = account.accountNumber.length > 4
        ? account.accountNumber.substring(account.accountNumber.length - 4)
        : account.accountNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF202349),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: Colors.white70),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            '****  ****  ****  $tail',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  account.accountNumber,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                '${account.currency} ${account.balance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipientPanel extends StatelessWidget {
  const _RecipientPanel({
    required this.destinationController,
    required this.descriptionController,
  });

  final TextEditingController destinationController;
  final TextEditingController descriptionController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.inputBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send to',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 15),
          ),
          TextFormField(
            controller: destinationController,
            decoration: const InputDecoration(
              labelText: 'Destination account number',
              prefixIcon: Icon(Icons.account_balance),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Unesite racun primaoca.';
              }
              return null;
            },
          ),
          TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({required this.currency, required this.amountController});

  final String currency;
  final TextEditingController amountController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.inputBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Enter Your Amount',
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: 14, left: 12, right: 10),
            child: Text(
              currency,
              style: const TextStyle(
                color: Color(0xFF8FA6CC),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 72),
        ),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        validator: (value) {
          final amount = double.tryParse(
            (value ?? '').trim().replaceAll(',', '.'),
          );
          if (amount == null) {
            return 'Unesite validan iznos.';
          }
          if (amount <= 0) {
            return 'Iznos mora biti veci od nule.';
          }
          return null;
        },
      ),
    );
  }
}
