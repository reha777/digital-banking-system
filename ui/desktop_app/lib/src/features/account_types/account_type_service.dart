import '../../core/api_client.dart';

class AccountTypeItem {
  const AccountTypeItem({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });
  final String id, code, name;
  final bool isActive;
  factory AccountTypeItem.fromJson(Map<String, dynamic> json) =>
      AccountTypeItem(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        isActive: json['isActive'] == true,
      );
}

class AccountTypeService {
  AccountTypeService(this._api);
  final ApiClient _api;
  Future<List<AccountTypeItem>> getAll(String token) async =>
      (await _api.getJsonList('/api/admin/account-types', token: token))
          .map((x) => AccountTypeItem.fromJson(x as Map<String, dynamic>))
          .toList();
  Future<void> create(String token, String code, String name) async =>
      _api.postJson('/api/admin/account-types', {
        'code': code,
        'name': name,
      }, token: token);
  Future<void> update(String token, String id, String name) async => _api
      .putJson('/api/admin/account-types/$id', {'name': name}, token: token);
  Future<void> setActive(String token, String id, bool active) async =>
      _api.postJson(
        '/api/admin/account-types/$id/${active ? 'activate' : 'deactivate'}',
        const {},
        token: token,
      );
}
