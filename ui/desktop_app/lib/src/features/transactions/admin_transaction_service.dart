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
  }) async {
    final query = _buildFiltersQuery(
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
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
  }) async {
    final query = _buildFiltersQuery(
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
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

    return query;
  }

  static String _formatDateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
