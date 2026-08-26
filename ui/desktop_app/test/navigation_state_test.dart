import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/core/theme_controller.dart';
import 'package:desktop_app/src/features/admin_shell/admin_shell_screen.dart';
import 'package:desktop_app/src/features/auth/auth_models.dart';
import 'package:desktop_app/src/features/auth/auth_session.dart';
import 'package:desktop_app/src/features/settings/admin_settings_controller.dart';
import 'package:desktop_app/src/features/settings/admin_settings_models.dart';
import 'package:desktop_app/src/features/settings/admin_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'lazy shell cache preserves Customers and Transactions search state',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = ApiClient(
        httpClient: MockClient((_) async => throw Exception('offline')),
      );
      final session = AuthSession(client)
        ..token = 'token'
        ..user = const AuthUser(
          id: 'admin',
          firstName: 'Admin',
          lastName: 'User',
          email: 'admin@test.com',
          role: 'Admin',
        );
      final settings = AdminSettingsController(
        AdminSettingsService(client),
        ThemeController(),
      )..settings = _settings;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminShellScreen(
            session: session,
            themeController: ThemeController(),
            settingsController: settings,
          ),
        ),
      );

      await tester.tap(find.text('Customers'));
      await tester.pump();
      final customerSearch = find.widgetWithText(
        TextField,
        'Search name, email, phone or account',
      );
      await tester.enterText(customerSearch, 'Haris');
      await tester.tap(find.text('Loans'));
      await tester.pump();
      await tester.tap(find.text('Customers'));
      await tester.pump();
      expect(find.text('Haris'), findsOneWidget);

      await tester.tap(find.text('Transactions'));
      await tester.pump();
      final transactionSearch = find.widgetWithText(
        TextField,
        'Search reference, customer or account',
      );
      await tester.enterText(transactionSearch, 'TX-2026');
      await tester.tap(find.text('Loans'));
      await tester.pump();
      await tester.tap(find.text('Transactions'));
      await tester.pump();
      expect(find.text('TX-2026'), findsOneWidget);

      await tester.tap(find.text('Card Requests'));
      await tester.pump();
      await tester.tap(find.text('Issued Cards'));
      await tester.pump();
      expect(
        find.text('Search customer, account or last four'),
        findsOneWidget,
      );
      await tester.tap(find.text('Customers'));
      await tester.pump();
      await tester.tap(find.text('Card Requests'));
      await tester.pump();
      expect(
        find.text('Search customer, account or last four'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    },
  );
}

const _settings = AdminSettings(
  system: SystemSettings(
    systemName: 'Very Long Digital Banking Administration System Name',
    systemShortName: 'DBS',
    companyName: 'Bank',
    companyEmail: 'support@test.com',
    companyPhone: '+387',
    timezone: 'Europe/Sarajevo',
    sessionTimeoutMinutes: 30,
    autoLogoutWarningMinutes: 5,
    enableDataCaching: true,
    updatedAtUtc: null,
  ),
  preferences: AdminPreferences(
    themeMode: 'light',
    sidebarStyle: 'expanded',
    dateFormat: 'DD.MM.YYYY',
    timeFormat: '24h',
    firstDayOfWeek: 'monday',
    numberFormat: '1,234.56',
    defaultItemsPerPage: 20,
    timezone: 'Europe/Sarajevo',
  ),
  profile: AdminProfile(
    firstName: 'Admin',
    lastName: 'User',
    email: 'admin@test.com',
    phoneNumber: '+387',
  ),
);
