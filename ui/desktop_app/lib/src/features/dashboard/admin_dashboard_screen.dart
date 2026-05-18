import 'package:flutter/material.dart';

import '../auth/admin_login_screen.dart';
import '../auth/auth_session.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final user = session.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BankPick Admin'),
        actions: [
          IconButton(
            onPressed: () {
              session.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => AdminLoginScreen(session: session),
                ),
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${user?.firstName ?? 'Admin'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Administrative dashboard placeholder',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Next: accounts, transactions, reports and reference data management.'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
