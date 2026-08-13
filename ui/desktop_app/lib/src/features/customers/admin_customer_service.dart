import '../../core/api_client.dart';
import 'admin_customer_models.dart';

class AdminCustomerService {
  const AdminCustomerService(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminCustomerPage> getCustomers({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
  }) async {
    final query = _buildFiltersQuery(search: search, status: status);
    query.addAll({'page': page.toString(), 'pageSize': pageSize.toString()});

    final uri = Uri(path: '/api/admin/customers', queryParameters: query);
    final json = await _apiClient.getJson(uri.toString(), token: token);
    return AdminCustomerPage.fromJson(json);
  }

  Future<AdminCustomerSummary> getSummary({
    required String token,
    String? search,
    int? status,
  }) async {
    final query = _buildFiltersQuery(search: search, status: status);
    final uri = Uri(
      path: '/api/admin/customers/summary',
      queryParameters: query,
    );
    final json = await _apiClient.getJson(uri.toString(), token: token);
    return AdminCustomerSummary.fromJson(json);
  }

  Future<AdminCustomer> updateCustomer({
    required String token,
    required String id,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final json = await _apiClient.putJson('/api/admin/customers/$id', {
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
    }, token: token);
    return AdminCustomer.fromJson(json);
  }

  Future<AdminCustomer> updateStatus({
    required String token,
    required String id,
    required int status,
  }) async {
    final json = await _apiClient.patchJson('/api/admin/customers/$id/status', {
      'status': status,
    }, token: token);
    return AdminCustomer.fromJson(json);
  }

  Future<void> deleteCustomer({required String token, required String id}) {
    return _apiClient.delete('/api/admin/customers/$id', token: token);
  }

  Map<String, String> _buildFiltersQuery({String? search, int? status}) {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (status != null) {
      query['status'] = status.toString();
    }

    return query;
  }
}
