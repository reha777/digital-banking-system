import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme_controller.dart';
import '../auth/admin_login_screen.dart';
import '../auth/auth_session.dart';
import '../audit_logs/audit_logs_page.dart';
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
import '../reference_data/reference_data_page.dart';
import '../reports/reports_page.dart';
import '../notifications/notifications_page.dart';
import '../notifications/notification_bell.dart';
import '../notifications/notification_service.dart';
import 'admin_section.dart';
import 'widgets/admin_sidebar.dart';
import 'widgets/admin_account_menu.dart';
import '../../widgets/app_page_header.dart';

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
  bool _navigatingToLogin = false;
  BuildContext? _warningDialogContext;
  DateTime? _lastPassiveActivityAt;
  SettingsSection _settingsSection = SettingsSection.general;
  final List<AdminSection> _cachedSections = [];
  int _bellGeneration = 0;
  int _accountGeneration = 0;
  int _cardRequestsRefreshRevision = 0;
  int _transactionReviewsRefreshRevision = 0;
  int _loansRefreshRevision = 0;

  static const _cacheableSections = <AdminSection>{
    AdminSection.transactions,
    AdminSection.transactionReviews,
    AdminSection.customers,
    AdminSection.cardRequests,
    AdminSection.loans,
    AdminSection.auditLogs,
    AdminSection.referenceData,
    AdminSection.reports,
    AdminSection.notifications,
  };

  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_handleSettingsChanged);
    widget.session.addListener(_handleSessionChanged);
    _resetActivityTimers();
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_handleSettingsChanged);
    widget.session.removeListener(_handleSessionChanged);
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

  void _handleSettingsChanged() {
    _resetActivityTimers();
    if (mounted) setState(() {});
  }

  void _recordPassiveActivity() {
    final now = DateTime.now();
    if (_lastPassiveActivityAt != null &&
        now.difference(_lastPassiveActivityAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastPassiveActivityAt = now;
    _resetActivityTimers();
  }

  Future<void> _showSessionWarning(int minutes) async {
    if (!mounted || _warningVisible) return;
    _warningVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _warningDialogContext = dialogContext;
        return AlertDialog(
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
        );
      },
    );
    _warningDialogContext = null;
    _warningVisible = false;
  }

  void _selectSection(AdminSection section) => setState(() {
    _selectedSection = section;
    if (_cacheableSections.contains(section) &&
        !_cachedSections.contains(section)) {
      _cachedSections.add(section);
    }
  });

  void _openNotificationTarget(AdminNotification notification) {
    final type = notification.entityType;
    setState(() {
      if (type == 'LoanApplication' || type == 'LoanInstallment') {
        _loansRefreshRevision++;
        _selectedSection = AdminSection.loans;
      } else if (type == 'CardRequest') {
        _cardRequestsRefreshRevision++;
        _selectedSection = AdminSection.cardRequests;
      } else if (type == 'Transaction') {
        _transactionReviewsRefreshRevision++;
        _selectedSection = AdminSection.transactionReviews;
      } else {
        return;
      }
      if (!_cachedSections.contains(_selectedSection)) {
        _cachedSections.add(_selectedSection);
      }
    });
  }

  void _openSettings(SettingsSection section) => setState(() {
    _settingsSection = section;
    _selectedSection = AdminSection.settings;
  });
  Future<void> _profileUpdated(AdminProfile profile) async {
    await widget.session.updateProfile(
      firstName: profile.firstName,
      lastName: profile.lastName,
      hasProfilePhoto: profile.hasProfilePhoto,
      profilePhotoUpdatedAtUtc: profile.profilePhotoUpdatedAtUtc,
      clearProfilePhoto: !profile.hasProfilePhoto,
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final dialogContext = _warningDialogContext;
    if (dialogContext != null && Navigator.of(dialogContext).canPop()) {
      Navigator.of(dialogContext).pop();
    }
    _warningDialogContext = null;
    _warningVisible = false;
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    await widget.session.logout();
    await _navigateToLogin();
  }

  void _handleSessionChanged() {
    if (!widget.session.isAuthenticated) _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    if (!mounted || _navigatingToLogin) return;
    _navigatingToLogin = true;
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

  Widget _activePage(AdminSection section, String token) => switch (section) {
    AdminSection.dashboard => AdminDashboardScreen(
      token: token,
      onNavigate: _selectSection,
      user: widget.session.user,
      onOpenProfile: () => _openSettings(SettingsSection.profile),
      onOpenPreferences: () => _openSettings(SettingsSection.general),
      onOpenSecurity: () => _openSettings(SettingsSection.security),
      onLogout: _logout,
      dateFormatter: widget.settingsController.formatDateTime,
    ),
    AdminSection.transactions => TransactionsPage(
      token: token,
      showHeader: false,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDateTime,
    ),
    AdminSection.transactionReviews => TransactionReviewPage(
      token: token,
      showHeader: false,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDateTime,
      refreshRevision: _transactionReviewsRefreshRevision,
    ),
    AdminSection.customers => CustomersPage(
      token: token,
      showHeader: false,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDateTime,
    ),
    AdminSection.cardRequests => CardRequestsPage(
      token: token,
      showHeader: false,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDateTime,
      refreshRevision: _cardRequestsRefreshRevision,
    ),
    AdminSection.loans => LoansPage(
      token: token,
      showHeader: false,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDateTime,
      refreshRevision: _loansRefreshRevision,
    ),
    AdminSection.auditLogs => AuditLogsPage(
      token: token,
      showHeader: false,
      defaultPageSize:
          widget.settingsController.preferences.defaultItemsPerPage,
      dateFormatter: widget.settingsController.formatDateTime,
    ),
    AdminSection.referenceData => ReferenceDataPage(token: token),
    AdminSection.reports => ReportsPage(token: token),
    AdminSection.notifications => NotificationsPage(
      token: token,
      onTarget: _openNotificationTarget,
    ),
    AdminSection.settings => SettingsPage(
      token: token,
      controller: widget.settingsController,
      onProfileUpdated: _profileUpdated,
      initialSection: _settingsSection,
      headerAction: const SizedBox.shrink(),
      showHeader: false,
    ),
  };

  Widget _pageFor(AdminSection section, String token) {
    return KeyedSubtree(
      key: ValueKey(section),
      child: _activePage(section, token),
    );
  }

  Widget _pageHost(String token) {
    final isCached = _cacheableSections.contains(_selectedSection);
    if (isCached && !_cachedSections.contains(_selectedSection)) {
      _cachedSections.add(_selectedSection);
    }
    return Stack(
      children: [
        if (_cachedSections.isNotEmpty)
          Positioned.fill(
            child: Offstage(
              offstage: !isCached,
              child: IndexedStack(
                index: isCached ? _cachedSections.indexOf(_selectedSection) : 0,
                children: [
                  for (final section in _cachedSections)
                    _pageFor(section, token),
                ],
              ),
            ),
          ),
        if (!isCached)
          Positioned.fill(
            child: KeyedSubtree(
              key: ValueKey(_selectedSection),
              child: _activePage(_selectedSection, token),
            ),
          ),
      ],
    );
  }

  String get _sectionTitle => switch (_selectedSection) {
    AdminSection.dashboard => 'Dashboard',
    AdminSection.transactions => 'Transactions',
    AdminSection.transactionReviews => 'Transaction Review',
    AdminSection.customers => 'Customers',
    AdminSection.cardRequests => 'Card Requests',
    AdminSection.loans => 'Loans',
    AdminSection.auditLogs => 'Audit Logs',
    AdminSection.referenceData => 'Reference Data',
    AdminSection.reports => 'Reports',
    AdminSection.notifications => 'Notifications',
    AdminSection.settings => 'Settings',
  };

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) _resetActivityTimers();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetActivityTimers(),
        onPointerMove: (_) => _recordPassiveActivity(),
        onPointerSignal: (_) => _recordPassiveActivity(),
        child: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 1100 ||
                  widget.settingsController.preferences.sidebarStyle ==
                      'compact';
              final padding = constraints.maxWidth < 900 ? 16.0 : 28.0;
              return Row(
                children: [
                  AdminSidebar(
                    compact: compact,
                    userName:
                        '${user?.firstName ?? 'Admin'} ${user?.lastName ?? ''}'
                            .trim(),
                    user: user,
                    token: widget.session.token,
                    selectedSection: _selectedSection,
                    onSectionSelected: _selectSection,
                    onLogout: _logout,
                    systemName:
                        widget.settingsController.settings?.system.systemName ??
                        'Digital Banking System',
                    systemShortName:
                        widget
                            .settingsController
                            .settings
                            ?.system
                            .systemShortName ??
                        'DBS',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            14,
                            padding,
                            12,
                          ),
                          child: Row(
                            key: const ValueKey('global-admin-header'),
                            children: [
                              Expanded(
                                child: Text(
                                  _sectionTitle,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              DesktopNotificationBell(
                                key: ValueKey(
                                  'notification-bell-$_bellGeneration',
                                ),
                                token: widget.session.token ?? '',
                                onOpening: () =>
                                    setState(() => _accountGeneration++),
                                onViewAll: () =>
                                    _selectSection(AdminSection.notifications),
                                onTarget: _openNotificationTarget,
                              ),
                              const SizedBox(width: 10),
                              AdminAccountMenu(
                                key: ValueKey(
                                  'account-menu-$_accountGeneration',
                                ),
                                user: widget.session.user,
                                token: widget.session.token,
                                showDetails: true,
                                onProfile: () =>
                                    _openSettings(SettingsSection.profile),
                                onPreferences: () =>
                                    _openSettings(SettingsSection.general),
                                onSecurity: () =>
                                    _openSettings(SettingsSection.security),
                                onLogout: _logout,
                                onOpening: () =>
                                    setState(() => _bellGeneration++),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              18,
                              padding,
                              24,
                            ),
                            child: AdminPageHeaderScope(
                              child: _pageHost(widget.session.token ?? ''),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
