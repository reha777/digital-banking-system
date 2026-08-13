import 'package:flutter/material.dart';

import '../../core/theme_controller.dart';
import '../../widgets/mobile_shell.dart';
import '../accounts/account_models.dart';
import '../auth/auth_session.dart';
import '../auth/login_screen.dart';
import '../cards/mobile_cards_screen.dart';
import '../home/pages/home_page.dart';
import '../settings/pages/settings_page.dart';
import '../statistics/pages/statistics_page.dart';
import '../transactions/send_money_screen.dart';
import '../transactions/transaction_history_screen.dart';

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
  bool _statisticsVisited = false;
  int _selectedIndex = 0;

  Future<void> _openSendMoney(Account account) async {
    final transferred = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            SendMoneyScreen(session: widget.session, sourceAccount: account),
      ),
    );
    if (transferred == true && mounted) {
      _homeKey.currentState?.refresh();
    }
  }

  Future<void> _openTransactionHistory() async {
    final selectedIndex = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => TransactionHistoryScreen(session: widget.session),
      ),
    );
    if (selectedIndex != null && mounted) {
      setState(() => _selectedIndex = selectedIndex);
    }
  }

  Future<void> _openCardRequest() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CardRequestScreen(session: widget.session),
      ),
    );
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
      onSelected: (index) {
        setState(() {
          _selectedIndex = index;
          _statisticsVisited = _statisticsVisited || index == 2;
        });
      },
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: _selectedIndex != 0,
              child: HomePage(
                key: _homeKey,
                session: widget.session,
                onSendMoney: _openSendMoney,
                onTransactionHistory: _openTransactionHistory,
                onLogout: _logout,
              ),
            ),
            if (_statisticsVisited)
              Offstage(
                offstage: _selectedIndex != 2,
                child: _SectionLayout(
                  title: 'Statistics',
                  onLogout: _logout,
                  child: StatisticsPage(session: widget.session),
                ),
              ),
            if (_selectedIndex == 1 || _selectedIndex == 3) _selectedPage(),
          ],
        ),
      ),
    );
  }

  Widget _selectedPage() {
    return switch (_selectedIndex) {
      1 => _SectionLayout(
        title: 'My Cards',
        showLogout: false,
        onLogout: _logout,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height - 180,
          child: MobileCardsScreen(
            session: widget.session,
            onRequestCard: _openCardRequest,
          ),
        ),
      ),
      3 => _SectionLayout(
        title: 'Settings',
        onLogout: _logout,
        child: SettingsPage(
          themeController: widget.themeController,
          onLogout: _logout,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _SectionLayout extends StatelessWidget {
  const _SectionLayout({
    required this.title,
    required this.onLogout,
    required this.child,
    this.showLogout = true,
  });

  final String title;
  final VoidCallback onLogout;
  final Widget child;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Row(
          children: [
            CircleIconButton(
              icon: Icons.arrow_back_ios_new,
              onPressed: () {},
              tooltip: 'Back',
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (showLogout)
              CircleIconButton(
                icon: Icons.logout,
                onPressed: onLogout,
                tooltip: 'Sign out',
              )
            else
              const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}
