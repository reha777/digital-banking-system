String numericAccountNumber(String value) {
  final digits = value.replaceAll(RegExp('[^0-9]'), '');
  return digits.isEmpty ? '----' : digits;
}

String numericAccountEnding(String value) {
  final digits = numericAccountNumber(value);
  if (digits == '----') return digits;
  return digits.length <= 4
      ? digits.padLeft(4, '0')
      : digits.substring(digits.length - 4);
}

String maskedNumericAccount(String value) =>
    '•••• ${numericAccountEnding(value)}';
