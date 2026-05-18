import 'package:desktop_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows admin login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BankingDesktopApp());

    expect(find.text('Admin Sign In'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsNothing);
  });
}
