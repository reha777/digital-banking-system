class MobileApiEndpoints {
  const MobileApiEndpoints._();

  static const accountsBalance = '/api/accounts/balance';
  static const cards = '/api/cards/my';
  static const cardRequests = '/api/cards/requests';
  static const myCardRequests = '/api/cards/requests/my';
  static const transactions = '/api/transactions';
  static const sendMoney = '/api/transactions/send-money';
  static const transferQuote = '/api/transactions/quote';
  static const recentRecipients = '/api/transactions/recent-recipients';
  static const recipientLookup = '/api/transactions/recipients/lookup';

  static String cardRequestDocuments(String requestId) {
    return '/api/cards/requests/$requestId/documents';
  }

  static String cardSensitiveData(String cardId) =>
      '/api/cards/$cardId/sensitive-data';
  static String freezeCard(String cardId) => '/api/cards/$cardId/freeze';
  static String unfreezeCard(String cardId) => '/api/cards/$cardId/unfreeze';
}
