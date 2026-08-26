import 'package:flutter/material.dart';
import '../admin_shell/admin_section.dart';
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
    this.dateFormatter,
  });
  final String token;
  final ValueChanged<AdminSection> onNavigate;
  final AuthUser? user;
  final VoidCallback onOpenProfile, onOpenPreferences, onOpenSecurity, onLogout;
  final String Function(DateTime)? dateFormatter;

  @override
  Widget build(BuildContext context) => AdminDashboardOverview(
    token: token,
    onViewTransactions: () => onNavigate(AdminSection.transactions),
    onViewReviews: () => onNavigate(AdminSection.transactionReviews),
    onViewCardRequests: () => onNavigate(AdminSection.cardRequests),
    onViewLoans: () => onNavigate(AdminSection.loans),
    dateFormatter: dateFormatter,
  );
}
