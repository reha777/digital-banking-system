import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../widgets/profile_avatar.dart';

class HomeProfileHeader extends StatelessWidget {
  const HomeProfileHeader({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.hasProfilePhoto,
    required this.accessToken,
    required this.onProfileTap,
    this.profilePhotoUpdatedAtUtc,
  });

  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;
  final String? accessToken;
  final DateTime? profilePhotoUpdatedAtUtc;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName'.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        IconButton.filledTonal(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search ce biti povezan kasnije.')),
            );
          },
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? AppTheme.darkSurface
                : const Color(0xFFF5F6FA),
            foregroundColor: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
