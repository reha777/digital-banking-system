import '../../core/api_client.dart';
import '../../core/api_date_time.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.publishAtUtc,
    required this.createdAtUtc,
    required this.isPublished,
  });
  final String id, title, message;
  final DateTime publishAtUtc, createdAtUtc;
  final bool isPublished;
  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    message: json['message'] as String? ?? '',
    publishAtUtc: parseApiUtc(json['publishAtUtc'] as String),
    createdAtUtc: parseApiUtc(json['createdAtUtc'] as String),
    isPublished: json['isPublished'] == true,
  );
}

class AnnouncementService {
  AnnouncementService(this._api);
  final ApiClient _api;
  Future<List<Announcement>> getAll(String token) async {
    final json = await _api.getJson(
      '/api/admin/announcements?page=1&pageSize=100',
      token: token,
    );
    return (json['items'] as List<dynamic>? ?? const [])
        .map((x) => Announcement.fromJson(x as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(
    String token, {
    String? id,
    required String title,
    required String message,
    required DateTime publishAtUtc,
  }) async {
    final body = {
      'title': title,
      'message': message,
      'publishAtUtc': publishAtUtc.toUtc().toIso8601String(),
    };
    if (id == null) {
      await _api.postJson('/api/admin/announcements', body, token: token);
    } else {
      await _api.putJson('/api/admin/announcements/$id', body, token: token);
    }
  }
}
