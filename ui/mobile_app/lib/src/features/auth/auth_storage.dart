import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_models.dart';

abstract interface class SecureAuthStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract interface class LegacyAuthStore {
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class AuthStorage {
  AuthStorage({SecureAuthStore? secureStore, LegacyAuthStore? legacyStore})
    : _secureStore = secureStore ?? _FlutterSecureAuthStore(),
      _legacyStore = legacyStore ?? _SharedPreferencesAuthStore();

  static const tokenKey = 'auth.accessToken';
  static const refreshTokenKey = 'auth.refreshToken';
  static const tokenExpiresAtKey = 'auth.tokenExpiresAtUtc';
  static const refreshTokenExpiresAtKey = 'auth.refreshTokenExpiresAtUtc';
  static const userKey = 'auth.user';
  static const _authKeys = [
    tokenKey,
    refreshTokenKey,
    tokenExpiresAtKey,
    refreshTokenExpiresAtKey,
    userKey,
  ];

  final SecureAuthStore _secureStore;
  final LegacyAuthStore _legacyStore;

  Future<void> save(AuthResult result) async {
    final values = <String, String>{
      tokenKey: result.token,
      refreshTokenKey: result.refreshToken,
      tokenExpiresAtKey: result.tokenExpiresAtUtc.toIso8601String(),
      refreshTokenExpiresAtKey: result.refreshTokenExpiresAtUtc
          .toIso8601String(),
      userKey: result.encodeUser(),
    };

    for (final entry in values.entries) {
      await _secureStore.write(entry.key, entry.value);
    }
    for (final key in _authKeys) {
      await _legacyStore.delete(key);
    }
  }

  Future<StoredAuthSession?> read() async {
    final values = <String, String?>{};
    for (final key in _authKeys) {
      values[key] = await _readAndMigrate(key);
    }

    final token = values[tokenKey];
    final refreshToken = values[refreshTokenKey];
    final tokenExpiresAt = values[tokenExpiresAtKey];
    final refreshTokenExpiresAt = values[refreshTokenExpiresAtKey];
    final userJson = values[userKey];
    if (token == null ||
        refreshToken == null ||
        tokenExpiresAt == null ||
        refreshTokenExpiresAt == null ||
        userJson == null) {
      return null;
    }

    try {
      return StoredAuthSession(
        token: token,
        refreshToken: refreshToken,
        tokenExpiresAtUtc: DateTime.parse(tokenExpiresAt),
        refreshTokenExpiresAtUtc: DateTime.parse(refreshTokenExpiresAt),
        user: AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<String?> _readAndMigrate(String key) async {
    final secureValue = await _secureStore.read(key);
    final legacyValue = await _legacyStore.read(key);
    if (secureValue != null) {
      if (legacyValue != null) {
        await _legacyStore.delete(key);
      }
      return secureValue;
    }
    if (legacyValue == null) {
      return null;
    }

    await _secureStore.write(key, legacyValue);
    final confirmedValue = await _secureStore.read(key);
    if (confirmedValue == null) {
      return legacyValue;
    }
    await _legacyStore.delete(key);
    return confirmedValue;
  }

  Future<void> clear() async {
    for (final key in _authKeys) {
      await _secureStore.delete(key);
      await _legacyStore.delete(key);
    }
  }
}

class _FlutterSecureAuthStore implements SecureAuthStore {
  _FlutterSecureAuthStore()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class _SharedPreferencesAuthStore implements LegacyAuthStore {
  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
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
