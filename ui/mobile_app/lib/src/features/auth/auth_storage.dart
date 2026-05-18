import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

class AuthStorage {
  static const _tokenKey = 'auth.accessToken';
  static const _refreshTokenKey = 'auth.refreshToken';
  static const _tokenExpiresAtKey = 'auth.tokenExpiresAtUtc';
  static const _refreshTokenExpiresAtKey = 'auth.refreshTokenExpiresAtUtc';
  static const _userKey = 'auth.user';

  Future<void> save(AuthResult result) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, result.token);
    await preferences.setString(_refreshTokenKey, result.refreshToken);
    await preferences.setString(_tokenExpiresAtKey, result.tokenExpiresAtUtc.toIso8601String());
    await preferences.setString(_refreshTokenExpiresAtKey, result.refreshTokenExpiresAtUtc.toIso8601String());
    await preferences.setString(_userKey, result.encodeUser());
  }

  Future<StoredAuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final refreshToken = preferences.getString(_refreshTokenKey);
    final tokenExpiresAt = preferences.getString(_tokenExpiresAtKey);
    final refreshTokenExpiresAt = preferences.getString(_refreshTokenExpiresAtKey);
    final userJson = preferences.getString(_userKey);

    if (token == null ||
        refreshToken == null ||
        tokenExpiresAt == null ||
        refreshTokenExpiresAt == null ||
        userJson == null) {
      return null;
    }

    return StoredAuthSession(
      token: token,
      refreshToken: refreshToken,
      tokenExpiresAtUtc: DateTime.parse(tokenExpiresAt),
      refreshTokenExpiresAtUtc: DateTime.parse(refreshTokenExpiresAt),
      user: AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_refreshTokenKey);
    await preferences.remove(_tokenExpiresAtKey);
    await preferences.remove(_refreshTokenExpiresAtKey);
    await preferences.remove(_userKey);
  }
}

class StoredAuthSession {
  const StoredAuthSession({
    required this.token,
    required this.refreshToken,
    required this.tokenExpiresAtUtc,
    required this.refreshTokenExpiresAtUtc,
    required this.user,
  });

  final String token;
  final String refreshToken;
  final DateTime tokenExpiresAtUtc;
  final DateTime refreshTokenExpiresAtUtc;
  final AuthUser user;
}
