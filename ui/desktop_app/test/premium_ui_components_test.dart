import 'package:desktop_app/src/core/app_theme.dart';
import 'package:desktop_app/src/features/admin_shell/widgets/admin_account_menu.dart';
import 'package:desktop_app/src/features/admin_shell/widgets/admin_avatar.dart';
import 'package:desktop_app/src/features/auth/auth_models.dart';
import 'package:desktop_app/src/widgets/app_segmented_control.dart';
import 'package:desktop_app/src/widgets/app_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin avatar uses initials when profile photo is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminAvatar(
            user: AuthUser(
              id: '1',
              firstName: 'Desktop',
              lastName: 'Admin',
              email: 'admin@example.com',
              role: 'Admin',
            ),
            radius: 20,
          ),
        ),
      ),
    );

    expect(find.text('DA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin avatar uses authenticated cache-busted photo resource', (
    tester,
  ) async {
    final version = DateTime.utc(2026, 8, 23, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminAvatar(
            user: AuthUser(
              id: '1',
              firstName: 'Desktop',
              lastName: 'Admin',
              email: 'admin@example.com',
              role: 'Admin',
              hasProfilePhoto: true,
              profilePhotoUpdatedAtUtc: version,
            ),
            token: 'access-token',
            radius: 20,
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(provider.url, contains('/api/admin/settings/profile/photo?v='));
    expect(provider.headers?['Authorization'], 'Bearer access-token');
  });

  testWidgets('premium segmented control changes selection', (tester) async {
    var selected = 'light';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AppSegmentedControl<String>(
              value: selected,
              segments: const [
                AppSegment(value: 'light', label: 'Light'),
                AppSegment(value: 'dark', label: 'Dark'),
              ],
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(selected, 'dark');
    expect(tester.takeException(), isNull);
  });

  testWidgets('account popover exposes profile metadata and actions', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: AdminAccountMenu(
              user: const AuthUser(
                id: '1',
                firstName: 'Desktop',
                lastName: 'Admin',
                email: 'admin@example.com',
                role: 'Administrator',
              ),
              showDetails: true,
              onProfile: () {},
              onPreferences: () {},
              onSecurity: () {},
              onLogout: () => loggedOut = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Account menu'));
    await tester.pumpAndSettle();

    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
  });

  testWidgets('account popover toggles, dismisses and fits narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var profileOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: AdminAccountMenu(
              user: const AuthUser(
                id: '1',
                firstName: 'Desktop',
                lastName: 'Admin',
                email: 'admin@example.com',
                role: 'Administrator',
              ),
              showDetails: true,
              onProfile: () => profileOpened = true,
              onPreferences: () {},
              onSecurity: () {},
              onLogout: () {},
            ),
          ),
        ),
      ),
    );

    final trigger = find.byTooltip('Account menu');
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(trigger, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 400));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNothing);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(profileOpened, isTrue);
    expect(find.text('Profile'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modern dropdown opens below its visible field', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 'DD.MM.YYYY';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: AppDropdownField<String>(
                  key: const Key('date-dropdown'),
                  label: 'Date Format',
                  value: selected,
                  items: const [
                    AppDropdownItem(value: 'DD.MM.YYYY', label: 'DD.MM.YYYY'),
                    AppDropdownItem(value: 'DD/MM/YYYY', label: 'DD/MM/YYYY'),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byKey(const Key('date-dropdown'));
    final fieldRect = tester.getRect(field);
    await tester.tap(field);
    await tester.pumpAndSettle();

    final option = find.text('DD/MM/YYYY');
    expect(option, findsOneWidget);
    expect(tester.getRect(option).top, greaterThan(fieldRect.bottom));
    expect(tester.takeException(), isNull);

    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(selected, 'DD/MM/YYYY');
  });
}
