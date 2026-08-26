import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../auth/auth_session.dart';
import '../card_models.dart';
import '../card_service.dart';
import '../widgets/bank_card.dart';
import '../widgets/card_requests_panel.dart';
import 'card_details_screen.dart';

class MobileCardsScreen extends StatefulWidget {
  const MobileCardsScreen({
    super.key,
    required this.session,
    required this.onRequestCard,
    this.refreshRevision = 0,
    this.cardService,
  });

  final AuthSession session;
  final Future<void> Function() onRequestCard;
  final int refreshRevision;
  final CardService? cardService;

  @override
  State<MobileCardsScreen> createState() => _MobileCardsScreenState();
}

class _MobileCardsScreenState extends State<MobileCardsScreen> {
  late final CardService _cardService;
  late Future<_CardsScreenData> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _cardService = widget.cardService ?? CardService(ApiClient());
    _cardsFuture = _loadCards();
  }

  @override
  void didUpdateWidget(covariant MobileCardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshRevision != oldWidget.refreshRevision) _refreshCards();
  }

  Future<_CardsScreenData> _loadCards() async {
    final token = widget.session.token;
    if (token == null) {
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    final cards = await _cardService.getMyCards(token);
    final requests = await _cardService.getMyRequests(token);
    return _CardsScreenData(cards: cards, requests: requests);
  }

  void _refreshCards() {
    if (!mounted) {
      return;
    }
    setState(() {
      _cardsFuture = _loadCards();
    });
  }

  Future<void> _openRequestCard() async {
    await widget.onRequestCard();
    if (!mounted) {
      return;
    }
    _refreshCards();
  }

  Future<void> _openDetails(BankCardModel card) async {
    await Navigator.of(context).push<BankCardModel>(
      PageRouteBuilder<BankCardModel>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: CardDetailsScreen(session: widget.session, card: card),
        ),
      ),
    );
    _refreshCards();
  }

  void _handleDocumentUploaded() {
    if (!mounted) {
      return;
    }
    _refreshCards();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Document uploaded.')));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          right: -190,
          top: 118,
          child: IgnorePointer(child: CardsGlow()),
        ),
        FutureBuilder<_CardsScreenData>(
          future: _cardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _CardsErrorState(
                message: snapshot.error.toString(),
                onRetry: _refreshCards,
              );
            }

            final data = snapshot.requireData;
            return RefreshIndicator(
              onRefresh: () async => _refreshCards(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                children: [
                  if (data.cards.isEmpty)
                    const _EmptyCardsState()
                  else
                    ...data.cards.map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: BankCard(
                          card: card,
                          onTap: () => _openDetails(card),
                        ),
                      ),
                    ),
                  if (data.requests.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    CardRequestsPanel(
                      requests: data.requests,
                      token: widget.session.token,
                      cardService: _cardService,
                      onDocumentUploaded: _handleDocumentUploaded,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _openRequestCard,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Card'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CardsScreenData {
  const _CardsScreenData({required this.cards, required this.requests});

  final List<BankCardModel> cards;
  final List<CardRequestModel> requests;
}

class _EmptyCardsState extends StatelessWidget {
  const _EmptyCardsState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.credit_card_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text('No cards yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Request a card and admin will review it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CardsErrorState extends StatelessWidget {
  const _CardsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
