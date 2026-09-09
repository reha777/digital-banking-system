String formatCardExpiry(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

/// `DD.MM.YYYY HH:mm` of the wall clock already held by [value], with no
/// timezone conversion of its own.
String formatWallClockDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

/// Renders a UTC instant from the API in the device's local time.
String formatLocalDateTime(DateTime utc) =>
    formatWallClockDateTime(utc.toLocal());
