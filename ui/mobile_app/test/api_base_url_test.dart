import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/core/api_client.dart';

void main() {
  group('API base URL resolution', () {
    test('Android emulator uses the host alias', () {
      expect(
        ApiClient.resolveBaseUrl(
          configuredBaseUrl: '',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'http://10.0.2.2:5026',
      );
    });

    test('Web uses localhost regardless of browser host platform', () {
      expect(
        ApiClient.resolveBaseUrl(
          configuredBaseUrl: '',
          isWeb: true,
          platform: TargetPlatform.windows,
        ),
        'http://localhost:5026',
      );
    });

    test('Windows uses localhost', () {
      expect(
        ApiClient.resolveBaseUrl(
          configuredBaseUrl: '',
          isWeb: false,
          platform: TargetPlatform.windows,
        ),
        'http://localhost:5026',
      );
    });

    test('explicit dart define value has highest priority', () {
      expect(
        ApiClient.resolveBaseUrl(
          configuredBaseUrl: 'http://example.test:9999',
          isWeb: false,
          platform: TargetPlatform.android,
        ),
        'http://example.test:9999',
      );
    });
  });
}
