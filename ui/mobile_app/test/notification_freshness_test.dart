import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/cards/card_models.dart';
import 'package:mobile_app/src/features/cards/card_service.dart';
import 'package:mobile_app/src/features/cards/pages/cards_screen.dart';

void main() {
  testWidgets(
    'card request notification refresh does not return a Future from setState',
    (tester) async {
      final service = _CountingCardService();
      final session = AuthSession(ApiClient())..token = 'token';

      Widget page(int revision) => MaterialApp(
        home: Scaffold(
          body: MobileCardsScreen(
            session: session,
            onRequestCard: () async {},
            refreshRevision: revision,
            cardService: service,
          ),
        ),
      );

      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(service.cardsLoads, 1);
      expect(service.requestLoads, 1);

      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();
      expect(service.cardsLoads, 2);
      expect(service.requestLoads, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CountingCardService extends CardService {
  _CountingCardService() : super(ApiClient());

  int cardsLoads = 0;
  int requestLoads = 0;

  @override
  Future<List<BankCardModel>> getMyCards(String token) async {
    cardsLoads++;
    return const [];
  }

  @override
  Future<List<CardRequestModel>> getMyRequests(String token) async {
    requestLoads++;
    return const [];
  }
}
