import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../widgets/mobile_shell.dart';
import '../accounts/account_models.dart';
import '../accounts/account_service.dart';
import '../auth/auth_session.dart';
import '../auth/login_screen.dart';
import '../transactions/send_money_screen.dart';
import '../transactions/transaction_models.dart';
import '../transactions/transaction_service.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  late final AccountService _accountService;
  late final TransactionService _transactionService;
  late Future<_DashboardData> _dashboardFuture;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient();
    _accountService = AccountService(apiClient);
    _transactionService = TransactionService(apiClient);
    _dashboardFuture = _loadDashboard();
  }

  Future<_DashboardData> _loadDashboard() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    final balance = await _accountService.getBalanceSummary(token);
    final transactions = await _transactionService.getRecentTransactions(token);

    return _DashboardData(
      balance: balance,
      transactions: transactions,
    );
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<void> _refreshDashboardAsync() async {
    final future = _loadDashboard();
    setState(() {
      _dashboardFuture = future;
    });
    await future;
  }

  Future<void> _openSendMoney(Account account) async {
    final transferred = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SendMoneyScreen(
          session: widget.session,
          sourceAccount: account,
        ),
      ),
    );

    if (transferred == true) {
      _refreshDashboard();
    }
  }

  Future<void> _logout() async {
    await widget.session.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(session: widget.session),
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
        });
      },
      child: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _DashboardError(
                message: snapshot.error.toString(),
                onRetry: _refreshDashboard,
                onLogout: _logout,
              );
            }

            final data = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: _refreshDashboardAsync,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                children: [
                  if (_selectedIndex != 0) ...[
                    _DashboardHeader(
                      title: _selectedIndex == 2 ? 'Statistics' : 'Home',
                      onLogout: _logout,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedIndex == 0)
                    _HomeBalanceCard(
                      firstName: widget.session.user?.firstName ?? 'Customer',
                      lastName: widget.session.user?.lastName ?? '',
                      summary: data.balance,
                      onSendMoney: data.balance.primaryAccount == null
                          ? null
                          : () => _openSendMoney(data.balance.primaryAccount!),
                    )
                  else if (_selectedIndex == 2)
                    _StatisticsCard(summary: data.balance)
                  else
                    _ComingSoonCard(
                      title: _selectedIndex == 1 ? 'My Cards' : 'Settings',
                    ),
                  const SizedBox(height: 24),
                  _TransactionsSection(transactions: data.transactions),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.balance,
    required this.transactions,
  });

  final AccountBalanceSummary balance;
  final List<BankTransaction> transactions;
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.onLogout,
  });

  final String title;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        CircleIconButton(
          icon: Icons.logout,
          onPressed: onLogout,
          tooltip: 'Sign out',
        ),
      ],
    );
  }
}

class _HomeBalanceCard extends StatelessWidget {
  const _HomeBalanceCard({
    required this.firstName,
    required this.lastName,
    required this.summary,
    required this.onSendMoney,
  });

  final String firstName;
  final String lastName;
  final AccountBalanceSummary summary;
  final VoidCallback? onSendMoney;

