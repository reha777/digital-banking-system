import '../../core/api_client.dart';

class PasswordResetService {
  PasswordResetService([ApiClient? client]) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<String> forgot(String email, {String? demoAccount}) async {
    final body = <String, dynamic>{'email': email};
    if (demoAccount != null) {
      body['demoAccount'] = demoAccount;
    }
    return (await _client.postJson(
          demoAccount == null
              ? '/api/auth/forgot-password'
              : '/api/auth/demo/forgot-password',
          body,
        ))['message']
        as String;
  }

  Future<void> reset(String token, String password) async {
    await _client.postJson('/api/auth/reset-password', {
      'token': token,
      'newPassword': password,
      'confirmPassword': password,
    });
  }
}
