import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'models/statistics_models.dart';

class StatisticsService {
  const StatisticsService(this._client);
  final ApiClient _client;

  Future<StatisticsData> getStatistics({
    required String token,
    required DateTime from,
    required DateTime to,
    String? accountId,
  }) async {
    final query = <String, String>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'accountId': ?accountId,
    };
    final uri = Uri(
      path: MobileApiEndpoints.statistics,
      queryParameters: query,
    );
    return StatisticsData.fromJson(
      await _client.getJson(uri.toString(), token: token),
    );
  }
}
