import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class SendMoneyAmountField extends StatelessWidget {
  const SendMoneyAmountField({
    super.key,
    required this.currency,
    required this.controller,
    required this.availableBalance,
    required this.onChangeCurrency,
    this.debitAmount,
  });
  final String currency;
  final TextEditingController controller;
  final double availableBalance;
  final double? debitAmount;
  final VoidCallback onChangeCurrency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1C2B) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Enter Your Amount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              InkWell(
                key: const ValueKey('change-currency'),
                onTap: onChangeCurrency,
                child: Text(
                  'Change Currency?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFFF3D71),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextFormField(
            key: const ValueKey('send-amount'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '$currency  ',
              hintText: '0.00',
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 10),
              prefixStyle: TextStyle(
                color: isDark ? const Color(0xFF9FB1D2) : AppTheme.textDark,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : AppTheme.textMuted,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            validator: (value) {
              final amount = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );
              if (amount == null) return 'Enter a valid amount.';
              if (amount <= 0) return 'Amount must be greater than zero.';
              if ((debitAmount ?? amount) > availableBalance) {
                return 'Insufficient balance.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
