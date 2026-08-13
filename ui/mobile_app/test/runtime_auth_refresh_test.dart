import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/src/core/api_client.dart';
import 'package:mobile_app/src/features/auth/auth_models.dart';
import 'package:mobile_app/src/features/auth/auth_session.dart';
import 'package:mobile_app/src/features/auth/auth_storage.dart';

void main() {
  test(
    '401 refreshes session and retries once with the new access token',
    () async {
      var protectedCalls = 0;
      var refreshCalls = 0;
      final storage = MemoryAuthStorage();
      late AuthSession session;
      final transport = MockClient((request) async {
        if (request.url.path == '/api/auth/refresh') {
          refreshCalls++;
          return _authResponse();
        }
        protectedCalls++;
        if (request.headers['Authorization'] == 'Bearer old-access') {
          return http.Response('{}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-access');
        return http.Response('{"ok":true}', 200);
      });
      final authClient = ApiClient(httpClient: transport);
      session = AuthSession(authClient, storage: storage)..token = 'old-access';
      _seedSession(session);

      final result = await ApiClient(
        httpClient: transport,
      ).getJson('/protected', token: 'old-access');

      expect(result['ok'], isTrue);
      expect(refreshCalls, 1);
      expect(protectedCalls, 2);
      expect(session.token, 'new-access');
      expect(storage.saved?.refreshToken, 'new-refresh');
    },
  );

  test('original request is retried at most once', () async {
    var protectedCalls = 0;
    var refreshCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCalls++;
        return _authResponse();
      }
      protectedCalls++;
      return http.Response('{}', 401);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: MemoryAuthStorage(),
    );
    _seedSession(session);

    await expectLater(
      ApiClient(
        httpClient: transport,
      ).getJson('/protected', token: 'old-access'),
      throwsA(isA<ApiException>()),
    );
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
  });

  test('POST retry preserves method, JSON body, and content type', () async {
    var protectedCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        return _authResponse();
      }

      protectedCalls++;
      expect(request.method, 'POST');
      expect(request.headers['content-type'], 'application/json');
      expect(jsonDecode(request.body), {'amount': 25, 'note': 'test'});
      if (request.headers['Authorization'] == 'Bearer old-access') {
        return http.Response('{}', 401);
      }
      expect(request.headers['Authorization'], 'Bearer new-access');
      return http.Response('{"ok":true}', 200);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: MemoryAuthStorage(),
    );
    _seedSession(session);

    final result = await ApiClient(httpClient: transport).postJson(
      '/protected',
      {'amount': 25, 'note': 'test'},
      token: 'old-access',
    );

    expect(result['ok'], isTrue);
    expect(protectedCalls, 2);
  });

  test('parallel 401 responses share one refresh request', () async {
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
      storage: MemoryAuthStorage(),
    );
    _seedSession(session);
    final client = ApiClient(httpClient: transport);

    final results = await Future.wait([
      client.getJson('/one', token: 'old-access'),
      client.getJson('/two', token: 'old-access'),
      client.getJson('/three', token: 'old-access'),
    ]);

    expect(results.every((item) => item['ok'] == true), isTrue);
    expect(refreshCalls, 1);
  });

  test('invalid refresh clears runtime and persisted session', () async {
    final storage = MemoryAuthStorage();
    final transport = MockClient((request) async => http.Response('{}', 401));
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: storage,
    );
    _seedSession(session);

    await expectLater(
      ApiClient(
        httpClient: transport,
      ).getJson('/protected', token: 'old-access'),
      throwsA(isA<ApiException>()),
    );
    expect(session.isAuthenticated, isFalse);
    expect(storage.clearCalls, 1);
  });

  test('refresh network failure preserves the refresh session', () async {
    final storage = MemoryAuthStorage();
    var refreshCalls = 0;
    final transport = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCalls++;
        throw http.ClientException('offline');
      }
      return http.Response('{}', 401);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: storage,
    );
    _seedSession(session);

    await expectLater(
      ApiClient(
        httpClient: transport,
      ).getJson('/protected', token: 'old-access'),
      throwsA(isA<http.ClientException>()),
    );
    expect(refreshCalls, 1);
    expect(session.refreshToken, 'old-refresh');
    expect(storage.clearCalls, 0);
  });

  test('refresh endpoint 401 is not recursively refreshed', () async {
    var refreshCalls = 0;
    final transport = MockClient((request) async {
      refreshCalls++;
      return http.Response('{}', 401);
    });
    final session = AuthSession(
      ApiClient(httpClient: transport),
      storage: MemoryAuthStorage(),
    );
    _seedSession(session);

    await expectLater(session.refresh(), throwsA(isA<ApiException>()));
    expect(refreshCalls, 1);
  });
}

void _seedSession(AuthSession session) {
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
      id: 'user-1',
      firstName: 'Test',
      lastName: 'Customer',
      email: 'test@example.com',
      role: 'Customer',
    );
}

http.Response _authResponse() {
  return http.Response(
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
        'id': 'user-1',
        'firstName': 'Test',
        'lastName': 'Customer',
        'email': 'test@example.com',
        'role': 'Customer',
      },
    }),
    200,
  );
}

class MemoryAuthStorage extends AuthStorage {
  MemoryAuthStorage()
    : super(secureStore: _EmptySecureStore(), legacyStore: _EmptyLegacyStore());

  AuthResult? saved;
  int clearCalls = 0;

  @override
  Future<void> save(AuthResult result) async => saved = result;

  @override
  Future<void> clear() async => clearCalls++;
}

class _EmptySecureStore implements SecureAuthStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _EmptyLegacyStore implements LegacyAuthStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> delete(String key) async {}
}
