import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'features/auth/auth_session.dart';
import 'features/auth/login_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/splash_screen.dart';

class BankingMobileApp extends StatefulWidget {
  const BankingMobileApp({super.key});

  @override
  State<BankingMobileApp> createState() => _BankingMobileAppState();
}

class _BankingMobileAppState extends State<BankingMobileApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthSession _session;

  @override
  void initState() {
    super.initState();
    _session = AuthSession(ApiClient());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Digital Bank',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: SplashScreen(
        onFinished: () {
          _navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => OnboardingScreen(
                onFinished: () {
                  _navigatorKey.currentState?.pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginScreen(session: _session),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
