import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../widgets/app_page_header.dart';
import '../admin_shell/admin_section.dart';
import 'admin_dashboard_overview.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.token,
    required this.onNavigate,
  });
  final String token;
  final ValueChanged<AdminSection> onNavigate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppPageHeader(
        icon: LucideIcons.layoutDashboard,
        title: 'Dashboard',
        subtitle: 'Overview of your digital banking system.',
      ),
      const SizedBox(height: 18),
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
