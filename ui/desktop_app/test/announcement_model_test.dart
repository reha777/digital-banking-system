import 'dart:convert';

import 'package:desktop_app/src/core/api_client.dart';
import 'package:desktop_app/src/features/announcements/announcement_service.dart';
import 'package:desktop_app/src/features/settings/admin_date_time_formatter.dart';
import 'package:desktop_app/src/features/settings/admin_settings_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('admin announcement preserves publish state and timestamps', () {
    final value = Announcement.fromJson({
      'id': 'announcement-1',
      'title': 'Important notice',
      'message': 'Never share verification codes.',
      'publishAtUtc': '2026-09-09T10:30:00Z',
      'createdAtUtc': '2026-09-09T09:30:00Z',
      'isPublished': true,
    });
    expect(value.isPublished, isTrue);
    expect(value.publishAtUtc.isUtc, isTrue);
    expect(value.publishAtUtc, DateTime.utc(2026, 9, 9, 10, 30));
    expect(value.title, 'Important notice');
  });

  test('zone-less API timestamp is read as UTC, not as device local time', () {
    // SQL Server datetime2 materializes as DateTimeKind.Unspecified, so the API
    // serializes UTC instants without a trailing Z.
    final value = _announcement('2026-09-09T13:52:00');

    expect(value.publishAtUtc.isUtc, isTrue);
    expect(value.publishAtUtc, DateTime.utc(2026, 9, 9, 13, 52));
    expect(value.createdAtUtc, DateTime.utc(2026, 9, 9, 13, 52));
  });

  test('explicit zone designators keep the instant they describe', () {
    // 15:52 at UTC+02 is the same instant as 13:52 UTC.
    expect(
      _announcement('2026-09-09T15:52:00+02:00').publishAtUtc,
      DateTime.utc(2026, 9, 9, 13, 52),
    );
    expect(
      _announcement('2026-09-09T13:52:00Z').publishAtUtc,
      DateTime.utc(2026, 9, 9, 13, 52),
    );
    expect(
      _announcement('2026-09-09T13:52:00.000Z').publishAtUtc,
      DateTime.utc(2026, 9, 9, 13, 52),
    );
  });

  test('stored 13:52 UTC renders as 15:52 in the admin timezone', () {
    final value = _announcement('2026-09-09T13:52:00');

    // The list uses AdminSettingsController.formatDateTime, which shifts a UTC
    // instant into the admin's configured zone (Europe/Sarajevo, +02 in September).
    expect(
      const AdminDateTimeFormatter(_preferences).dateTime(value.publishAtUtc),
      '09.09.2026. 15:52',
    );
  });

  test('a local publish time is converted to UTC exactly once', () async {
    late http.Request sent;
    final service = AnnouncementService(
      ApiClient(
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(const <String, dynamic>{}), 200);
        }),
      ),
    );

    // What the date and time pickers produce: a device-local wall clock.
    final picked = DateTime(2026, 9, 9, 15, 52);
    await service.save(
      'token',
      title: 'Title',
      message: 'Message',
      publishAtUtc: picked.toUtc(),
    );

    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    final serialized = DateTime.parse(body['publishAtUtc'] as String);
    expect(body['publishAtUtc'] as String, endsWith('Z'));
    expect(serialized.isUtc, isTrue);
    // Shifted back by the device offset once — never twice.
    expect(serialized, picked.toUtc());
    expect(
      serialized,
      DateTime.utc(2026, 9, 9, 15, 52).subtract(picked.timeZoneOffset),
    );
  });

  test('a local 15:52 selection at UTC+02 is sent as 13:52 UTC', () async {
    late http.Request sent;
    final service = AnnouncementService(
      ApiClient(
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(const <String, dynamic>{}), 200);
        }),
      ),
    );

    // The instant a UTC+02 admin selects when picking 09.09.2026 15:52.
    final pickedAtPlusTwo = DateTime.parse('2026-09-09T15:52:00+02:00');
    await service.save(
      'token',
      title: 'Title',
      message: 'Message',
      publishAtUtc: pickedAtPlusTwo.toUtc(),
    );

    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(
      DateTime.parse(body['publishAtUtc'] as String),
      DateTime.utc(2026, 9, 9, 13, 52),
    );
  });

  test('an already-UTC value is not shifted a second time on send', () async {
    late http.Request sent;
    final service = AnnouncementService(
      ApiClient(
        httpClient: MockClient((request) async {
          sent = request;
          return http.Response(jsonEncode(const <String, dynamic>{}), 200);
        }),
      ),
    );

    await service.save(
      'token',
      title: 'Title',
      message: 'Message',
      publishAtUtc: DateTime.utc(2026, 9, 9, 13, 52),
    );

    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(
      DateTime.parse(body['publishAtUtc'] as String),
      DateTime.utc(2026, 9, 9, 13, 52),
    );
  });

  test('editing round-trips the stored instant back to the same UTC', () {
    final stored = _announcement('2026-09-09T13:52:00');

    // The dialog seeds its pickers with the local wall clock and converts back.
    final seeded = stored.publishAtUtc.toLocal();
    final rebuilt = DateTime(
      seeded.year,
      seeded.month,
      seeded.day,
      seeded.hour,
      seeded.minute,
    );

    expect(rebuilt.toUtc(), stored.publishAtUtc);
  });
}

Announcement _announcement(String publishAt) => Announcement.fromJson({
  'id': 'announcement-1',
  'title': 'Important notice',
  'message': 'Never share verification codes.',
  'publishAtUtc': publishAt,
  'createdAtUtc': publishAt,
  'isPublished': true,
});

const _preferences = AdminPreferences(
  themeMode: 'light',
  sidebarStyle: 'expanded',
  dateFormat: 'DD.MM.YYYY',
  timeFormat: '24h',
  firstDayOfWeek: 'monday',
  numberFormat: '1,234.56',
  defaultItemsPerPage: 20,
  timezone: 'Europe/Sarajevo',
);
