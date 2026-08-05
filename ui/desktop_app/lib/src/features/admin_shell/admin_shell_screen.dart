import 'package:flutter/material.dart';
import '../../core/theme_controller.dart';
import '../auth/admin_login_screen.dart';
import '../auth/auth_session.dart';
import '../cards/pages/card_requests_page.dart';
import '../customers/pages/customers_page.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../transactions/pages/transaction_review_page.dart';
import '../transactions/pages/transactions_page.dart';
import 'admin_section.dart';
import 'widgets/admin_sidebar.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({
    super.key,
    required this.session,
    required this.themeController,
  });
  final AuthSession session;
  final ThemeController themeController;
  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  AdminSection _selectedSection = AdminSection.dashboard;
  void _selectSection(AdminSection section) =>
      setState(() => _selectedSection = section);
  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminLoginScreen(
          session: widget.session,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  Widget _activePage(String token) => switch (_selectedSection) {
    AdminSection.dashboard => AdminDashboardScreen(
      token: token,
      onNavigate: _selectSection,
    ),
    AdminSection.transactions => TransactionsPage(token: token),
    AdminSection.transactionReviews => TransactionReviewPage(token: token),
    AdminSection.customers => CustomersPage(token: token),
    AdminSection.cardRequests => CardRequestsPage(token: token),
  };

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          final padding = constraints.maxWidth < 900 ? 16.0 : 28.0;
          return Row(
            children: [
              AdminSidebar(
                compact: compact,
                userName:
                    '${user?.firstName ?? 'Admin'} ${user?.lastName ?? ''}'
                        .trim(),
                selectedSection: _selectedSection,
                onSectionSelected: _selectSection,
                themeController: widget.themeController,
                onLogout: _logout,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 24, padding, 24),
                  child: _activePage(widget.session.token ?? ''),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
