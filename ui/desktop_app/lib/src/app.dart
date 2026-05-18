import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'features/auth/admin_login_screen.dart';
import 'features/auth/auth_session.dart';

class BankingDesktopApp extends StatefulWidget {
  const BankingDesktopApp({super.key});

  @override
  State<BankingDesktopApp> createState() => _BankingDesktopAppState();
}

class _BankingDesktopAppState extends State<BankingDesktopApp> {
  late final AuthSession _session;

  @override
  void initState() {
    super.initState();
    _session = AuthSession(ApiClient());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BankPick Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AdminLoginScreen(session: _session),
    );
  }
}
