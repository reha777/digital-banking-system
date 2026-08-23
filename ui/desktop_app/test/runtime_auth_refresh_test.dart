import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/auth/auth_models.dart';
import 'package:desktop_app/src/features/auth/auth_session.dart';
import 'package:desktop_app/src/features/auth/auth_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('401 refreshes once and retries with current token', () async {
    var protectedCalls = 0;
    var refreshCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCalls++;
        return _authResponse();
      }
      protectedCalls++;
      return request.headers['Authorization'] == 'Bearer old-access'
          ? http.Response('{}', 401)
          : http.Response('{"ok":true}', 200);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: _MemoryStorage(),
    );
    _seed(session);
    final result = await ApiClient(
      httpClient: transport,
    ).getJson('/protected', token: 'stale-page-token');
    expect(result['ok'], true);
    expect((refreshCalls, protectedCalls), (1, 2));
  });

  test('original request is retried at most once', () async {
    var protectedCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') return _authResponse();
      protectedCalls++;
      return http.Response('{}', 401);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: _MemoryStorage(),
    );
    _seed(session);
    await expectLater(
      ApiClient(httpClient: transport).getJson('/protected'),
      throwsA(isA<ApiException>()),
    );
    expect(protectedCalls, 2);
  });

  test('parallel 401 responses share one in-flight refresh', () async {
    var refreshCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _authResponse();
      }
      return request.headers['Authorization'] == 'Bearer old-access'
          ? http.Response('{}', 401)
          : http.Response('{"ok":true}', 200);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: _MemoryStorage(),
    );
    _seed(session);
    final client = ApiClient(httpClient: transport);
    await Future.wait([
      client.getJson('/1'),
      client.getJson('/2'),
      client.getJson('/3'),
    ]);
    expect(refreshCalls, 1);
  });

  test(
    'invalid refresh clears session while network failure preserves it',
    () async {
      final invalidStorage = _MemoryStorage();
      final invalidTransport = MockClient(
        (_) async => http.Response('{}', 401),
      );
      final invalid = AuthSession(
        ApiClient(httpClient: invalidTransport),
        storage: invalidStorage,
      );
      _seed(invalid);
      await expectLater(
        ApiClient(httpClient: invalidTransport).getJson('/protected'),
        throwsA(isA<ApiException>()),
      );
      expect(invalid.isAuthenticated, false);
      expect(invalidStorage.clearCalls, 1);

      final networkStorage = _MemoryStorage();
      final networkTransport = MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          throw http.ClientException('offline');
        }
        return http.Response('{}', 401);
      });
      final network = AuthSession(
        ApiClient(httpClient: networkTransport),
        storage: networkStorage,
      );
      _seed(network);
      await expectLater(
        ApiClient(httpClient: networkTransport).getJson('/protected'),
        throwsA(isA<http.ClientException>()),
      );
      expect(network.refreshToken, 'old-refresh');
      expect(networkStorage.clearCalls, 0);
    },
  );

  test('refresh endpoint cannot recursively refresh', () async {
    var calls = 0;
    final transport = MockClient((_) async {
      calls++;
      return http.Response('{}', 401);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: _MemoryStorage(),
    );
    _seed(session);
    await expectLater(session.refresh(), throwsA(isA<ApiException>()));
    expect(calls, 1);
  });
}

void _seed(AuthSession session) {
  session
    ..token = 'old-access'
    ..refreshToken = 'old-refresh'
    ..tokenExpiresAtUtc = DateTime.now().toUtc().subtract(
      const Duration(minutes: 1),
    )
    ..refreshTokenExpiresAtUtc = DateTime.now().toUtc().add(
      const Duration(days: 1),
    )
    ..user = const AuthUser(
      id: 'admin',
      firstName: 'Admin',
      lastName: 'User',
      email: 'admin@test.com',
      role: 'Admin',
    );
}

http.Response _authResponse() => http.Response(
  jsonEncode({
    'token': 'new-access',
    'tokenExpiresAtUtc': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
    'refreshToken': 'new-refresh',
    'refreshTokenExpiresAtUtc': DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .toIso8601String(),
    'user': {
      'id': 'admin',
      'firstName': 'Admin',
      'lastName': 'User',
      'email': 'admin@test.com',
      'role': 'Admin',
    },
  }),
  200,
);

class _MemoryStorage extends AuthStorage {
  _MemoryStorage()
    : super(secureStore: _EmptySecure(), legacyStore: _EmptyLegacy());
  int clearCalls = 0;
  @override
  Future<void> save(AuthResult result) async {}
  @override
  Future<void> clear() async => clearCalls++;
}

class _EmptySecure implements SecureAuthStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _EmptyLegacy implements LegacyAuthStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> delete(String key) async {}
}
