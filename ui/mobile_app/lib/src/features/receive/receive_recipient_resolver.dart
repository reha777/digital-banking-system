import '../transactions/transaction_models.dart';
import '../transactions/transaction_service.dart';
import 'receive_qr_payload.dart';

class ReceiveRecipientResolver {
  const ReceiveRecipientResolver(this._transactionService);

  final TransactionService _transactionService;

  Future<RecentRecipient> resolve({
    required String rawValue,
    required String sourceAccountNumber,
    required String token,
  }) async {
    final payload = ReceiveQrPayload.decode(rawValue);
    if (payload.accountNumber == sourceAccountNumber) {
      throw const ReceiveQrPayloadException(
        "You can't send money to the same account.",
      );
    }
    return _transactionService.lookupRecipient(
      token: token,
      accountNumber: payload.accountNumber,
    );
  }
}
