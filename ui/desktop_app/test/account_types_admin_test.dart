import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/core/theme_controller.dart';
import 'package:desktop_app/src/features/account_types/account_type_service.dart';
import 'package:desktop_app/src/features/account_types/account_types_page.dart';
import 'package:desktop_app/src/features/admin_shell/admin_shell_screen.dart';
import 'package:desktop_app/src/features/auth/auth_models.dart';
import 'package:desktop_app/src/features/auth/auth_session.dart';
import 'package:desktop_app/src/features/settings/admin_settings_controller.dart';
import 'package:desktop_app/src/features/settings/admin_settings_models.dart';
import 'package:desktop_app/src/features/settings/admin_settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('admin navigation exposes the Account Types section', (
    tester,
  ) async {
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

    expect(find.text('Account Types'), findsOneWidget);
    await tester.tap(find.text('Account Types'));
    await tester.pump();

    expect(find.byType(AccountTypesPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders dynamic reference data without legacy enum mapping', (
    tester,
  ) async {
    final backend = _AccountTypeBackend();
    await _pumpPage(tester, backend);

    expect(find.text('Code'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);

    expect(find.text('CHECKING'), findsOneWidget);
    expect(find.text('Checking'), findsOneWidget);
    expect(find.text('SAVINGS'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('BUSINESS'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);

    expect(find.text('Active'), findsNWidgets(2));
    expect(find.text('Inactive'), findsOneWidget);

    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(backend.requests.single.url.path, '/api/admin/account-types');
  });

  testWidgets('create validates input, posts the new type and refreshes', (
    tester,
  ) async {
    final backend = _AccountTypeBackend();
    await _pumpPage(tester, backend);

    await tester.tap(find.text('Add Account Type'));
    await tester.pumpAndSettle();
    expect(find.text('Create account type'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('Code and name are required.'), findsOneWidget);
    expect(backend.writes, isEmpty);

    await tester.enterText(_dialogFields.at(0), 'PREMIUM');
    await tester.enterText(_dialogFields.at(1), 'Premium');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create account type'), findsNothing);
    expect(find.text('Account type created.'), findsOneWidget);
    expect(backend.writes.single.method, 'POST');
    expect(backend.writes.single.url.path, '/api/admin/account-types');
    expect(jsonDecode(backend.writes.single.body), {
      'code': 'PREMIUM',
      'name': 'Premium',
    });
    expect(find.text('PREMIUM'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    await _settleSnackBar(tester);
  });

  testWidgets('create surfaces the API error and keeps the dialog open', (
    tester,
  ) async {
    final backend = _AccountTypeBackend()
      ..writeStatus = 409
      ..writeMessage = 'Account type code already exists.';
    await _pumpPage(tester, backend);

    await tester.tap(find.text('Add Account Type'));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogFields.at(0), 'CHECKING');
    await tester.enterText(_dialogFields.at(1), 'Checking');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Account type code already exists.'), findsOneWidget);
    expect(find.text('Create account type'), findsOneWidget);
  });

  testWidgets('edit keeps the code read-only and renames the type', (
    tester,
  ) async {
    final backend = _AccountTypeBackend();
    await _pumpPage(tester, backend);

    await tester.tap(find.byTooltip('Edit').at(2));
    await tester.pumpAndSettle();

    expect(find.text('Edit account type'), findsOneWidget);
    expect(tester.widget<TextField>(_dialogFields.at(0)).readOnly, isTrue);
    expect(tester.widget<TextField>(_dialogFields.at(1)).readOnly, isFalse);
    expect(find.text('Code cannot be changed after creation.'), findsOneWidget);

    await tester.enterText(_dialogFields.at(1), 'Business Account');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(backend.writes.single.method, 'PUT');
    expect(
      backend.writes.single.url.path,
      '/api/admin/account-types/type-business',
    );
    expect(jsonDecode(backend.writes.single.body), {
      'name': 'Business Account',
    });
    expect(find.text('Business Account'), findsOneWidget);
    expect(find.text('BUSINESS'), findsOneWidget);
    expect(find.text('Account type updated.'), findsOneWidget);
    await _settleSnackBar(tester);
  });

  testWidgets('deactivate confirms first and then refreshes the status', (
    tester,
  ) async {
    final backend = _AccountTypeBackend();
    await _pumpPage(tester, backend);

    await tester.tap(find.text('Deactivate').first);
    await tester.pumpAndSettle();
    expect(find.text('Deactivate account type?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(backend.writes, isEmpty);
    expect(find.text('Active'), findsNWidgets(2));

    await tester.tap(find.text('Deactivate').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(backend.writes.single.method, 'POST');
    expect(
      backend.writes.single.url.path,
      '/api/admin/account-types/type-checking/deactivate',
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsNWidgets(2));
    expect(find.text('Account type deactivated.'), findsOneWidget);
    await _settleSnackBar(tester);
  });

  testWidgets('activate calls the lifecycle endpoint without confirmation', (
    tester,
  ) async {
    final backend = _AccountTypeBackend();
    await _pumpPage(tester, backend);

    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(backend.writes.single.method, 'POST');
    expect(
      backend.writes.single.url.path,
      '/api/admin/account-types/type-business/activate',
    );
    expect(find.text('Active'), findsNWidgets(3));
    expect(find.text('Inactive'), findsNothing);
    expect(find.text('Account type activated.'), findsOneWidget);
    await _settleSnackBar(tester);
  });

  testWidgets('list failure shows an error state with retry', (tester) async {
    final backend = _AccountTypeBackend()..listStatus = 500;
    await _pumpPage(tester, backend);

    expect(find.text('Account types could not be loaded.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    backend.listStatus = 200;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('CHECKING'), findsOneWidget);
  });
}

/// Lets the success SnackBar expire so no timer outlives the test.
Future<void> _settleSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

final _dialogFields = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Future<void> _pumpPage(WidgetTester tester, _AccountTypeBackend backend) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AccountTypesPage(token: 'token', service: backend.service),
    ),
  );
  await tester.pumpAndSettle();
}

class _AccountTypeBackend {
  _AccountTypeBackend();

  final List<Map<String, dynamic>> items = [
    {
      'id': 'type-checking',
      'code': 'CHECKING',
      'name': 'Checking',
      'isActive': true,
    },
    {
      'id': 'type-savings',
      'code': 'SAVINGS',
      'name': 'Savings',
      'isActive': true,
    },
    {
      'id': 'type-business',
      'code': 'BUSINESS',
      'name': 'Business',
      'isActive': false,
    },
  ];
  final List<http.Request> requests = [];
  int listStatus = 200;
  int writeStatus = 200;
  String writeMessage = 'Request failed.';

  List<http.Request> get writes =>
      requests.where((request) => request.method != 'GET').toList();

  AccountTypeService get service =>
      AccountTypeService(ApiClient(httpClient: MockClient(_handle)));

  Map<String, dynamic> _byId(String id) =>
      items.firstWhere((item) => item['id'] == id);

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final segments = request.url.pathSegments;
    if (request.method == 'GET') {
      return listStatus == 200
          ? http.Response(jsonEncode(items), 200)
          : http.Response(jsonEncode({'message': 'boom'}), listStatus);
    }
    if (writeStatus != 200) {
      return http.Response(jsonEncode({'message': writeMessage}), writeStatus);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.method == 'PUT') {
      _byId(segments.last)['name'] = body['name'];
    } else if (segments.last == 'activate') {
      _byId(segments[segments.length - 2])['isActive'] = true;
    } else if (segments.last == 'deactivate') {
      _byId(segments[segments.length - 2])['isActive'] = false;
    } else {
      items.add({
        'id': 'type-${body['code']}',
        'code': body['code'],
        'name': body['name'],
        'isActive': true,
      });
    }
    return http.Response(jsonEncode(const <String, dynamic>{}), 200);
  }
}

const _settings = AdminSettings(
  system: SystemSettings(
    systemName: 'Digital Banking Administration',
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
