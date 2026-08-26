import '../../core/api_client.dart';

class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.sortOrder,
    this.description,
  });
  factory ReferenceItem.fromJson(Map<String, dynamic> value) => ReferenceItem(
    id: value['id'] as String,
    code: value['code'] as String,
    name: value['name'] as String,
    description: value['description'] as String?,
    isActive: value['isActive'] as bool,
    sortOrder: (value['sortOrder'] as num).toInt(),
  );
  final String id, code, name;
  final String? description;
  final bool isActive;
  final int sortOrder;
  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'description': description,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };
}

class ReferenceDataService {
  ReferenceDataService(this.client);
  final ApiClient client;
  String path(String type) => '/api/admin/reference-data/$type';
  Future<ReferencePageResult> get(
    String token,
    String type, {
    String search = '',
    bool? active,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (active != null) 'isActive': '$active',
        'page': '$page',
        'pageSize': '$pageSize',
      },
    ).query;
    final json = await client.getJson('${path(type)}?$query', token: token);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .map(
                (value) =>
                    ReferenceItem.fromJson(value as Map<String, dynamic>),
              )
              .toList()
        : <ReferenceItem>[];
    return ReferencePageResult(
      items: items,
      page: (json['page'] as num?)?.toInt() ?? page,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? pageSize,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> save(
    String token,
    String type,
    ReferenceItem item, {
    bool create = false,
  }) async {
    if (create) {
      await client.postJson(path(type), item.toJson(), token: token);
    } else {
      await client.putJson(
        '${path(type)}/${item.id}',
        item.toJson(),
        token: token,
      );
    }
  }
}

class ReferencePageResult {
  const ReferencePageResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });
  final List<ReferenceItem> items;
  final int page, pageSize, totalCount, totalPages;
}
