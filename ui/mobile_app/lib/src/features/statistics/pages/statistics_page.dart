import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../../accounts/account_service.dart';
import '../../auth/auth_session.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final Future<AccountBalanceSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    final token = widget.session.token;
    _summaryFuture = token == null
        ? Future.error(
            ApiException('Sesija je istekla. Prijavite se ponovo.', 401),
          )
        : AccountService(ApiClient()).getBalanceSummary(token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountBalanceSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(
            snapshot.error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return _StatisticsCard(summary: snapshot.requireData);
      },
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({required this.summary});

  final AccountBalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.primaryTotal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          'Current Balance',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        Text(
          '${total?.currency ?? 'USD'} ${formatMoney(total?.balance ?? 0)}',
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textDark,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          height: 190,
          width: double.infinity,
          child: CustomPaint(painter: _ChartPainter()),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter();

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
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.95,
        size.width * 0.18,
        size.height * 0.2,
        size.width * 0.32,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height * 0.78,
        size.width * 0.5,
        size.height * 0.05,
        size.width * 0.62,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.75,
        size.height * 0.58,
        size.width * 0.82,
        size.height * 0.15,
        size.width * 0.94,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.98,
        size.height * 0.12,
        size.width,
        size.height * 0.18,
        size.width,
        size.height * 0.18,
      );
    final strokePaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.28),
      9,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.28),
      9,
      strokePaint..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