  @override
  Widget build(BuildContext context) {
    final total = summary.primaryTotal;
    final account = summary.primaryAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeProfileHeader(
          firstName: firstName,
          lastName: lastName,
        ),
        const SizedBox(height: 20),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -150,
              top: 78,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: const BoxDecoration(
                    color: Color(0x333A66FF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _BankCard(
                  accountNumber: account?.accountNumber ?? 'No account available',
                  holderName: '$firstName $lastName'.trim().isEmpty
                      ? 'BankPick Customer'
                      : '$firstName $lastName'.trim(),
                  currency: total?.currency ?? account?.currency ?? 'USD',
                  balance: total?.balance ?? account?.balance ?? 0,
                ),
                const SizedBox(height: 34),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.arrow_upward,
                        label: 'Send',
                        onPressed: onSendMoney,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: _ActionButton(
                        icon: Icons.arrow_downward,
                        label: 'Receive',
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: _ActionButton(
                        icon: Icons.attach_money,
                        assetPath: 'assets/icons/dashboard/loan.png',
                        label: 'Loan',
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: _ActionButton(
                        icon: Icons.cloud_upload_outlined,
                        assetPath: 'assets/icons/dashboard/topup.png',
                        label: 'Topup',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeProfileHeader extends StatelessWidget {
  const _HomeProfileHeader({
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName'.trim();

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
            backgroundColor: const Color(0xFFF5F6FA),
            foregroundColor: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.accountNumber,
    required this.holderName,
    required this.currency,
    required this.balance,
  });

  final String accountNumber;
  final String holderName;
  final String currency;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final groupedNumber = _formatAccountNumber(accountNumber);

    return AspectRatio(
      aspectRatio: 335 / 199,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF25253D),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFF2A2C3C)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0A1027),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              right: 20,
              top: 14,
              height: 92,
              child: Opacity(
                opacity: 0.58,
                child: Image.asset(
                  'assets/images/cards/worldmap.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              left: 26,
              top: 24,
              child: Image.asset(
                'assets/icons/cards/chip.png',
                width: 34,
                height: 26,
                fit: BoxFit.contain,
              ),
            ),
            const Positioned(
              right: 25,
              top: 28,
              child: _ContactlessIcon(),
            ),
            Positioned(
              left: 26,
              right: 26,
              top: 78,
              child: Text(
                groupedNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
            Positioned(
              left: 26,
              top: 123,
              child: Text(
                holderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Positioned(
              left: 26,
              bottom: 38,
              child: Text(
                'Expiry Date',
                style: TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 11,
                ),
              ),
            ),
            const Positioned(
              left: 26,
              bottom: 18,
              child: Text(
                '24/2000',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Positioned(
              left: 112,
              bottom: 38,
              child: Text(
                'CVV',
                style: TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 11,
                ),
              ),
            ),
            const Positioned(
              left: 112,
              bottom: 18,
              child: Text(
                '6986',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              right: 26,
              bottom: 38,
              child: Image.asset(
                'assets/icons/cards/mastercard.png',
                width: 48,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const Positioned(
              right: 28,
              bottom: 15,
              child: Text(
                'Master\ncard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  height: 1.0,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              right: 26,
              top: 122,
              child: Text(
                '$currency ${_formatMoney(balance)}',
                style: const TextStyle(
                  color: Color(0xB3FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactlessIcon extends StatelessWidget {
  const _ContactlessIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 27,
      height: 26,
      child: CustomPaint(
        painter: _ContactlessPainter(),
      ),
    );
  }
}

class _ContactlessPainter extends CustomPainter {
  const _ContactlessPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x665C5A98)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    final center = Offset(0, size.height / 2);
    for (var i = 0; i < 4; i++) {
      final inset = i * 5.2;
      final rect = Rect.fromCircle(
        center: center,
        radius: 9 + inset,
      );
      canvas.drawArc(rect, -0.72, 1.44, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.summary});

  final AccountBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.primaryTotal;

    return Column(
      children: [
        Text(
          'Current Balance',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          '${total?.currency ?? 'USD'} ${_formatMoney(total?.balance ?? 0)}',
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 28),
        const _SimpleChart(),
      ],
    );
  }
}

class _SimpleChart extends StatelessWidget {
  const _SimpleChart();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEDEFF5)
      ..strokeWidth = 1;

    for (var i = 0; i < 6; i++) {
      final x = size.width * i / 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final path = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(size.width * 0.12, size.height * 0.95, size.width * 0.18, size.height * 0.2, size.width * 0.32, size.height * 0.45)
      ..cubicTo(size.width * 0.48, size.height * 0.78, size.width * 0.5, size.height * 0.05, size.width * 0.62, size.height * 0.28)
      ..cubicTo(size.width * 0.75, size.height * 0.58, size.width * 0.82, size.height * 0.15, size.width * 0.94, size.height * 0.12)
      ..cubicTo(size.width * 0.98, size.height * 0.12, size.width, size.height * 0.18, size.width, size.height * 0.18);

    final strokePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.28), 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.28),
      9,
      strokePaint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({required this.transactions});

  final List<BankTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Transaction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text('See All'),
            ),
          ],
        ),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No transactions yet.'),
          )
        else
          ...transactions.map((transaction) => _TransactionTile(transaction: transaction)),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final BankTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncoming = transaction.amount > 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF5F6FA),
        child: Icon(
          isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncoming ? AppTheme.primary : AppTheme.textMuted,
        ),
      ),
      title: Text(
        transaction.description.isEmpty ? 'Money Transfer' : transaction.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(transaction.status),
      trailing: Text(
        '${isIncoming ? '+' : '-'} \$${_formatMoney(transaction.amount.abs())}',
        style: TextStyle(
          color: isIncoming ? AppTheme.primary : AppTheme.textDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.assetPath,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFF5F6FA),
            child: assetPath == null
                ? Icon(icon, color: const Color(0xFF10163A), size: 25)
                : Image.asset(
                    assetPath!,
                    width: 25,
                    height: 25,
                    color: const Color(0xFF10163A),
                    colorBlendMode: BlendMode.srcIn,
                  ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text('$title screen will be connected next.'),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: onLogout,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    buffer.write(whole[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return '${buffer.toString()}.${parts.last}';
}

String _formatAccountNumber(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp('[^0-9]'), '');
  if (digits.length < 16) {
    return '4562  1122  4595  7852';
  }

  final cardDigits = digits.substring(0, 16);
  return '${cardDigits.substring(0, 4)}  ${cardDigits.substring(4, 8)}  '
      '${cardDigits.substring(8, 12)}  ${cardDigits.substring(12, 16)}';
}
