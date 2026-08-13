import '../accounts/account_models.dart';
import '../cards/card_models.dart';
import '../transactions/transaction_models.dart';

class DashboardData {
  const DashboardData({
    required this.balance,
    required this.transactions,
    required this.cards,
  });

  final AccountBalanceSummary balance;
  final List<BankTransaction> transactions;
  final List<BankCardModel> cards;

  BankCardModel? get primaryCard => cards.isEmpty ? null : cards.first;
}
