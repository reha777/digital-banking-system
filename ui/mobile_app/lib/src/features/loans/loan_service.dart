import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'models/loan_models.dart';

abstract class LoanRepository {
  Future<List<LoanProductModel>> getProducts(String token);
  Future<LoanQuoteModel> getQuote(
    String token, {
    required String productId,
    required double principal,
    required int termMonths,
  });
  Future<LoanApplicationModel?> getCurrentApplication(String token);
  Future<LoanApplicationModel> submitApplication(
    String token, {
    required String productId,
    required String destinationAccountId,
    required double principal,
    required int termMonths,
    required String clientRequestId,
  });
  Future<LoanModel?> getCurrentLoan(String token) async => null;
  Future<LoanModel?> getRecentLoan(String token) async => null;
  Future<LoanDetailsModel> getLoanDetails(String token, String loanId) =>
      throw UnimplementedError();
  Future<LoanPaymentQuoteModel> getPaymentQuote(String token, String loanId) =>
      throw UnimplementedError();
  Future<LoanPaymentResultModel> payInstallment(
    String token,
    String loanId, {
    required String sourceAccountId,
    required String clientRequestId,
  }) => throw UnimplementedError();
}

class LoanService implements LoanRepository {
  const LoanService(this._client);
  final ApiClient _client;
  @override
  Future<List<LoanProductModel>> getProducts(String token) async =>
      (await _client.getJsonList(
        MobileApiEndpoints.loanProducts,
        token: token,
      )).map(LoanProductModel.fromJson).toList();
  @override
  Future<LoanQuoteModel> getQuote(
    String token, {
    required String productId,
    required double principal,
    required int termMonths,
  }) async => LoanQuoteModel.fromJson(
    await _client.postJson(MobileApiEndpoints.loanQuote, {
      'loanProductId': productId,
      'principal': principal,
      'termMonths': termMonths,
    }, token: token),
  );
  @override
  Future<LoanApplicationModel?> getCurrentApplication(String token) async {
    final json = await _client.getJson(
      MobileApiEndpoints.currentLoanApplication,
      token: token,
    );
    return json.isEmpty ? null : LoanApplicationModel.fromJson(json);
  }

  @override
  Future<LoanApplicationModel> submitApplication(
    String token, {
    required String productId,
    required String destinationAccountId,
    required double principal,
    required int termMonths,
    required String clientRequestId,
  }) async => LoanApplicationModel.fromJson(
    await _client.postJson(MobileApiEndpoints.loanApplications, {
      'loanProductId': productId,
      'destinationAccountId': destinationAccountId,
      'principal': principal,
      'termMonths': termMonths,
      'clientRequestId': clientRequestId,
    }, token: token),
  );

  @override
  Future<LoanModel?> getCurrentLoan(String token) async {
    final json = await _client.getJson(
      MobileApiEndpoints.currentLoan,
      token: token,
    );
    return json.isEmpty ? null : LoanModel.fromJson(json);
  }

  @override
  Future<LoanModel?> getRecentLoan(String token) async {
    final json = await _client.getJson(
      MobileApiEndpoints.recentLoan,
      token: token,
    );
    return json.isEmpty ? null : LoanModel.fromJson(json);
  }

  @override
  Future<LoanDetailsModel> getLoanDetails(String token, String loanId) async =>
      LoanDetailsModel.fromJson(
        await _client.getJson(
          MobileApiEndpoints.loanDetails(loanId),
          token: token,
        ),
      );
  @override
  Future<LoanPaymentQuoteModel> getPaymentQuote(
    String token,
    String loanId,
  ) async => LoanPaymentQuoteModel.fromJson(
    await _client.getJson(
      MobileApiEndpoints.loanPaymentQuote(loanId),
      token: token,
    ),
  );
  @override
  Future<LoanPaymentResultModel> payInstallment(
    String token,
    String loanId, {
    required String sourceAccountId,
    required String clientRequestId,
  }) async => LoanPaymentResultModel.fromJson(
    await _client.postJson(MobileApiEndpoints.loanPayments(loanId), {
      'sourceAccountId': sourceAccountId,
      'clientRequestId': clientRequestId,
    }, token: token),
  );
}
