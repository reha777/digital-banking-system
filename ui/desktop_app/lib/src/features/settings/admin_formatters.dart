class AdminFormatters {
  static String numberFormat = '1,234.56';

  static String number(num value, {bool currency = false}) {
    final parts = value.toStringAsFixed(2).split('.');
    final groups = <String>[];
    for (var end = parts.first.length; end > 0; end -= 3) {
      groups.insert(0, parts.first.substring((end - 3).clamp(0, end), end));
    }
    final european = numberFormat == '1.234,56';
    final formatted =
        '${groups.join(european ? '.' : ',')}${european ? ',' : '.'}${parts.last}';
    return currency ? '\$$formatted' : formatted;
  }
}
