import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../auth/auth_models.dart';

class AdminAvatar extends StatelessWidget {
  const AdminAvatar({
    super.key,
    required this.user,
    required this.radius,
    this.token,
    this.backgroundColor,
    this.foregroundColor,
  });

  final AuthUser? user;
  final double radius;
  final String? token;
  final Color? backgroundColor, foregroundColor;

  @override
  Widget build(BuildContext context) {
    final initials = [
      user?.firstName ?? '',
      user?.lastName ?? '',
    ].where((value) => value.isNotEmpty).map((value) => value[0]).join();
    final fallback = Center(
      child: Text(
        initials.isEmpty ? 'A' : initials.toUpperCase(),
        style: TextStyle(
          color: foregroundColor ?? Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * .62,
        ),
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ??
          Theme.of(context).colorScheme.primary.withValues(alpha: .1),
      child: ClipOval(
        child: SizedBox.square(
          dimension: radius * 2,
          child: user?.hasProfilePhoto == true && token?.isNotEmpty == true
              ? Image.network(
                  '${ApiClient.baseUrl}/api/admin/settings/profile/photo?v=${user?.profilePhotoUpdatedAtUtc?.millisecondsSinceEpoch ?? 0}',
                  headers: {'Authorization': 'Bearer $token'},
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}
