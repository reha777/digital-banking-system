import '../../core/api_client.dart';
import 'admin_card_request_models.dart';

class AdminCardRequestService {
  const AdminCardRequestService(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminCardRequestPage> getRequests({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = _buildFiltersQuery(
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    query.addAll({'page': page.toString(), 'pageSize': pageSize.toString()});

    final uri = Uri(path: '/api/admin/card-requests', queryParameters: query);
    final json = await _apiClient.getJson(uri.toString(), token: token);
    return AdminCardRequestPage.fromJson(json);
  }

  Future<AdminCardRequestSummary> getSummary({
    required String token,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = _buildFiltersQuery(
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    final uri = Uri(
      path: '/api/admin/card-requests/summary',
      queryParameters: query,
    );
    final json = await _apiClient.getJson(uri.toString(), token: token);
    return AdminCardRequestSummary.fromJson(json);
  }

  Future<AdminCardRequest> approve({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    final json = await _apiClient.postJson(
      '/api/admin/card-requests/$id/approve',
      {'adminNote': adminNote},
      token: token,
    );
    return AdminCardRequest.fromJson(json);
  }

  Future<AdminCardRequest> reject({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    final json = await _apiClient.postJson(
      '/api/admin/card-requests/$id/reject',
      {'adminNote': adminNote},
      token: token,
    );
    return AdminCardRequest.fromJson(json);
  }

  Future<AdminCardRequest> requestDocuments({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    final json = await _apiClient.postJson(
      '/api/admin/card-requests/$id/request-documents',
      {'adminNote': adminNote},
      token: token,
    );
    return AdminCardRequest.fromJson(json);
  }

  Future<List<int>> downloadDocument({
    required String token,
    required String requestId,
    required String documentId,
  }) {
    return _apiClient.getBytes(
      '/api/admin/card-requests/$requestId/documents/$documentId/download',
      token: token,
    );
  }

  Map<String, String> _buildFiltersQuery({
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (status != null) {
      query['status'] = status.toString();
    }

    if (dateFrom != null) query['dateFromUtc'] = _formatDateOnly(dateFrom);
    if (dateTo != null) query['dateToUtc'] = _formatDateOnly(dateTo);

    return query;
  }

  Future<AdminIssuedCardPage> getIssuedCards({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    };
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (status != null) query['status'] = status.toString();
    final uri = Uri(path: '/api/admin/cards', queryParameters: query);
    return AdminIssuedCardPage.fromJson(
      await _apiClient.getJson(uri.toString(), token: token),
    );
  }

  static String _formatDateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
