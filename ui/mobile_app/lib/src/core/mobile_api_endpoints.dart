class MobileApiEndpoints {
  const MobileApiEndpoints._();

  static const accountsBalance = '/api/accounts/balance';
  static const cards = '/api/cards/my';
  static const cardRequests = '/api/cards/requests';
  static const myCardRequests = '/api/cards/requests/my';
  static const transactions = '/api/transactions';
  static const statistics = '/api/transactions/statistics';
  static const sendMoney = '/api/transactions/send-money';
  static const transferQuote = '/api/transactions/quote';
  static const internalTransfer = '/api/transactions/internal-transfer';
  static const internalTransferQuote =
      '/api/transactions/internal-transfer/quote';
  static const recentRecipients = '/api/transactions/recent-recipients';
  static const recipientLookup = '/api/transactions/recipients/lookup';
  static const loanProducts = '/api/loans/products';
  static const loanRecommendations = '/api/loans/recommendations';
  static const loanPurposes = '/api/reference-data/loan-purposes';
  static const loanQuote = '/api/loans/quote';
  static const loanApplications = '/api/loans/applications';
  static const currentLoanApplication = '/api/loans/applications/current';
  static const currentLoan = '/api/loans/current';
  static const recentLoan = '/api/loans/recent';
  static String loanDetails(String id) => '/api/loans/$id';
  static String loanPaymentQuote(String id) => '/api/loans/$id/payment-quote';
  static String loanPayments(String id) => '/api/loans/$id/payments';

  static String cardRequestDocuments(String requestId) {
    return '/api/cards/requests/$requestId/documents';
  }

  static String cardSensitiveData(String cardId) =>
      '/api/cards/$cardId/sensitive-data';
  static String freezeCard(String cardId) => '/api/cards/$cardId/freeze';
  static String unfreezeCard(String cardId) => '/api/cards/$cardId/unfreeze';
}
