import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../auth/auth_models.dart';

class AdminAccountMenu extends StatelessWidget {
  const AdminAccountMenu({
    super.key,
    required this.user,
    required this.showDetails,
    required this.onProfile,
    required this.onPreferences,
    required this.onSecurity,
    required this.onLogout,
  });
  final AuthUser? user;
  final bool showDetails;
  final VoidCallback onProfile, onPreferences, onSecurity, onLogout;
  String get _name =>
      '${user?.firstName ?? 'Admin'} ${user?.lastName ?? ''}'.trim();
  String get _initials => [
    user?.firstName ?? '',
    user?.lastName ?? '',
  ].where((v) => v.isNotEmpty).map((v) => v[0].toUpperCase()).join();
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Account menu',
    offset: const Offset(0, 48),
    constraints: const BoxConstraints.tightFor(width: 286),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    elevation: 10,
    onSelected: (value) => switch (value) {
      'profile' => onProfile(),
      'preferences' => onPreferences(),
      'security' => onSecurity(),
      'logout' => onLogout(),
      _ => null,
    },
    itemBuilder: (context) => [
      PopupMenuItem<String>(
        enabled: false,
        height: 72,
        child: Row(
          children: [
            _avatar(context, 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      _item(
        'profile',
        LucideIcons.user,
        'Profile',
        'View and edit your profile',
      ),
      _item(
        'preferences',
        LucideIcons.slidersHorizontal,
        'Preferences',
        'Personal settings',
      ),
      _item(
        'security',
        LucideIcons.keyRound,
        'Change Password',
        'Update your password',
      ),
      const PopupMenuDivider(),
      _item(
        'logout',
        LucideIcons.logOut,
        'Logout',
        'Sign out of your account',
        danger: true,
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _avatar(context, 18),
          if (showDetails && MediaQuery.sizeOf(context).width >= 1100) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Administrator',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
          const Icon(LucideIcons.chevronDown, size: 16),
        ],
      ),
    ),
  );
  PopupMenuItem<String> _item(
    String value,
    IconData icon,
    String title,
    String subtitle, {
    bool danger = false,
  }) => PopupMenuItem(
    value: value,
    height: 62,
    child: Row(
      children: [
        Icon(icon, size: 19, color: danger ? const Color(0xFFDC2626) : null),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: danger ? const Color(0xFFDC2626) : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _avatar(BuildContext context, double radius) => CircleAvatar(
    radius: radius,
    backgroundColor: Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: .1),
    child: Text(
      _initials.isEmpty ? 'A' : _initials,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        fontSize: radius * .65,
      ),
    ),
  );
}
