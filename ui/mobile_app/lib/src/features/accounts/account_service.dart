import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'account_models.dart';

class AccountService {
  const AccountService(this._apiClient);

  final ApiClient _apiClient;

  Future<AccountBalanceSummary> getBalanceSummary(String token) async {
    final json = await _apiClient.getJson(
      MobileApiEndpoints.accountsBalance,
      token: token,
    );

    return AccountBalanceSummary.fromJson(json);
  }
}
