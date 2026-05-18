import '../../core/api_client.dart';
import 'auth_models.dart';

class AuthSession {
  AuthSession(this._apiClient);

  final ApiClient _apiClient;

  String? token;
  AuthUser? user;

  bool get isAuthenticated => token != null && user != null;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _apiClient.postJson('/api/auth/login', {
      'email': email,
      'password': password,
    });

    return _apply(AuthResult.fromJson(json));
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

    return _apply(AuthResult.fromJson(json));
  }

  void logout() {
    token = null;
    user = null;
  }

  AuthResult _apply(AuthResult result) {
    token = result.token;
    user = result.user;
    return result;
  }
}
