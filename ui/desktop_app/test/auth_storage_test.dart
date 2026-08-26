import 'dart:convert';

import 'package:desktop_app/src/features/auth/auth_models.dart';
import 'package:desktop_app/src/features/auth/auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemorySecureStore secure;
  late _MemoryLegacyStore legacy;
  late AuthStorage storage;

  setUp(() {
    secure = _MemorySecureStore();
    legacy = _MemoryLegacyStore();
    storage = AuthStorage(secureStore: secure, legacyStore: legacy);
  });

  test('migrates legacy session only after confirmed secure writes', () async {
    legacy.values.addAll(_values());
    expect((await storage.read())?.token, 'access');
    expect(secure.values.keys, containsAll(_values().keys));
    expect(legacy.values, isEmpty);
  });

  test('secure values have priority over legacy values', () async {
    secure.values.addAll(_values(access: 'secure'));
    legacy.values.addAll(_values(access: 'legacy'));
    expect((await storage.read())?.token, 'secure');
    expect(legacy.values, isEmpty);
  });

  test('partial migration combines secure and legacy values safely', () async {
    secure.values[AuthStorage.tokenKey] = 'secure';
    legacy.values.addAll(_values());
    final restored = await storage.read();
    expect(restored?.token, 'secure');
    expect(restored?.refreshToken, 'refresh');
    expect(legacy.values, isEmpty);
  });

  test('failed secure write preserves plaintext fallback', () async {
    legacy.values.addAll(_values());
    secure.failKey = AuthStorage.tokenKey;
    await expectLater(storage.read(), throwsStateError);
    expect(legacy.values[AuthStorage.tokenKey], 'access');
  });

  test('logout cleanup removes secure and legacy values', () async {
    secure.values.addAll(_values());
    legacy.values.addAll(_values());
    await storage.clear();
    expect(secure.values, isEmpty);
    expect(legacy.values, isEmpty);
  });
}

Map<String, String> _values({String access = 'access'}) => {
  AuthStorage.tokenKey: access,
  AuthStorage.refreshTokenKey: 'refresh',
  AuthStorage.tokenExpiresAtKey: DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 5))
      .toIso8601String(),
  AuthStorage.refreshTokenExpiresAtKey: DateTime.now()
      .toUtc()
      .add(const Duration(days: 1))
      .toIso8601String(),
  AuthStorage.userKey: jsonEncode(
    const AuthUser(
      id: 'a',
      firstName: 'Admin',
      lastName: 'User',
      email: 'admin@test.com',
      role: 'Admin',
    ).toJson(),
  ),
};

class _MemorySecureStore implements SecureAuthStore {
  final values = <String, String>{};
  String? failKey;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (key == failKey) throw StateError('secure write failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _MemoryLegacyStore implements LegacyAuthStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
}
