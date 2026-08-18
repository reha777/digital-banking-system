import 'package:flutter/material.dart';

import '../core/api_client.dart';

String profileInitials(String firstName, String lastName) {
  final parts = [
    firstName.trim(),
    lastName.trim(),
  ].where((value) => value.isNotEmpty);
  return parts.map((value) => value[0].toUpperCase()).take(2).join();
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.hasProfilePhoto,
    required this.accessToken,
    this.photoVersion,
    this.onTap,
    this.size = 52,
    this.borderWidth = 3,
  });

  final String firstName;
  final String lastName;
  final bool hasProfilePhoto;
  final String? accessToken;
  final DateTime? photoVersion;
  final VoidCallback? onTap;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final initials = profileInitials(firstName, lastName);
    final fallback = Container(
      color: const Color(0xFF1D4ED8),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final token = accessToken;
    final content = hasProfilePhoto && token != null
        ? Image.network(
            '${ApiClient.baseUrl}/api/profile/photo?v=${photoVersion?.millisecondsSinceEpoch ?? 0}',
            headers: {'Authorization': 'Bearer $token'},
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        key: const ValueKey('profile-avatar-tap'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(borderWidth),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEFF1F7),
          ),
          child: ClipOval(child: content),
        ),
      ),
    );
  }
}
