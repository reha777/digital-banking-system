import 'package:flutter/material.dart';

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().replaceAll(' ', '');
    final colors = switch (normalized) {
      'completed' ||
      'approved' ||
      'active' => (const Color(0xFF168A4A), const Color(0xFFE9F8EF)),
      'failed' ||
      'rejected' ||
      'blocked' => (const Color(0xFFC9363E), const Color(0xFFFFECEE)),
      'pending' => (const Color(0xFF9A6700), const Color(0xFFFFF4D6)),
      'inactive' => (const Color(0xFFB7791F), const Color(0xFFFFF7E6)),
      'documentsrequested' => (
        const Color(0xFF2864B7),
        const Color(0xFFEAF2FF),
      ),
      _ => (const Color(0xFF667085), const Color(0xFFF0F2F5)),
    };
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? colors.$1.withValues(alpha: .18) : colors.$2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: dark ? colors.$1.withValues(alpha: .95) : colors.$1,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
