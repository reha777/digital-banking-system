import 'package:flutter/material.dart';

import '../widgets/settings_widgets.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: '1. Information We Collect',
      body:
          'The application may process your name, email address, phone number, profile photo, account and card information, transaction and payment history, card and loan applications, uploaded documents, notifications, security activity, and technical information required for authentication and application security.',
    ),
    (
      title: '2. How We Use Your Information',
      body:
          'We use your information to authenticate your identity, manage your profile, accounts and cards, process transfers and payments, process card and loan applications, display transaction history and statistics, deliver notifications, prevent unauthorized access, and maintain financial and audit records.',
    ),
    (
      title: '3. Data Security',
      body:
          'Reasonable technical measures are used to protect your information. Passwords are not stored as readable text. Access to protected features requires authentication, and administrative operations are restricted by user roles. No method of electronic storage or transmission is completely secure, so absolute security cannot be guaranteed.',
    ),
    (
      title: '4. Biometric Authentication',
      body:
          'If biometric authentication is enabled, fingerprint or facial recognition is handled by your device’s operating system. BankPick does not receive or store your biometric data.',
    ),
    (
      title: '5. Notifications',
      body:
          'The application may provide notifications related to transactions, transfers, card requests, requested documents, loan applications, repayments, account activity, and security events.',
    ),
    (
      title: '6. Data Sharing',
      body:
          'Your personal information is not sold. Information is used only for application functionality, security, administration, and academic demonstration requirements. Data may be disclosed when required by law or when necessary to protect the security and integrity of the system.',
    ),
    (
      title: '7. Data Retention',
      body:
          'Information is retained while your account is active and for as long as necessary to maintain financial, security, and audit records. Some records may need to remain stored after account deactivation.',
    ),
    (
      title: '8. Your Rights',
      body:
          'Depending on applicable rules, you may request to view or correct your personal information, change your password, update your profile, or deactivate your account. Financial transactions and audit records may be retained when required for security, integrity, or legal reasons.',
    ),
    (
      title: '9. Third-Party Services',
      body:
          'Some features may depend on operating-system or external services, such as biometric authentication and email delivery. Those services may process information according to their own privacy policies.',
    ),
    (
      title: '10. Children’s Privacy',
      body:
          'This application is not intended for children and does not knowingly collect personal information from children.',
    ),
    (
      title: '11. Changes to This Policy',
      body:
          'This Privacy Policy may be updated when application functionality or data-processing practices change. The latest revision date will be displayed on this page.',
    ),
    (
      title: '12. Contact',
      body:
          'For questions about this Privacy Policy or your information, contact support@bankingapp.local.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            const SettingsHeader(title: 'Privacy Policy'),
            const SizedBox(height: 28),
            Text(
              'Last updated: August 26, 2026',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Text(
              'BankPick respects your privacy. This Privacy Policy explains how information is collected, used, stored, and protected when you use the mobile application.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 26),
            for (final section in _sections) ...[
              Text(
                section.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.55),
              ),
              const SizedBox(height: 24),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Educational Demo Notice',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'BankPick is an academic demonstration project and does not represent a real bank or financial institution. Do not enter real card numbers, banking credentials, passwords, identification documents, or other sensitive personal information.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
