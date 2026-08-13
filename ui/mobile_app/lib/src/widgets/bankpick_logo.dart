import 'package:flutter/material.dart';

class BankPickLogo extends StatelessWidget {
  const BankPickLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/bankpick_logo.png',
          width: 82,
          height: 82,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        Text(
          'BANKPICK',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            letterSpacing: 0,
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
      ],
    );
  }
}
