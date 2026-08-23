import 'dart:convert';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.hasProfilePhoto = false,
    this.profilePhotoUpdatedAtUtc,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final bool hasProfilePhoto;
  final DateTime? profilePhotoUpdatedAtUtc;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'].toString(),
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      hasProfilePhoto: json['hasProfilePhoto'] as bool? ?? false,
      profilePhotoUpdatedAtUtc: DateTime.tryParse(
        json['profilePhotoUpdatedAtUtc']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role,
      'hasProfilePhoto': hasProfilePhoto,
      'profilePhotoUpdatedAtUtc': profilePhotoUpdatedAtUtc?.toIso8601String(),
    };
  }
}

class AuthResult {
  const AuthResult({
    required this.token,
    required this.tokenExpiresAtUtc,
    required this.refreshToken,
    required this.refreshTokenExpiresAtUtc,
    required this.user,
  });

  final String token;
  final DateTime tokenExpiresAtUtc;
  final String refreshToken;
  final DateTime refreshTokenExpiresAtUtc;
  final AuthUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token']?.toString() ?? '',
      tokenExpiresAtUtc: DateTime.parse(json['tokenExpiresAtUtc'].toString()),
      refreshToken: json['refreshToken']?.toString() ?? '',
      refreshTokenExpiresAtUtc: DateTime.parse(
        json['refreshTokenExpiresAtUtc'].toString(),
      ),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  String encodeUser() => jsonEncode(user.toJson());
}
