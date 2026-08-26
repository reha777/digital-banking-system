import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/auth_session.dart';
import '../settings_service.dart';
import 'change_password_page.dart';
import 'privacy_policy_page.dart';
import 'profile_page.dart';
import '../widgets/settings_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    this.user,
    this.session,
    this.onOpenCards,
    this.onProfileUpdated,
  });

  final ThemeController themeController;
  final AuthUser? user;
  final AuthSession? session;
  final VoidCallback? onOpenCards;
  final VoidCallback? onProfileUpdated;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, _) =>
            FadeTransition(opacity: animation, child: page),
        transitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = session == null
        ? null
        : SettingsService(ApiClient(), session!);
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            title: 'General',
            children: [
              SettingsNavigationTile(
                label: 'My Profile',
                onTap: user == null
                    ? null
                    : () => _push(
                        context,
                        ProfilePage(
                          user: user!,
                          service: service,
                          onOpenCards: onOpenCards,
                          onProfileUpdated: onProfileUpdated,
                          accessToken: session?.token,
                          session: session,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SettingsSection(
            title: 'Security',
            children: [
              SettingsNavigationTile(
                label: 'Change Password',
                onTap: () => _push(
                  context,
                  ChangePasswordPage(onSubmit: service?.changePassword),
                ),
              ),
              SettingsNavigationTile(
                label: 'Privacy Policy',
                onTap: () => _push(context, const PrivacyPolicyPage()),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SettingsSection(
            title: 'Appearance',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                subtitle: const Text(
                  'Switch between light and dark app theme.',
                ),
                value: themeController.isDarkMode,
                onChanged: themeController.toggleDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
