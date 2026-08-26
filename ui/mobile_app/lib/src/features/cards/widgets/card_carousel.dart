import 'package:flutter/material.dart';

import '../card_models.dart';
import 'bank_card.dart';

class CardCarousel extends StatefulWidget {
  const CardCarousel({
    super.key,
    required this.cards,
    required this.onCardChanged,
    this.onCardTap,
    this.initialIndex = 0,
  });

  final List<BankCardModel> cards;
  final int initialIndex;
  final ValueChanged<int> onCardChanged;
  final ValueChanged<BankCardModel>? onCardTap;

  @override
  State<CardCarousel> createState() => _CardCarouselState();
}

class _CardCarouselState extends State<CardCarousel> {
  late final PageController _controller;
  late double _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.toDouble();
    _controller = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: widget.cards.length > 1 ? .92 : 1,
    )..addListener(_changed);
  }

  void _changed() {
    if (_controller.hasClients) setState(() => _page = _controller.page ?? 0);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 335 / 215,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.cards.length,
          onPageChanged: widget.onCardChanged,
          itemBuilder: (context, index) {
            final distance = (_page - index).abs().clamp(0.0, 1.0);
            final scale = 1 - (distance * .055);
            final verticalOffset = distance * 8;
            final card = widget.cards[index];
            return Transform.translate(
              offset: Offset(0, verticalOffset),
              child: Transform.scale(
                scale: scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: BankCard(
                    card: card,
                    onTap: widget.onCardTap == null
                        ? null
                        : () => widget.onCardTap!(card),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      if (widget.cards.length > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.cards.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page.round() == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _page.round() == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
    ],
  );
}
