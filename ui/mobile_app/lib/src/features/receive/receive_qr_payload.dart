import 'dart:convert';

class ReceiveQrPayloadException implements Exception {
  const ReceiveQrPayloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiveQrPayload {
  const ReceiveQrPayload({required this.accountNumber, required this.currency});

  static const version = 1;
  static const type = 'receive_money';
  static final _accountPattern = RegExp(r'^[A-Za-z0-9-]{1,34}$');
  static final _currencyPattern = RegExp(r'^[A-Z]{3}$');

  final String accountNumber;
  final String currency;

  String encode() => jsonEncode({
    'version': version,
    'type': type,
    'accountNumber': accountNumber,
    'currency': currency,
  });

  static ReceiveQrPayload decode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        throw const ReceiveQrPayloadException('Invalid Receive Money QR code.');
      }
      if (decoded['version'] != version) {
        throw const ReceiveQrPayloadException(
          'This Receive Money QR version is not supported.',
        );
      }
      if (decoded['type'] != type) {
        throw const ReceiveQrPayloadException(
          'This QR code is not a Receive Money code.',
        );
      }
      final accountNumber = decoded['accountNumber']?.toString().trim() ?? '';
      final currency =
          decoded['currency']?.toString().trim().toUpperCase() ?? '';
      if (!_accountPattern.hasMatch(accountNumber) ||
          !_currencyPattern.hasMatch(currency)) {
        throw const ReceiveQrPayloadException('Invalid Receive Money QR code.');
      }
      return ReceiveQrPayload(accountNumber: accountNumber, currency: currency);
    } on ReceiveQrPayloadException {
      rethrow;
    } on FormatException {
      throw const ReceiveQrPayloadException('Invalid Receive Money QR code.');
    }
  }
}
