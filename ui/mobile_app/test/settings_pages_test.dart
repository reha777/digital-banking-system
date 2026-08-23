import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/theme_controller.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/settings/pages/change_password_page.dart';
import 'package:mobile_app/src/features/settings/pages/language_page.dart';
import 'package:mobile_app/src/features/settings/pages/personal_information_page.dart';
import 'package:mobile_app/src/features/settings/pages/settings_page.dart';
import 'package:mobile_app/src/features/settings/settings_service.dart';
import 'package:mobile_app/src/features/settings/profile_photo_picker.dart';
import 'package:mobile_app/src/features/home/widgets/home_profile_header.dart';
import 'package:mobile_app/src/features/settings/pages/profile_page.dart';
import 'package:mobile_app/src/widgets/profile_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testUser = AuthUser(
  id: 'customer-1',
  firstName: 'Amina',
  lastName: 'Hadzic',
  email: 'amina@example.com',
  role: 'Customer',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('settings renders required sections and existing controls', (
    tester,
  ) async {
    await _pumpSettings(tester);

    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('settings navigates to language and supports search/selection', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePage), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('language-search')),
      'Bos',
    );
    await tester.pump();
    expect(find.text('Bosnian'), findsOneWidget);
    expect(find.text('English'), findsNothing);

    await tester.tap(find.text('Bosnian'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('language-bs')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('settings profile uses the authenticated customer', (
    tester,
  ) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Amina Hadzic'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Tanya Myroniuk'), findsNothing);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Address'), findsNothing);
    expect(find.text('API required'), findsOneWidget);
  });

  testWidgets('settings navigates to change password', (tester) async {
    await _pumpSettings(tester);
    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
  });

  testWidgets('change password validates required and matching values', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChangePasswordPage()));
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(3));

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('current-password')),
        matching: find.byType(TextFormField),
      ),
      'current',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('new-password')),
        matching: find.byType(TextFormField),
      ),
      'new-password',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('confirm-password')),
        matching: find.byType(TextFormField),
      ),
      'different',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pump();
    expect(find.text('Passwords must match'), findsOneWidget);
  });

  testWidgets('change password prevents double submit while loading', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordPage(
          onSubmit: (_, _) {
            calls++;
            return completion.future;
          },
        ),
      ),
    );
    for (final key in const [
      'current-password',
      'new-password',
      'confirm-password',
    ]) {
      await tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TextFormField),
        ),
        'valid-password',
      );
    }
    final submit = find.byKey(const ValueKey('change-password-submit'));
    await tester.tap(submit);
    await tester.pump();
    await tester.tap(submit);
    expect(calls, 1);
    expect(find.byKey(const ValueKey('loading')), findsOneWidget);
    completion.complete();
    await tester.pumpAndSettle();
  });

  test('customer profile parses typed backend data', () {
    final profile = CustomerProfile.fromJson({
      'id': 'customer-1',
      'firstName': 'Amina',
      'lastName': 'Hadzic',
      'email': 'amina@example.com',
      'phoneNumber': '+38761123456',
      'role': 'Customer',
    });
    expect(profile.toAuthUser().phoneNumber, '+38761123456');
  });

  testWidgets('profile save tracks dirty state and reports success', (
    tester,
  ) async {
    var saves = 0;
    final profile = CustomerProfile(
      id: testUser.id,
      firstName: testUser.firstName,
      lastName: testUser.lastName,
      email: testUser.email,
      phoneNumber: '+38761000000',
      role: testUser.role,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PersonalInformationPage(
          profile: profile,
          onSave:
              ({
                required firstName,
                required lastName,
                required phoneNumber,
              }) async {
                saves++;
                return CustomerProfile(
                  id: profile.id,
                  firstName: firstName.trim(),
                  lastName: lastName.trim(),
                  email: profile.email,
                  phoneNumber: phoneNumber.trim(),
                  role: profile.role,
                );
              },
        ),
      ),
    );

    final save = find.byKey(const ValueKey('profile-save'));
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('profile-first-name')),
        matching: find.byType(TextFormField),
      ),
      'Updated',
    );
    await tester.pump();
    expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Profile updated successfully.'), findsOneWidget);
  });

  testWidgets('home profile header renders real initials and opens Profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return HomeProfileHeader(
              firstName: 'Demo',
              lastName: 'Customer',
              hasProfilePhoto: false,
              accessToken: null,
              onProfileTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfilePage(user: testUser),
                ),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('DC'), findsOneWidget);
    expect(find.text('Demo Customer'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-avatar-tap')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('profile avatar uses photo state when reference exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileAvatar(
          firstName: 'Demo',
          lastName: 'Customer',
          hasProfilePhoto: true,
          accessToken: 'token',
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  test('profile photo validation rejects type and oversized bytes', () {
    expect(
      () => validateProfilePhoto('avatar.pdf', Uint8List.fromList([1])),
      throwsA(isA<ProfilePhotoPickerException>()),
    );
    expect(
      () => validateProfilePhoto(
        'avatar.png',
        Uint8List(maximumProfilePhotoSizeBytes + 1),
      ),
      throwsA(isA<ProfilePhotoPickerException>()),
    );
  });

  testWidgets('successful photo upload updates Profile photo state', (
    tester,
  ) async {
    final service = _PhotoSettingsService(succeeds: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          user: testUser,
          service: service,
          accessToken: 'token',
          photoPicker: () async => PickedProfilePhoto(
            fileName: 'avatar.png',
            bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-profile-photo')));
    await tester.pumpAndSettle();

    expect(service.uploadCalls, 1);
    expect(find.text('Change Photo'), findsOneWidget);
    expect(find.text('Profile photo updated.'), findsOneWidget);
  });

  testWidgets('failed photo upload keeps existing photo state', (tester) async {
    final service = _PhotoSettingsService(
      succeeds: false,
      initiallyHasPhoto: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          user: const AuthUser(
            id: 'customer-1',
            firstName: 'Amina',
            lastName: 'Hadzic',
            email: 'amina@example.com',
            role: 'Customer',
            hasProfilePhoto: true,
          ),
          service: service,
          accessToken: 'token',
          photoPicker: () async => PickedProfilePhoto(
            fileName: 'avatar.png',
            bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-profile-photo')));
    await tester.pumpAndSettle();

    expect(find.text('Change Photo'), findsOneWidget);
    expect(find.text('Profile photo could not be updated.'), findsOneWidget);
  });
}

class _PhotoSettingsService extends SettingsService {
  _PhotoSettingsService({
    required this.succeeds,
    this.initiallyHasPhoto = false,
  }) : super(ApiClient(), AuthSession(ApiClient()));

  final bool succeeds;
  final bool initiallyHasPhoto;
  int uploadCalls = 0;

  CustomerProfile get _profile => CustomerProfile(
    id: testUser.id,
    firstName: testUser.firstName,
    lastName: testUser.lastName,
    email: testUser.email,
    phoneNumber: '',
    role: testUser.role,
    hasProfilePhoto: initiallyHasPhoto,
    profilePhotoUpdatedAtUtc: initiallyHasPhoto ? DateTime.utc(2026) : null,
  );

  @override
  Future<CustomerProfile> getProfile() async => _profile;

  @override
  Future<CustomerProfile> uploadProfilePhoto({
    required String fileName,
    required Uint8List bytes,
  }) async {
    uploadCalls++;
    if (!succeeds) throw ApiException('Upload failed', 400);
    return CustomerProfile(
      id: _profile.id,
      firstName: _profile.firstName,
      lastName: _profile.lastName,
      email: _profile.email,
      phoneNumber: _profile.phoneNumber,
      role: _profile.role,
      hasProfilePhoto: true,
      profilePhotoUpdatedAtUtc: DateTime.utc(2026, 8, 14),
    );
  }
}

Future<void> _pumpSettings(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SettingsPage(
            themeController: ThemeController(),
            user: testUser,
          ),
        ),
      ),
    ),
  );
}
