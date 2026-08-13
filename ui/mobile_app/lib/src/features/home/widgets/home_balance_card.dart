import 'package:flutter/material.dart';

import '../../../core/formatting/date_formatters.dart';
import '../../../core/formatting/money_formatters.dart';
import '../../accounts/account_models.dart';
import '../../cards/card_models.dart';
import 'home_profile_header.dart';
import 'home_quick_actions.dart';

class HomeBalanceCard extends StatelessWidget {
  const HomeBalanceCard({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.summary,
    required this.card,
    required this.onSendMoney,
  });

  final String firstName;
  final String lastName;
  final AccountBalanceSummary summary;
  final BankCardModel? card;
  final VoidCallback? onSendMoney;

  @override
  Widget build(BuildContext context) {
    final total = summary.primaryTotal;
    final account = summary.primaryAccount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeProfileHeader(firstName: firstName, lastName: lastName),
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
                _HomeAccountCard(
                  card: card,
                  accountNumber:
                      account?.accountNumber ?? 'No account available',
                  holderName: '$firstName $lastName'.trim().isEmpty
                      ? 'BankPick Customer'
                      : '$firstName $lastName'.trim(),
                  currency: total?.currency ?? account?.currency ?? 'USD',
                  balance: total?.balance ?? account?.balance ?? 0,
                ),
                const SizedBox(height: 34),
                HomeQuickActions(onSendMoney: onSendMoney),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HomeAccountCard extends StatelessWidget {
  const _HomeAccountCard({
    required this.card,
    required this.accountNumber,
    required this.holderName,
    required this.currency,
    required this.balance,
  });

  final BankCardModel? card;
  final String accountNumber;
  final String holderName;
  final String currency;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final groupedNumber = _formatCardNumber(card?.cardNumber ?? accountNumber);
    final displayedHolderName = card?.cardholderName ?? holderName;
    final displayedCurrency = card?.currency ?? currency;
    final displayedBalance = card?.balance ?? balance;
    final displayedExpiry = card == null
        ? '24/2000'
        : formatCardExpiry(card!.expiryDate);
    final displayedCvv = card?.cvv ?? '6986';

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
            const Positioned(right: 25, top: 28, child: _ContactlessIcon()),
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
                ),
              ),
            ),
            Positioned(
              left: 26,
              top: 123,
              child: Text(
                displayedHolderName,
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
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
            Positioned(
              left: 26,
              bottom: 18,
              child: Text(
                displayedExpiry,
                style: const TextStyle(
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
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
            Positioned(
              left: 112,
              bottom: 18,
              child: Text(
                displayedCvv,
                style: const TextStyle(
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
                '$displayedCurrency ${formatMoney(displayedBalance)}',
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
      child: CustomPaint(painter: _ContactlessPainter()),
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
      final rect = Rect.fromCircle(center: center, radius: 9 + inset);
      canvas.drawArc(rect, -0.72, 1.44, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _formatCardNumber(String value) {
  final digits = value.replaceAll(RegExp('[^0-9]'), '');
  if (digits.length < 16) {
    return '4562  1122  4595  7852';
  }
  final cardDigits = digits.substring(0, 16);
  return '${cardDigits.substring(0, 4)}  ${cardDigits.substring(4, 8)}  '
      '${cardDigits.substring(8, 12)}  ${cardDigits.substring(12, 16)}';
}
