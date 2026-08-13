import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/app_theme.dart';
import '../admin_shell/admin_section.dart';
import '../admin_shell/widgets/admin_account_menu.dart';
import '../auth/auth_models.dart';
import 'admin_dashboard_overview.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.token,
    required this.onNavigate,
    required this.user,
    required this.onOpenProfile,
    required this.onOpenPreferences,
    required this.onOpenSecurity,
    required this.onLogout,
  });
  final String token;
  final ValueChanged<AdminSection> onNavigate;
  final AuthUser? user;
  final VoidCallback onOpenProfile, onOpenPreferences, onOpenSecurity, onLogout;

  void _search(String value) {
    final query = value.trim().toLowerCase();
    if (query.contains('transaction review') || query.contains('review')) {
      onNavigate(AdminSection.transactionReviews);
    } else if (query.contains('transaction')) {
      onNavigate(AdminSection.transactions);
    } else if (query.contains('customer')) {
      onNavigate(AdminSection.customers);
    } else if (query.contains('card')) {
      onNavigate(AdminSection.cardRequests);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 62,
        padding: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF303244)
                  : AppTheme.border,
            ),
          ),
        ),
        child: Row(
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: 300,
              child: TextField(
                onSubmitted: _search,
                decoration: const InputDecoration(
                  hintText: 'Search anything...',
                  prefixIcon: Icon(LucideIcons.search, size: 18),
                ),
              ),
            ),
            const Spacer(flex: 2),
            IconButton(
              onPressed: () {},
              tooltip: 'Notifications',
              icon: const Icon(LucideIcons.bell, size: 20),
            ),
            IconButton(
              onPressed: () {},
              tooltip: 'Messages',
              icon: const Icon(LucideIcons.messagesSquare, size: 20),
            ),
            const SizedBox(width: 8),
            AdminAccountMenu(
              user: user,
              showDetails: MediaQuery.sizeOf(context).width >= 1100,
              onProfile: onOpenProfile,
              onPreferences: onOpenPreferences,
              onSecurity: onOpenSecurity,
              onLogout: onLogout,
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Expanded(
        child: AdminDashboardOverview(
          token: token,
          onViewTransactions: () => onNavigate(AdminSection.transactions),
          onViewReviews: () => onNavigate(AdminSection.transactionReviews),
          onViewCardRequests: () => onNavigate(AdminSection.cardRequests),
        ),
      ),
    ],
  );
}
