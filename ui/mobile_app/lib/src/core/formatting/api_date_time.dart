/// Parses an API timestamp into a UTC [DateTime].
///
/// `datetime2` columns come back from SQL Server as `DateTimeKind.Unspecified`,
/// so the API serializes UTC instants without a `Z` suffix
/// (`2026-09-09T13:52:00`). `DateTime.parse` reads such a string as device-local
/// time, which shifts the instant by the local offset and makes the value render
/// as the raw UTC clock reading. A timestamp without an explicit zone designator
/// is therefore reinterpreted as UTC; values that do carry `Z` or an offset keep
/// the instant they already describe.
DateTime parseApiUtc(String value) {
  final text = value.trim();
  final parsed = DateTime.parse(text);
  if (_hasZoneDesignator(text)) return parsed.toUtc();
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

final _offsetSuffix = RegExp(r'[+-]\d{2}:?\d{2}$');

bool _hasZoneDesignator(String text) =>
    text.endsWith('Z') || text.endsWith('z') || _offsetSuffix.hasMatch(text);
