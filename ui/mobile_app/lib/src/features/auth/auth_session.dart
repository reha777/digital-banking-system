import '../../core/api_client.dart';
import 'auth_models.dart';
import 'auth_storage.dart';

class AuthSession {
  AuthSession(this._apiClient, {AuthStorage? storage})
    : _storage = storage ?? AuthStorage() {
    ApiClient.configureAuth(
      accessTokenProvider: () => token,
      refreshSession: refresh,
      invalidateSession: endDisabledSession,
    );
  }

  final ApiClient _apiClient;
  final AuthStorage _storage;

  String? token;
  String? refreshToken;
  DateTime? tokenExpiresAtUtc;
  DateTime? refreshTokenExpiresAtUtc;
  AuthUser? user;
  Future<void>? _refreshFuture;
  Future<void> Function(String message)? onSessionEnded;
  String? sessionEndedMessage;

  bool get isAuthenticated => token != null && user != null;

  Future<void> initialize() async {
    final stored = await _storage.read();
    if (stored == null ||
        stored.refreshTokenExpiresAtUtc.isBefore(DateTime.now().toUtc())) {
      await _storage.clear();
      return;
    }

    if (stored.user.role == 'Admin') {
      await _storage.clear();
      return;
    }

    token = stored.token;
    refreshToken = stored.refreshToken;
    tokenExpiresAtUtc = stored.tokenExpiresAtUtc;
    refreshTokenExpiresAtUtc = stored.refreshTokenExpiresAtUtc;
    user = stored.user;

    if (tokenExpiresAtUtc!.isBefore(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    )) {
      try {
        await refresh();
      } on ApiException catch (error) {
        if (error.statusCode != 400 &&
            error.statusCode != 401 &&
            error.statusCode != 403) {
          rethrow;
        }
      }
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

    return _applyCustomer(AuthResult.fromJson(json));
  }

  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/api/auth/register', {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'email': email,
      'password': password,
    });

    return _applyCustomer(AuthResult.fromJson(json));
  }

  Future<void> refresh() async {
    final inFlight = _refreshFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _performRefresh();
    _refreshFuture = future;
    try {
      await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  Future<void> _performRefresh() async {
    final currentRefreshToken = refreshToken;
    final expiry = refreshTokenExpiresAtUtc;
    if (currentRefreshToken == null ||
        (expiry != null && expiry.isBefore(DateTime.now().toUtc()))) {
      await _clearLocalSession();
      throw ApiException('Sesija je istekla. Prijavite se ponovo.', 401);
    }

    try {
      final json = await _apiClient.postJson('/api/auth/refresh', {
        'refreshToken': currentRefreshToken,
      }, allowAuthRefresh: false);
      await _applyCustomer(AuthResult.fromJson(json));
    } on ApiException catch (error) {
      if (error.statusCode == 400 ||
          error.statusCode == 401 ||
          error.statusCode == 403) {
        if (error.code == 'account_disabled') {
          await endDisabledSession(error.message);
        } else {
          await _clearLocalSession();
        }
      }
      rethrow;
    }
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

    await _clearLocalSession();
  }

  Future<void> endDisabledSession(String message) async {
    sessionEndedMessage = message;
    await _clearLocalSession();
    await onSessionEnded?.call(message);
  }

  Future<void> updateCurrentUser(AuthUser updatedUser) async {
    final currentToken = token;
    final currentRefreshToken = refreshToken;
    final accessExpiry = tokenExpiresAtUtc;
    final refreshExpiry = refreshTokenExpiresAtUtc;
    if (currentToken == null ||
        currentRefreshToken == null ||
        accessExpiry == null ||
        refreshExpiry == null) {
      throw StateError('Authenticated session is not available.');
    }

    final result = AuthResult(
      token: currentToken,
      tokenExpiresAtUtc: accessExpiry,
      refreshToken: currentRefreshToken,
      refreshTokenExpiresAtUtc: refreshExpiry,
      user: updatedUser,
    );
    await _storage.save(result);
    user = updatedUser;
  }

  Future<void> _clearLocalSession() async {
    token = null;
    refreshToken = null;
    tokenExpiresAtUtc = null;
    refreshTokenExpiresAtUtc = null;
    user = null;
    await _storage.clear();
  }

  Future<AuthResult> _applyCustomer(AuthResult result) async {
    if (result.user.role == 'Admin') {
      throw ApiException(
        'Admin korisnici ne mogu pristupiti mobilnoj aplikaciji.',
        403,
      );
    }

    token = result.token;
    sessionEndedMessage = null;
    refreshToken = result.refreshToken;
    tokenExpiresAtUtc = result.tokenExpiresAtUtc;
    refreshTokenExpiresAtUtc = result.refreshTokenExpiresAtUtc;
    user = result.user;
    await _storage.save(result);
    return result;
  }
}
