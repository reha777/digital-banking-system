import 'package:desktop_app/src/features/settings/settings_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session timeout follows backend bounds', () {
    expect(SettingsValidation.timeout('abc'), isNotNull);
    expect(SettingsValidation.timeout('4'), isNotNull);
    expect(SettingsValidation.timeout('481'), isNotNull);
    expect(SettingsValidation.timeout('5'), isNull);
    expect(SettingsValidation.timeout('480'), isNull);
  });

  test('warning follows bounds and must be shorter than timeout', () {
    expect(SettingsValidation.warning('abc', '30'), isNotNull);
    expect(SettingsValidation.warning('0', '30'), isNotNull);
    expect(SettingsValidation.warning('61', '100'), isNotNull);
    expect(SettingsValidation.warning('30', '30'), isNotNull);
    expect(SettingsValidation.warning('5', '30'), isNull);
  });
}
