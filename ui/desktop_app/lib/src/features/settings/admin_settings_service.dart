import '../../core/api_client.dart';
import 'dart:typed_data';
import 'admin_settings_models.dart';

class AdminSettingsService {
  AdminSettingsService(this._api);
  final ApiClient _api;
  Future<AdminSettings> get(String token) async => AdminSettings.fromJson(
    await _api.getJson('/api/admin/settings', token: token),
  );
  Future<SystemSettings> saveSystem(String token, SystemSettings value) async =>
      SystemSettings.fromJson(
        await _api.putJson(
          '/api/admin/settings/system',
          value.toJson(),
          token: token,
        ),
      );
  Future<AdminPreferences> savePreferences(
    String token,
    AdminPreferences value,
  ) async => AdminPreferences.fromJson(
    await _api.putJson(
      '/api/admin/settings/preferences',
      value.toJson(),
      token: token,
    ),
  );
  Future<AdminProfile> saveProfile(String token, AdminProfile value) async =>
      AdminProfile.fromJson(
        await _api.putJson(
          '/api/admin/settings/profile',
          value.toJson(),
          token: token,
        ),
      );
  Future<void> changePassword(
    String token,
    String currentPassword,
    String newPassword,
  ) async => _api.putJson('/api/admin/settings/password', {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  }, token: token);
  Future<AdminProfile> uploadProfilePhoto(
    String token,
    Uint8List bytes,
    String fileName,
  ) async => AdminProfile.fromJson(
    await _api.postMultipart(
      '/api/admin/settings/profile/photo',
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
      token: token,
    ),
  );
  Future<AdminProfile> deleteProfilePhoto(String token) async {
    await _api.delete('/api/admin/settings/profile/photo', token: token);
    final settings = await get(token);
    return settings.profile;
  }
}
