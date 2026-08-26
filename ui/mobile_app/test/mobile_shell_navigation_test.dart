import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_app/src/core/app_theme.dart';
import 'package:mobile_app/src/widgets/mobile_shell.dart';

void main() {
  testWidgets('global tab selection closes a nested flow and shows tab root', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));

    await tester.tap(find.text('Open Send Money'));
    await tester.pumpAndSettle();
    expect(find.text('Send Money flow'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-bottom-navigation')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home root'), findsOneWidget);

    await tester.tap(find.text('Open Send Money'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Statistics root'), findsOneWidget);
    expect(find.text('Send Money flow'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home root'), findsOneWidget);
    expect(find.text('Send Money flow'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Send Money flow'), findsNothing);
  });

  testWidgets(
    'receive, transfer, cards and settings obey global root behavior',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));

      await tester.tap(find.text('Open Receive'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mobile-bottom-navigation')),
        findsOneWidget,
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings root'), findsOneWidget);

      await tester.tap(find.text('Open Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings root'), findsOneWidget);
      expect(find.text('Profile flow'), findsNothing);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Transfer'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mobile-bottom-navigation')),
        findsOneWidget,
      );
      await tester.tap(find.text('My Cards'));
      await tester.pumpAndSettle();
      expect(find.text('Cards root'), findsOneWidget);

      await tester.tap(find.text('Open Card Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Cards'));
      await tester.pumpAndSettle();
      expect(find.text('Cards root'), findsOneWidget);
      expect(find.text('Card Details flow'), findsNothing);
    },
  );

  testWidgets('bottom navigation uses four Lucide icons and selected styling', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));

    expect(find.byIcon(LucideIcons.house), findsOneWidget);
    expect(find.byIcon(LucideIcons.creditCard), findsOneWidget);
    expect(find.byIcon(LucideIcons.chartNoAxesCombined), findsOneWidget);
    expect(find.byIcon(LucideIcons.settings), findsOneWidget);

    Icon home = tester.widget(find.byIcon(LucideIcons.house));
    expect(home.color, AppTheme.primary);
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    home = tester.widget(find.byIcon(LucideIcons.house));
    final statistics = tester.widget<Icon>(
      find.byIcon(LucideIcons.chartNoAxesCombined),
    );
    expect(home.color, AppTheme.textMuted);
    expect(statistics.color, AppTheme.primary);
  });

  testWidgets('root tabs render exclusively through repeated tab changes', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));

    for (final label in [
      'Statistics',
      'My Cards',
      'Settings',
      'Home',
      'Statistics',
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    expect(find.text('Statistics root'), findsOneWidget);
    expect(find.text('Home root'), findsNothing);
    expect(find.text('Cards root'), findsNothing);
    expect(find.text('Settings root'), findsNothing);
    expect(find.text('CardCarousel marker'), findsNothing);
    expect(find.text('Add Card'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-bottom-navigation')),
      findsOneWidget,
    );
  });

  testWidgets('mixed root and feature navigation never duplicates the navbar', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));

    for (final action in [
      'Statistics',
      'Home',
      'Open Send Money',
      'Settings',
    ]) {
      await tester.tap(find.text(action));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mobile-bottom-navigation')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    expect(find.text('Settings root'), findsOneWidget);
    expect(find.text('Send Money flow'), findsNothing);
    expect(find.text('Home root'), findsNothing);
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('bottom navigation has no overflow at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));
      expect(tester.takeException(), isNull);
      expect(find.text('Statistics'), findsOneWidget);
    });
  }

  testWidgets('navigation supports dark theme and hides for the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const MediaQuery(
          data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
          child: _NavigationHarness(),
        ),
      ),
    );
    expect(find.text('Statistics'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness();

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _selected = ValueNotifier<int>(0);
  int _index = 0;

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  void _select(int index) {
    _navigatorKey.currentState!.popUntil((route) => route.isFirst);
    if (_index == index) return;
    setState(() {
      _index = index;
      _selected.value = index;
    });
  }

  void _open(String label) {
    _navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(builder: (_) => Center(child: Text(label))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileShell(
      currentIndex: _index,
      onSelected: _select,
      child: NavigatorPopHandler<void>(
        onPopWithResult: (_) => _navigatorKey.currentState!.maybePop(),
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ValueListenableBuilder<int>(
              valueListenable: _selected,
              builder: (_, index, _) => MobileTabStack(
                currentIndex: index,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Home root'),
                      const Text('CardCarousel marker'),
                      TextButton(
                        onPressed: () => _open('Send Money flow'),
                        child: const Text('Open Send Money'),
                      ),
                      TextButton(
                        onPressed: () => _open('Receive flow'),
                        child: const Text('Open Receive'),
                      ),
                      TextButton(
                        onPressed: () => _open('Transfer flow'),
                        child: const Text('Open Transfer'),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Cards root'),
                      const Text('Add Card'),
                      TextButton(
                        onPressed: () => _open('Card Details flow'),
                        child: const Text('Open Card Details'),
                      ),
                    ],
                  ),
                  const Center(child: Text('Statistics root')),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Settings root'),
                      TextButton(
                        onPressed: () => _open('Profile flow'),
                        child: const Text('Open Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
