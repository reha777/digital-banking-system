import '../../core/api_client.dart';
import 'models/admin_loan_models.dart';

abstract class AdminLoanRepository {
  Future<AdminLoanApplicationPage> getApplications({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
  });
  Future<AdminLoanSummary> getSummary({
    required String token,
    String? search,
    int? status,
  });
  Future<AdminLoanApplicationDetails> getApplicationDetails({
    required String token,
    required String id,
  });
  Future<AdminLoanApplicationDetails> approveApplication({
    required String token,
    required String id,
    String? adminNote,
  });
  Future<AdminLoanApplicationDetails> rejectApplication({
    required String token,
    required String id,
    required String adminNote,
  });
  Future<AdminLoanPage> getLoans({
    required String token,
    required int page,
    required int pageSize,
    required int status,
    String? search,
    DateTime? dateFromUtc,
    DateTime? dateToUtc,
  });
  Future<AdminLoanDetails> getLoanDetails({
    required String token,
    required String id,
  });
  Future<AdminLoansOverview> getLoansOverview({required String token});
}

class AdminLoanService implements AdminLoanRepository {
  const AdminLoanService(this._client);
  final ApiClient _client;
  Map<String, String> _query({String? search, int? status}) {
    final result = <String, String>{};
    if (search?.trim().isNotEmpty == true) result['search'] = search!.trim();
    if (status != null) result['status'] = '$status';
    return result;
  }

  @override
  Future<AdminLoanApplicationPage> getApplications({
    required String token,
    required int page,
    required int pageSize,
    String? search,
    int? status,
  }) async {
    final query = _query(search: search, status: status)
      ..addAll({'page': '$page', 'pageSize': '$pageSize'});
    final json = await _client.getJson(
      Uri(
        path: '/api/admin/loans/applications',
        queryParameters: query,
      ).toString(),
      token: token,
    );
    return AdminLoanApplicationPage.fromJson(json);
  }

  @override
  Future<AdminLoanSummary> getSummary({
    required String token,
    String? search,
    int? status,
  }) async {
    final json = await _client.getJson(
      Uri(
        path: '/api/admin/loans/applications/summary',
        queryParameters: _query(search: search, status: status),
      ).toString(),
      token: token,
    );
    return AdminLoanSummary.fromJson(json);
  }

  @override
  Future<AdminLoanApplicationDetails> getApplicationDetails({
    required String token,
    required String id,
  }) async => AdminLoanApplicationDetails.fromJson(
    await _client.getJson('/api/admin/loans/applications/$id', token: token),
  );

  @override
  Future<AdminLoanApplicationDetails> approveApplication({
    required String token,
    required String id,
    String? adminNote,
  }) async => AdminLoanApplicationDetails.fromJson(
    await _client.postJson('/api/admin/loans/applications/$id/approve', {
      'adminNote': adminNote,
    }, token: token),
  );

  @override
  Future<AdminLoanApplicationDetails> rejectApplication({
    required String token,
    required String id,
    required String adminNote,
  }) async => AdminLoanApplicationDetails.fromJson(
    await _client.postJson('/api/admin/loans/applications/$id/reject', {
      'adminNote': adminNote,
    }, token: token),
  );

  @override
  Future<AdminLoanPage> getLoans({
    required String token,
    required int page,
    required int pageSize,
    required int status,
    String? search,
    DateTime? dateFromUtc,
    DateTime? dateToUtc,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      'status': '$status',
    };
    if (search?.trim().isNotEmpty == true) query['search'] = search!.trim();
    if (dateFromUtc != null) {
      query['dateFromUtc'] = dateFromUtc.toUtc().toIso8601String();
    }
    if (dateToUtc != null) {
      query['dateToUtc'] = dateToUtc.toUtc().toIso8601String();
    }
    return AdminLoanPage.fromJson(
      await _client.getJson(
        Uri(path: '/api/admin/loans', queryParameters: query).toString(),
        token: token,
      ),
    );
  }

  @override
  Future<AdminLoanDetails> getLoanDetails({
    required String token,
    required String id,
  }) async => AdminLoanDetails.fromJson(
    await _client.getJson('/api/admin/loans/$id', token: token),
  );
  @override
  Future<AdminLoansOverview> getLoansOverview({required String token}) async =>
      AdminLoansOverview.fromJson(
        await _client.getJson('/api/admin/loans/summary', token: token),
      );
}
