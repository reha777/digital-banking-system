import '../../core/api_client.dart';

class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAtUtc,
    this.entityType,
    this.entityId,
  });
  final String id, type, title, message;
  final String? entityType, entityId;
  final bool isRead;
  final DateTime createdAtUtc;
  factory AdminNotification.fromJson(Map<String, dynamic> json) =>
      AdminNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
        isRead: json['isRead'] == true,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      );
  AdminNotification asRead() => AdminNotification(
    id: id,
    type: type,
    title: title,
    message: message,
    entityType: entityType,
    entityId: entityId,
    isRead: true,
    createdAtUtc: createdAtUtc,
  );
}

class AdminNotificationPage {
  const AdminNotificationPage(this.items, this.totalCount);
  final List<AdminNotification> items;
  final int totalCount;
}

class NotificationService {
  NotificationService(this._api);
  final ApiClient _api;
  Future<AdminNotificationPage> list(
    String token, {
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final json = await _api.getJson(
      '/api/notifications?page=$page&pageSize=$pageSize&unreadOnly=$unreadOnly',
      token: token,
    );
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map((x) => AdminNotification.fromJson(x as Map<String, dynamic>))
        .toList();
    return AdminNotificationPage(
      items,
      json['totalCount'] as int? ?? items.length,
    );
  }

  Future<int> unreadCount(String token) async =>
      (await _api.getJson(
            '/api/notifications/unread-count',
            token: token,
          ))['count']
          as int? ??
      0;
  Future<void> markRead(String token, String id) async {
    await _api.putJson('/api/notifications/$id/read', const {}, token: token);
  }

  Future<void> markAllRead(String token) async {
    await _api.putJson('/api/notifications/read-all', const {}, token: token);
  }
}
