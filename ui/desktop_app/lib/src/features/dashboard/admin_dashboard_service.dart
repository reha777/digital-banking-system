import '../../core/api_client.dart';
import 'admin_dashboard_models.dart';

class AdminDashboardService {
  const AdminDashboardService(this._client);

  final ApiClient _client;

  Future<AdminDashboardSummary> getDashboard({
    required String token,
    int periodDays = 7,
  }) async => AdminDashboardSummary.fromJson(
    await _client.getJson(
      '/api/admin/dashboard?periodDays=$periodDays',
      token: token,
    ),
  );
}
