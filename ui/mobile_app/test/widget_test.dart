import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('shows onboarding call to action', (WidgetTester tester) async {
    await tester.pumpWidget(const BankingMobileApp());

    expect(find.text('BANKPICK'), findsOneWidget);
  });
}
