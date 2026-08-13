import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_storage.dart';

void main() {
  late MemorySecureStore secure;
  late MemoryLegacyStore legacy;
  late AuthStorage storage;

  setUp(() {
    secure = MemorySecureStore();
    legacy = MemoryLegacyStore();
    storage = AuthStorage(secureStore: secure, legacyStore: legacy);
  });

  test(
    'migrates a complete legacy session and removes plaintext values',
    () async {
      legacy.values.addAll(_persistedValues());

      final restored = await storage.read();

      expect(restored?.token, 'access-token');
      expect(restored?.refreshToken, 'refresh-token');
      expect(secure.values, containsPair(AuthStorage.userKey, isNotEmpty));
      expect(legacy.values, isEmpty);
    },
  );

  test('secure values win and matching legacy values are removed', () async {
    secure.values.addAll(_persistedValues(accessToken: 'secure-access'));
    legacy.values.addAll(_persistedValues(accessToken: 'legacy-access'));

    final restored = await storage.read();

    expect(restored?.token, 'secure-access');
    expect(legacy.values, isEmpty);
  });

  test('finishes a partial migration without losing the session', () async {
    secure.values[AuthStorage.tokenKey] = 'secure-access';
    legacy.values.addAll(_persistedValues());

    final restored = await storage.read();

    expect(restored?.token, 'secure-access');
    expect(restored?.refreshToken, 'refresh-token');
    expect(secure.values.keys, containsAll(_persistedValues().keys));
    expect(legacy.values, isEmpty);
  });

  test('does not remove legacy data when secure write fails', () async {
    legacy.values.addAll(_persistedValues());
    secure.failWriteKey = AuthStorage.tokenKey;

    await expectLater(storage.read(), throwsStateError);

    expect(legacy.values[AuthStorage.tokenKey], 'access-token');
  });

  test('clear removes secure and legacy auth session data', () async {
    secure.values.addAll(_persistedValues());
    legacy.values.addAll(_persistedValues());

    await storage.clear();

    expect(secure.values, isEmpty);
    expect(legacy.values, isEmpty);
  });

  test(
    'invalid or incomplete persisted data does not restore a session',
    () async {
      secure.values.addAll(_persistedValues()..remove(AuthStorage.userKey));
      expect(await storage.read(), isNull);

      secure.values[AuthStorage.userKey] = 'not-json';
      expect(await storage.read(), isNull);
    },
  );
}

Map<String, String> _persistedValues({String accessToken = 'access-token'}) {
  final user = const AuthUser(
    id: 'user-1',
    firstName: 'Test',
    lastName: 'Customer',
    email: 'test@example.com',
    role: 'Customer',
  );
  return {
    AuthStorage.tokenKey: accessToken,
    AuthStorage.refreshTokenKey: 'refresh-token',
    AuthStorage.tokenExpiresAtKey: DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
    AuthStorage.refreshTokenExpiresAtKey: DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String(),
    AuthStorage.userKey: jsonEncode(user.toJson()),
  };
}

class MemorySecureStore implements SecureAuthStore {
  final values = <String, String>{};
  String? failWriteKey;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWriteKey == key) {
      throw StateError('Secure write failed');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class MemoryLegacyStore implements LegacyAuthStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}
