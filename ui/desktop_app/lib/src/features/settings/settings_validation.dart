abstract final class SettingsValidation {
  static String? timeout(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null) return 'Enter a whole number.';
    if (number < 5 || number > 480) return 'Use a value from 5 to 480.';
    return null;
  }

  static String? warning(String? value, String timeoutValue) {
    final warning = int.tryParse(value?.trim() ?? '');
    if (warning == null) return 'Enter a whole number.';
    if (warning < 1 || warning > 60) return 'Use a value from 1 to 60.';
    final timeout = int.tryParse(timeoutValue.trim());
    if (timeout != null && warning >= timeout) {
      return 'Warning must be shorter than timeout.';
    }
    return null;
  }
}
