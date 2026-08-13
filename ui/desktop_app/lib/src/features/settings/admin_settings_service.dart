import '../../core/api_client.dart';
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
}
