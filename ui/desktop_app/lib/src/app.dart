import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/auth/auth_session.dart';
import 'features/dashboard/admin_dashboard_screen.dart';

class BankingDesktopApp extends StatefulWidget {
  const BankingDesktopApp({super.key});

  @override
  State<BankingDesktopApp> createState() => _BankingDesktopAppState();
}

class _BankingDesktopAppState extends State<BankingDesktopApp> {
  late final AuthSession _session;
  late final Future<void> _initializeSessionFuture;

  @override
  void initState() {
    super.initState();
    _session = AuthSession(ApiClient());
    _initializeSessionFuture = _session.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankPick Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<void>(
        future: _initializeSessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return _session.isAuthenticated
              ? AdminDashboardScreen(session: _session)
              : AdminLoginScreen(session: _session);
        },
      ),
    );
  }
}
