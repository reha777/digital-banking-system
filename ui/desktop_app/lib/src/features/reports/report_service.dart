import '../../core/api_client.dart';
import 'report_models.dart';

class ReportService {
  ReportService(this.client);
  final ApiClient client;
  Future<ReportJobPageModel> list(String token) async =>
      ReportJobPageModel.fromJson(
        await client.getJson(
          '/api/admin/reports?page=1&pageSize=50',
          token: token,
        ),
      );
  Future<ReportJobModel> create(
    String token,
    String kind,
    Map<String, dynamic> filters,
  ) async => ReportJobModel.fromJson(
    await client.postJson('/api/admin/reports/$kind', filters, token: token),
  );
  Future<List<int>> download(String token, String id) async =>
      client.getBytes('/api/admin/reports/$id/download', token: token);
}
