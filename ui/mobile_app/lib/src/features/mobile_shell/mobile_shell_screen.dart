import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme_controller.dart';
import '../../core/api_client.dart';
import '../../widgets/mobile_shell.dart';
import '../accounts/account_models.dart';
import '../account_transfer/pages/account_transfer_page.dart';
import '../auth/auth_session.dart';
import '../auth/login_screen.dart';
import '../cards/mobile_cards_screen.dart';
import '../cards/card_models.dart';
import '../cards/pages/card_details_screen.dart';
import '../home/pages/home_page.dart';
import '../loans/pages/loans_page.dart';
import '../receive/pages/receive_money_page.dart';
import '../settings/pages/settings_page.dart';
import '../settings/pages/profile_page.dart';
import '../settings/settings_service.dart';
import '../statistics/pages/statistics_page.dart';
import '../statistics/models/statistics_models.dart';
import '../transactions/send_money_screen.dart';
import '../transactions/transaction_history_screen.dart';
import '../notifications/notifications_page.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({
    super.key,
    required this.session,
    required this.themeController,
  });

  final AuthSession session;
  final ThemeController themeController;

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  final _homeKey = GlobalKey<HomePageState>();
  final _contentNavigatorKey = GlobalKey<NavigatorState>();
  final _selectedIndexNotifier = ValueNotifier<int>(0);
  bool _cardsVisited = false;
  bool _statisticsVisited = false;
  bool _settingsVisited = false;
  int _selectedIndex = 0;
  int _cardsRefreshRevision = 0;

  NavigatorState get _contentNavigator => _contentNavigatorKey.currentState!;

  @override
  void dispose() {
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    _contentNavigator.popUntil((route) => route.isFirst);
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      _cardsVisited = _cardsVisited || index == 1;
      _statisticsVisited = _statisticsVisited || index == 2;
      _settingsVisited = _settingsVisited || index == 3;
      _selectedIndexNotifier.value = index;
    });
  }

  Future<void> _openSendMoney(Account account) async {
    final transferred = await _contentNavigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            SendMoneyScreen(session: widget.session, sourceAccount: account),
      ),
    );
    if (transferred == true && mounted) {
      _homeKey.currentState?.refresh();
    }
  }

  Future<void> _openTransactionHistory([String? accountId]) async {
    await _contentNavigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionHistoryScreen(
          session: widget.session,
          accountId: accountId,
        ),
      ),
    );
  }

  Future<void> _openFilteredTransactionHistory(
    StatisticsHistoryRequest request,
  ) async {
    await _contentNavigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransactionHistoryScreen(
          session: widget.session,
          accountId: request.accountId,
          dateFrom: request.from,
          dateTo: request.to,
        ),
      ),
    );
  }

  Future<void> _openReceiveMoney() async {
    await _contentNavigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReceiveMoneyPage(session: widget.session),
      ),
    );
  }

  Future<void> _openAccountTransfer() async {
    final transferred = await _contentNavigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountTransferPage(session: widget.session),
      ),
    );
    if (transferred == true && mounted) {
      _homeKey.currentState?.refresh();
    }
  }

  Future<void> _openLoans() async {
    final submitted = await _contentNavigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LoansPage(session: widget.session),
      ),
    );
    if (submitted == true && mounted) {
      _homeKey.currentState?.refresh();
    }
  }

  Future<void> _openCardDetails(BankCardModel card) async {
    await _contentNavigator.push<BankCardModel>(
      MaterialPageRoute(
        builder: (_) => CardDetailsScreen(session: widget.session, card: card),
      ),
    );
    _homeKey.currentState?.refresh();
  }

  Future<void> _openCardRequest() async {
    await _contentNavigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CardRequestScreen(session: widget.session),
      ),
    );
  }

  Future<void> _openProfile() async {
    final user = widget.session.user;
    if (user == null) return;
    await _contentNavigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          user: user,
          service: SettingsService(ApiClient(), widget.session),
          onOpenCards: () => _selectTab(1),
          onProfileUpdated: () => setState(() {}),
          accessToken: widget.session.token,
          session: widget.session,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openNotifications() async {
    await _contentNavigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(
          session: widget.session,
          onOpenTarget: (notification) {
            _contentNavigator.pop();
            final entityType = notification.entityType;
            if (entityType == 'CardRequest') {
              setState(() => _cardsRefreshRevision++);
              _selectTab(1);
            }
            if (entityType == 'Transaction') _openTransactionHistory();
            if (entityType == 'LoanApplication' ||
                entityType == 'LoanInstallment') {
              _openLoans();
            }
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          session: widget.session,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      currentIndex: _selectedIndex,
      onSelected: _selectTab,
      child: NavigatorPopHandler<void>(
        onPopWithResult: (_) => _contentNavigator.maybePop(),
        child: Navigator(
          key: _contentNavigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'mobile-tab-root'),
            builder: (_) => ValueListenableBuilder<int>(
              valueListenable: _selectedIndexNotifier,
              builder: (_, index, _) => _buildTabRoot(index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabRoot(int index) {
    final pages = <Widget>[
      HomePage(
        key: _homeKey,
        session: widget.session,
        onSendMoney: _openSendMoney,
        onReceiveMoney: _openReceiveMoney,
        onTransfer: _openAccountTransfer,
        onLoan: _openLoans,
        onTransactionHistory: _openTransactionHistory,
        onLogout: _logout,
        onProfileTap: _openProfile,
        onCardTap: _openCardDetails,
        onNotificationsTap: _openNotifications,
      ),
      _cardsVisited ? _selectedPage(1) : const SizedBox.shrink(),
      _statisticsVisited ? _selectedPage(2) : const SizedBox.shrink(),
      _settingsVisited ? _selectedPage(3) : const SizedBox.shrink(),
    ];

    return SafeArea(
      child: MobileTabStack(currentIndex: index, children: pages),
    );
  }

  Widget _selectedPage(int index) {
    return switch (index) {
      1 => _SectionLayout(
        title: 'My Cards',
        onBack: () => _selectTab(0),
        showLogout: false,
        expandChild: true,
        onLogout: _logout,
        child: MobileCardsScreen(
          session: widget.session,
          onRequestCard: _openCardRequest,
          refreshRevision: _cardsRefreshRevision,
        ),
      ),
      3 => _SectionLayout(
        title: 'Settings',
        onBack: () => _selectTab(0),
        onLogout: _logout,
        child: SettingsPage(
          themeController: widget.themeController,
          user: widget.session.user,
          session: widget.session,
          onProfileUpdated: () => setState(() {}),
          onOpenCards: () => _selectTab(1),
        ),
      ),
      2 => _SectionLayout(
        title: 'Statistics',
        onBack: () => _selectTab(0),
        expandChild: true,
        showLogout: false,
        onLogout: _logout,
        trailing: NotificationBell(
          session: widget.session,
          onTap: _openNotifications,
        ),
        child: StatisticsPage(
          session: widget.session,
          onSeeAll: _openFilteredTransactionHistory,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _SectionLayout extends StatelessWidget {
  const _SectionLayout({
    required this.title,
    required this.onBack,
    required this.onLogout,
    required this.child,
    this.showLogout = true,
    this.expandChild = false,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onLogout;
  final Widget child;
  final bool showLogout;
  final bool expandChild;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        CircleIconButton(
          icon: LucideIcons.arrowLeft,
          onPressed: onBack,
          tooltip: 'Back',
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (trailing != null)
          SizedBox(width: 48, child: trailing)
        else if (showLogout)
          CircleIconButton(
            icon: Icons.logout,
            onPressed: onLogout,
            tooltip: 'Sign out',
          )
        else
          const SizedBox(width: 48),
      ],
    );

    if (expandChild) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: Column(
          children: [
            header,
            const SizedBox(height: 24),
            Expanded(child: child),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [header, const SizedBox(height: 24), child],
    );
  }
}
