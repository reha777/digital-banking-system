class AppNotification {
  const AppNotification({
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

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
        isRead: json['isRead'] == true,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      );

  AppNotification asRead() => AppNotification(
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

class NotificationPageResult {
  const NotificationPageResult({required this.items, required this.totalCount});
  final List<AppNotification> items;
  final int totalCount;
}
