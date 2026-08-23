import '../../core/api_client.dart';
import 'audit_log_models.dart';

class AuditLogService {
  AuditLogService(this._client);
  final ApiClient _client;
  Future<AuditLogPageModel> getLogs({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    String? action,
    String? entityType,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (action != null) query['action'] = action;
    if (entityType != null) query['entityType'] = entityType;
    if (dateFrom != null) {
      query['dateFrom'] = dateFrom.toUtc().toIso8601String();
    }
    if (dateTo != null) query['dateTo'] = dateTo.toUtc().toIso8601String();
    final uri = Uri(path: '/api/admin/audit-logs', queryParameters: query);
    return AuditLogPageModel.fromJson(
      await _client.getJson(uri.toString(), token: token),
    );
  }
}
