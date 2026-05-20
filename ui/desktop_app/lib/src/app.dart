import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/theme_controller.dart';
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
  late final ThemeController _themeController;
  late final Future<void> _initializeAppFuture;

  @override
  void initState() {
    super.initState();
    _session = AuthSession(ApiClient());
    _themeController = ThemeController();
    _initializeAppFuture = _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _session.initialize(),
      _themeController.initialize(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'BankPick Admin',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _themeController.themeMode,
          home: FutureBuilder<void>(
            future: _initializeAppFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return _session.isAuthenticated
                  ? AdminDashboardScreen(
                      session: _session,
                      themeController: _themeController,
                    )
                  : AdminLoginScreen(
                      session: _session,
                      themeController: _themeController,
                    );
            },
          ),
        );
      },
    );
  }
}
