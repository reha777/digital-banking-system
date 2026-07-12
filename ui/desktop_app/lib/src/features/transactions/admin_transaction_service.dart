import '../../core/api_client.dart';
import 'admin_transaction_models.dart';

class AdminTransactionService {
  const AdminTransactionService(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminTransactionPage> getTransactions({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool highRiskOnly = false,
  }) async {
    final query = _buildFiltersQuery(
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      highRiskOnly: highRiskOnly,
    );
    query.addAll({
      'page': page.toString(),
      'pageSize': pageSize.toString(),
    });

    final uri = Uri(path: '/api/transactions', queryParameters: query);
    final json = await _apiClient.getJson(uri.toString(), token: token);
    return AdminTransactionPage.fromJson(json);
  }

  Future<AdminTransactionSummary> getSummary({
    required String token,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool highRiskOnly = false,
  }) async {
    final query = _buildFiltersQuery(
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      highRiskOnly: highRiskOnly,
    );

    final uri = Uri(path: '/api/transactions/summary', queryParameters: query);
    final json = await _apiClient.getJson(uri.toString(), token: token);
    return AdminTransactionSummary.fromJson(json);
  }

  Map<String, String> _buildFiltersQuery({
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool highRiskOnly = false,
  }) {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (status != null) {
      query['status'] = status.toString();
    }

    if (dateFrom != null) {
      query['dateFrom'] = _formatDateOnly(dateFrom);
    }

    if (dateTo != null) {
      query['dateTo'] = _formatDateOnly(dateTo);
    }

    if (highRiskOnly) {
      query['highRiskOnly'] = 'true';
    }

    return query;
  }

  Future<AdminTransaction> requestDocuments({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    final json = await _apiClient.postJson(
      '/api/transactions/$id/request-documents',
      {'adminNote': adminNote},
      token: token,
    );
    return AdminTransaction.fromJson(json);
  }

  Future<AdminTransaction> approveReview({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    final json = await _apiClient.postJson(
      '/api/transactions/$id/approve',
      {'adminNote': adminNote},
      token: token,
    );
    return AdminTransaction.fromJson(json);
  }

  Future<AdminTransaction> rejectReview({
    required String token,
    required String id,
    String? adminNote,
  }) async {
    final json = await _apiClient.postJson(
      '/api/transactions/$id/reject',
      {'adminNote': adminNote},
      token: token,
    );
    return AdminTransaction.fromJson(json);
  }

  Future<List<int>> downloadDocument({
    required String token,
    required String transactionId,
    required String documentId,
  }) {
    return _apiClient.getBytes(
      '/api/transactions/$transactionId/documents/$documentId/download',
      token: token,
    );
  }

  static String _formatDateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
