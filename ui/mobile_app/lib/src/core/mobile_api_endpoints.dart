class MobileApiEndpoints {
  const MobileApiEndpoints._();

  static const accountsBalance = '/api/accounts/balance';
  static const cards = '/api/cards/my';
  static const cardRequests = '/api/cards/requests';
  static const myCardRequests = '/api/cards/requests/my';
  static const transactions = '/api/transactions';
  static const sendMoney = '/api/transactions/send-money';

  static String cardRequestDocuments(String requestId) {
    return '/api/cards/requests/$requestId/documents';
  }
}
