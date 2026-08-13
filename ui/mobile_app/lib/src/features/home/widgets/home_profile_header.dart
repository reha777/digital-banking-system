import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class HomeProfileHeader extends StatelessWidget {
  const HomeProfileHeader({
    super.key,
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName'.trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1D2144), Color(0xFF0066FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFEFF1F7), width: 3),
          ),
          child: Center(
            child: Text(
              firstName.isEmpty ? 'B' : firstName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
