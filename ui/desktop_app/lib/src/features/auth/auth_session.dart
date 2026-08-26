import '../../core/api_client.dart';
import 'package:flutter/foundation.dart';
import 'auth_models.dart';
import 'auth_storage.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._apiClient, {AuthStorage? storage})
    : _storage = storage ?? AuthStorage() {
    ApiClient.configureAuth(
      accessTokenProvider: () => token,
      refreshSession: refresh,
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

  bool get isAuthenticated => token != null && user != null;

  Future<void> initialize() async {
    final stored = await _storage.read();
    if (stored == null ||
        stored.refreshTokenExpiresAtUtc.isBefore(DateTime.now().toUtc())) {
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

    if (tokenExpiresAtUtc!.isBefore(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    )) {
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
    final inFlight = _refreshFuture;
    if (inFlight != null) return inFlight;
    final future = _performRefresh();
    _refreshFuture = future;
    try {
      await future;
    } finally {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
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
      await _applyAdmin(AuthResult.fromJson(json));
    } on ApiException catch (error) {
      if (error.statusCode == 400 ||
          error.statusCode == 401 ||
          error.statusCode == 403) {
        await _clearLocalSession();
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

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    bool? hasProfilePhoto,
    DateTime? profilePhotoUpdatedAtUtc,
    bool clearProfilePhoto = false,
  }) async {
    final current = user;
    if (current == null ||
        token == null ||
        refreshToken == null ||
        tokenExpiresAtUtc == null ||
        refreshTokenExpiresAtUtc == null) {
      return;
    }
    user = AuthUser(
      id: current.id,
      firstName: firstName,
      lastName: lastName,
      email: current.email,
      role: current.role,
      hasProfilePhoto: hasProfilePhoto ?? current.hasProfilePhoto,
      profilePhotoUpdatedAtUtc: clearProfilePhoto
          ? null
          : profilePhotoUpdatedAtUtc ?? current.profilePhotoUpdatedAtUtc,
    );
    await _storage.save(
      AuthResult(
        token: token!,
        tokenExpiresAtUtc: tokenExpiresAtUtc!,
        refreshToken: refreshToken!,
        refreshTokenExpiresAtUtc: refreshTokenExpiresAtUtc!,
        user: user!,
      ),
    );
    notifyListeners();
  }

  Future<AuthResult> _applyAdmin(AuthResult result) async {
    if (result.user.role != 'Admin') {
      await _clearLocalSession();
      throw ApiException('Nemate pravo pristupa desktop administraciji.', 403);
    }

    token = result.token;
    refreshToken = result.refreshToken;
    tokenExpiresAtUtc = result.tokenExpiresAtUtc;
    refreshTokenExpiresAtUtc = result.refreshTokenExpiresAtUtc;
    user = result.user;
    await _storage.save(result);
    notifyListeners();
    return result;
  }

  Future<void> _clearLocalSession() async {
    token = null;
    refreshToken = null;
    tokenExpiresAtUtc = null;
    refreshTokenExpiresAtUtc = null;
    user = null;
    await _storage.clear();
    notifyListeners();
  }
}
