import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/formatting/date_formatters.dart';
import 'package:mobile_app/src/features/notifications/notification_model.dart';

void main() {
  test('published announcement parses title message and UTC publish date', () {
    final value = _announcement('2026-09-09T10:30:00Z');
    expect(value.title, 'Scheduled maintenance');
    expect(value.message, 'Service window.');
    expect(value.publishAtUtc.isUtc, isTrue);
    expect(value.publishAtUtc, DateTime.utc(2026, 9, 9, 10, 30));
  });

  test('zone-less API timestamp is read as UTC, not as device local time', () {
    // SQL Server datetime2 materializes as DateTimeKind.Unspecified, so the API
    // serializes UTC instants without a trailing Z.
    final value = _announcement('2026-09-09T13:52:00');

    expect(value.publishAtUtc.isUtc, isTrue);
    expect(value.publishAtUtc, DateTime.utc(2026, 9, 9, 13, 52));
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
  });

  test('stored 13:52 UTC renders as 15:52 on a UTC+02 device', () {
    final value = _announcement('2026-09-09T13:52:00');

    // The wall clock a UTC+02 device shows for that instant.
    final atPlusTwo = value.publishAtUtc.add(const Duration(hours: 2));
    expect(formatWallClockDateTime(atPlusTwo), '09.09.2026 15:52');
  });

  test('announcement dates render in device local time', () {
    final value = _announcement('2026-09-09T13:52:00');
    final local = value.publishAtUtc.toLocal();

    expect(
      formatLocalDateTime(value.publishAtUtc),
      formatWallClockDateTime(local),
    );
    // Never the raw UTC clock reading unless the device really is on UTC.
    expect(
      formatLocalDateTime(value.publishAtUtc) ==
          formatWallClockDateTime(value.publishAtUtc),
      local.timeZoneOffset == Duration.zero,
    );
  });
}

SystemAnnouncement _announcement(String publishAt) =>
    SystemAnnouncement.fromJson({
      'id': 'announcement-1',
      'title': 'Scheduled maintenance',
      'message': 'Service window.',
      'publishAtUtc': publishAt,
    });
