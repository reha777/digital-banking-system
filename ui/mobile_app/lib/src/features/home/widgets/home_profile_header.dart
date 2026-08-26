import 'package:flutter/material.dart';

import '../../../widgets/profile_avatar.dart';
import '../../auth/auth_session.dart';
import '../../notifications/notifications_page.dart';

class HomeProfileHeader extends StatelessWidget {
  const HomeProfileHeader({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.hasProfilePhoto,
    required this.accessToken,
    required this.onProfileTap,
    this.session,
    this.onNotificationsTap,
    this.profilePhotoUpdatedAtUtc,
  });

  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;
  final String? accessToken;
  final DateTime? profilePhotoUpdatedAtUtc;
  final VoidCallback onProfileTap;
  final AuthSession? session;
  final Future<void> Function()? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName'.trim();
    return Row(
      children: [
        ProfileAvatar(
          firstName: firstName,
          lastName: lastName,
          hasProfilePhoto: hasProfilePhoto,
          accessToken: accessToken,
          photoVersion: profilePhotoUpdatedAtUtc,
          onTap: onProfileTap,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 3),
              Text(
                fullName.isEmpty ? 'BankPick Customer' : fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        if (session != null && onNotificationsTap != null)
          NotificationBell(session: session!, onTap: onNotificationsTap!),
      ],
    );
  }
}
