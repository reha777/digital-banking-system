import '../../core/api_client.dart';
import 'auth_models.dart';
import 'auth_storage.dart';

class AuthSession {
  AuthSession(this._apiClient, {AuthStorage? storage}) : _storage = storage ?? AuthStorage();

  final ApiClient _apiClient;
  final AuthStorage _storage;

  String? token;
  String? refreshToken;
  DateTime? tokenExpiresAtUtc;
  DateTime? refreshTokenExpiresAtUtc;
  AuthUser? user;

  bool get isAuthenticated => token != null && user != null;

  Future<void> initialize() async {
    final stored = await _storage.read();
    if (stored == null || stored.refreshTokenExpiresAtUtc.isBefore(DateTime.now().toUtc())) {
      await _storage.clear();
      return;
    }

    if (stored.user.role != 'Admin') {
      await _storage.clear();
      return;
    }

    token = stored.token;
    refreshToken = stored.refreshToken;
    tokenExpiresAtUtc = stored.tokenExpiresAtUtc;
    refreshTokenExpiresAtUtc = stored.refreshTokenExpiresAtUtc;
    user = stored.user;

    if (tokenExpiresAtUtc!.isBefore(DateTime.now().toUtc().add(const Duration(minutes: 1)))) {
      await refresh();
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/api/auth/login', {
      'email': email,
      'password': password,
    });

    final result = AuthResult.fromJson(json);
    if (result.user.role != 'Admin') {
      throw ApiException('Nemate pravo pristupa desktop administraciji.', 403);
    }

    return _applyAdmin(result);
  }

  Future<void> refresh() async {
    final currentRefreshToken = refreshToken;
    if (currentRefreshToken == null) {
      return;
    }

    final json = await _apiClient.postJson('/api/auth/refresh', {
      'refreshToken': currentRefreshToken,
    });

    await _applyAdmin(AuthResult.fromJson(json));
  }

  Future<void> logout() async {
    final currentAccessToken = token;
    final currentRefreshToken = refreshToken;
    if (currentRefreshToken != null) {
      try {
        await _apiClient.postJson('/api/auth/logout', {
          'accessToken': currentAccessToken,
          'refreshToken': currentRefreshToken,
        });
      } catch (_) {
        // Local logout must still complete if the server is unavailable.
      }
    }

    token = null;
    refreshToken = null;
    tokenExpiresAtUtc = null;
    refreshTokenExpiresAtUtc = null;
    user = null;
    await _storage.clear();
  }

  Future<AuthResult> _applyAdmin(AuthResult result) async {
    if (result.user.role != 'Admin') {
      await logout();
      throw ApiException('Nemate pravo pristupa desktop administraciji.', 403);
    }

    token = result.token;
    refreshToken = result.refreshToken;
    tokenExpiresAtUtc = result.tokenExpiresAtUtc;
    refreshTokenExpiresAtUtc = result.refreshTokenExpiresAtUtc;
    user = result.user;
    await _storage.save(result);
    return result;
  }
}
