import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme_controller.dart';
import '../auth/admin_login_screen.dart';
import '../auth/auth_session.dart';
import '../cards/pages/card_requests_page.dart';
import '../customers/pages/customers_page.dart';
import '../loans/pages/loans_page.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../transactions/pages/transaction_review_page.dart';
import '../transactions/pages/transactions_page.dart';
import '../settings/admin_settings_controller.dart';
import '../settings/pages/settings_page.dart';
import '../settings/admin_settings_models.dart';
import '../settings/widgets/settings_navigation.dart';
import 'admin_section.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_account_menu.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({
    super.key,
    required this.session,
    required this.themeController,
    required this.settingsController,
  });
  final AuthSession session;
  final ThemeController themeController;
  final AdminSettingsController settingsController;
  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  AdminSection _selectedSection = AdminSection.dashboard;
  Timer? _warningTimer;
  Timer? _logoutTimer;
  bool _warningVisible = false;
  SettingsSection _settingsSection = SettingsSection.general;

  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_resetActivityTimers);
    _resetActivityTimers();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_resetActivityTimers);
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    super.dispose();
  }

  void _resetActivityTimers() {
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    final system = widget.settingsController.settings?.system;
    if (system == null) return;
    final timeout = system.sessionTimeoutMinutes;
    final warning = system.autoLogoutWarningMinutes.clamp(1, timeout - 1);
    _warningTimer = Timer(
      Duration(minutes: timeout - warning),
      () => _showSessionWarning(warning),
    );
    _logoutTimer = Timer(Duration(minutes: timeout), _logout);
  }

  Future<void> _showSessionWarning(int minutes) async {
    if (!mounted || _warningVisible) return;
    _warningVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Session expiring'),
        content: Text(
          'You will be signed out in $minutes minute${minutes == 1 ? '' : 's'} due to inactivity.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resetActivityTimers();
            },
            child: const Text('Stay signed in'),
          ),
        ],
      ),
    );
    _warningVisible = false;
  }

  void _selectSection(AdminSection section) =>
      setState(() => _selectedSection = section);
  void _openSettings(SettingsSection section) => setState(() {
    _settingsSection = section;
    _selectedSection = AdminSection.settings;
  });
  Future<void> _profileUpdated(AdminProfile profile) async {
    await widget.session.updateProfile(
      firstName: profile.firstName,
      lastName: profile.lastName,
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminLoginScreen(
          session: widget.session,
          themeController: widget.themeController,
          settingsController: widget.settingsController,
        ),
      ),
    );
  }

  Widget _activePage(String token) => switch (_selectedSection) {
    AdminSection.dashboard => AdminDashboardScreen(
      token: token,
      onNavigate: _selectSection,
      user: widget.session.user,
      onOpenProfile: () => _openSettings(SettingsSection.profile),
      onOpenPreferences: () => _openSettings(SettingsSection.general),
      onOpenSecurity: () => _openSettings(SettingsSection.security),
      onLogout: _logout,
    ),
    AdminSection.transactions => TransactionsPage(
      token: token,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDate,
    ),
    AdminSection.transactionReviews => TransactionReviewPage(
      token: token,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDate,
    ),
    AdminSection.customers => CustomersPage(
      token: token,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDate,
    ),
    AdminSection.cardRequests => CardRequestsPage(
      token: token,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDate,
    ),
    AdminSection.loans => LoansPage(
      token: token,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDate,
    ),
    AdminSection.settings => SettingsPage(
      token: token,
      controller: widget.settingsController,
      onProfileUpdated: _profileUpdated,
      initialSection: _settingsSection,
      headerAction: AdminAccountMenu(
        user: widget.session.user,
        showDetails: true,
        onProfile: () => _openSettings(SettingsSection.profile),
        onPreferences: () => _openSettings(SettingsSection.general),
        onSecurity: () => _openSettings(SettingsSection.security),
        onLogout: _logout,
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetActivityTimers(),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 1100 ||
                widget.settingsController.preferences.sidebarStyle == 'compact';
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(.012, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_selectedSection),
                        child: _activePage(widget.session.token ?? ''),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
