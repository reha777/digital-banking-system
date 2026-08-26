import '../../core/api_client.dart';
import '../auth/auth_session.dart';
import 'notification_model.dart';

class NotificationService {
  NotificationService(this._api, this._session);
  final ApiClient _api;
  final AuthSession _session;

  String get _token => _session.token ?? '';

  Future<NotificationPageResult> getNotifications({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async {
    final json = await _api.getJson(
      '/api/notifications?page=$page&pageSize=$pageSize&unreadOnly=$unreadOnly',
      token: _token,
    );
    final items = (json['items'] as List<dynamic>? ?? const [])
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
    return NotificationPageResult(
      items: items,
      totalCount: json['totalCount'] as int? ?? items.length,
    );
  }

  Future<int> unreadCount() async =>
      (await _api.getJson(
            '/api/notifications/unread-count',
            token: _token,
          ))['count']
          as int? ??
      0;

  Future<void> markRead(String id) async {
    await _api.putJson('/api/notifications/$id/read', const {}, token: _token);
  }

  Future<void> markAllRead() async {
    await _api.putJson('/api/notifications/read-all', const {}, token: _token);
  }
}
