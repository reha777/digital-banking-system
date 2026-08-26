import 'admin_settings_models.dart';

class AdminDateTimeFormatter {
  const AdminDateTimeFormatter(this.preferences);

  final AdminPreferences preferences;

  String date(DateTime utc) => _date(_inSelectedZone(utc));

  String time(DateTime utc) {
    final value = _inSelectedZone(utc);
    if (preferences.timeFormat == '12h') {
      final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
      return '$hour:${_two(value.minute)} ${value.hour < 12 ? 'AM' : 'PM'}';
    }
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  String dateTime(DateTime utc) => '${date(utc)} ${time(utc)}';

  DateTime _inSelectedZone(DateTime value) {
    final utc = value.toUtc();
    if (preferences.timezone == 'UTC') return utc;
    return utc.add(Duration(hours: _europeOffsetHours(utc)));
  }

  String _date(DateTime value) {
    final day = _two(value.day), month = _two(value.month);
    return switch (preferences.dateFormat) {
      'DD/MM/YYYY' => '$day/$month/${value.year}',
      'MM/DD/YYYY' => '$month/$day/${value.year}',
      'YYYY-MM-DD' => '${value.year}-$month-$day',
      _ => '$day.$month.${value.year}.',
    };
  }

  static int _europeOffsetHours(DateTime utc) {
    final start = _lastSundayUtc(utc.year, 3);
    final end = _lastSundayUtc(utc.year, 10);
    return !utc.isBefore(start) && utc.isBefore(end) ? 2 : 1;
  }

  static DateTime _lastSundayUtc(int year, int month) {
    final last = DateTime.utc(year, month + 1, 0);
    return DateTime.utc(year, month, last.day - (last.weekday % 7), 1);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
