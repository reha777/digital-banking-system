import 'package:flutter/material.dart';

import '../../../core/formatting/date_formatters.dart';
import '../card_models.dart';

class BankCard extends StatelessWidget {
  const BankCard({super.key, this.card});

  final BankCardModel? card;

  @override
  Widget build(BuildContext context) {
    final groupedNumber = _formatCardNumber(card?.cardNumber ?? '');
    final isVisa = card?.brand == 'Visa';
    final holderName = card?.cardholderName ?? 'BankPick Customer';
    final expiry = card == null
        ? 'MM/YYYY'
        : formatCardExpiry(card!.expiryDate);
    final cvv = card?.cvv ?? '****';

    return AspectRatio(
      aspectRatio: 335 / 199,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isVisa ? const Color(0xFF292541) : const Color(0xFF25253D),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: const Color(0xFF343552)),
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
            if (!isVisa)
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
            if (!isVisa)
              Positioned(
                left: 24,
                top: 24,
                child: Image.asset(
                  'assets/icons/cards/chip.png',
                  width: 34,
                  height: 26,
                  fit: BoxFit.contain,
                ),
              )
            else
              const Positioned(
                left: 24,
                top: 24,
                child: Icon(
                  Icons.credit_card,
                  color: Color(0xFF6D7FE8),
                  size: 30,
                ),
              ),
            if (!isVisa)
              const Positioned(right: 25, top: 28, child: _ContactlessIcon()),
            Positioned(
              left: 26,
              right: 26,
              top: isVisa ? 76 : 78,
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
              top: isVisa ? 124 : 123,
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
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
            ),
            Positioned(
              left: 26,
              bottom: 18,
              child: Text(
                expiry,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!isVisa) ...[
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
                  cvv,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            Positioned(
              right: 28,
              bottom: isVisa ? 24 : 38,
              child: isVisa
                  ? const Text(
                      'VISA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Image.asset(
                      'assets/icons/cards/mastercard.png',
                      width: 48,
                      height: 30,
                      fit: BoxFit.contain,
                    ),
            ),
            if (!isVisa)
              const Positioned(
                right: 28,
                bottom: 15,
                child: Text(
                  'Mastercard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.0,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CardsGlow extends StatelessWidget {
  const CardsGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: const BoxDecoration(
        color: Color(0x333A66FF),
        shape: BoxShape.circle,
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

String _formatCardNumber(String accountNumber) {
  final digits = accountNumber.replaceAll(RegExp('[^0-9]'), '');
  if (digits.length < 16) {
    return '4562  0000  0000  0000';
  }

  final cardDigits = digits.substring(0, 16);
  return '${cardDigits.substring(0, 4)}  ${cardDigits.substring(4, 8)}  '
      '${cardDigits.substring(8, 12)}  ${cardDigits.substring(12, 16)}';
}
