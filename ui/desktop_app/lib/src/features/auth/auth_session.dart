import '../../core/api_client.dart';
import 'auth_models.dart';

class AuthSession {
  AuthSession(this._apiClient);

  final ApiClient _apiClient;

  String? token;
  AuthUser? user;

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

    token = result.token;
    user = result.user;
    return result;
  }

  void logout() {
    token = null;
    user = null;
  }
}
