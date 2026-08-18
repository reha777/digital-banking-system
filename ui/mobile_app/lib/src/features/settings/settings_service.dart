import 'dart:typed_data';

import '../../core/api_client.dart';
import '../auth/auth_models.dart';
import '../auth/auth_session.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.hasProfilePhoto = false,
    this.profilePhotoUpdatedAtUtc,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String role;
  final bool hasProfilePhoto;
  final DateTime? profilePhotoUpdatedAtUtc;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        id: json['id'].toString(),
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        hasProfilePhoto: json['hasProfilePhoto'] == true,
        profilePhotoUpdatedAtUtc: json['profilePhotoUpdatedAtUtc'] == null
            ? null
            : DateTime.tryParse(json['profilePhotoUpdatedAtUtc'].toString()),
      );

  AuthUser toAuthUser() => AuthUser(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    role: role,
    phoneNumber: phoneNumber,
    hasProfilePhoto: hasProfilePhoto,
    profilePhotoUpdatedAtUtc: profilePhotoUpdatedAtUtc,
  );
}

class SettingsService {
  SettingsService(this._apiClient, this._session);

  final ApiClient _apiClient;
  final AuthSession _session;

  Future<CustomerProfile> getProfile() async {
    final json = await _apiClient.getJson(
      '/api/profile',
      token: _session.token,
    );
    final profile = CustomerProfile.fromJson(json);
    await _session.updateCurrentUser(profile.toAuthUser());
    return profile;
  }

  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final json = await _apiClient.putJson('/api/profile', {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phoneNumber': phoneNumber.trim(),
    }, token: _session.token);
    final profile = CustomerProfile.fromJson(json);
    await _session.updateCurrentUser(profile.toAuthUser());
    return profile;
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _apiClient.postJson('/api/profile/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    }, token: _session.token);
  }

  Future<CustomerProfile> uploadProfilePhoto({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _apiClient.postMultipartBytes(
      '/api/profile/photo',
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
      token: _session.token,
    );
    final profile = CustomerProfile.fromJson(json);
    await _session.updateCurrentUser(profile.toAuthUser());
    return profile;
  }
}
