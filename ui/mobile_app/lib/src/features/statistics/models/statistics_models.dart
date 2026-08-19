import '../../accounts/account_models.dart';
import '../../transactions/transaction_models.dart';

enum StatisticsMetric { spending, income }

class StatisticsData {
  const StatisticsData({required this.accounts, required this.currencySeries});

  factory StatisticsData.fromJson(Map<String, dynamic> json) => StatisticsData(
    accounts: (json['accounts'] as List? ?? [])
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList(),
    currencySeries: (json['currencySeries'] as List? ?? [])
        .map((e) => CurrencyStatistics.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final List<Account> accounts;
  final List<CurrencyStatistics> currencySeries;
}

class CurrencyStatistics {
  const CurrencyStatistics({
    required this.currency,
    required this.balance,
    required this.months,
  });

  factory CurrencyStatistics.fromJson(Map<String, dynamic> json) =>
      CurrencyStatistics(
        currency: json['currency']?.toString() ?? '',
        balance: (json['balance'] as num? ?? 0).toDouble(),
        months: (json['months'] as List? ?? [])
            .map((e) => MonthlyStatistics.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String currency;
  final double balance;
  final List<MonthlyStatistics> months;
}

class MonthlyStatistics {
  const MonthlyStatistics({
    required this.year,
    required this.month,
    required this.income,
    required this.spending,
    required this.recentTransactions,
  });

  factory MonthlyStatistics.fromJson(Map<String, dynamic> json) =>
      MonthlyStatistics(
        year: json['year'] as int? ?? 0,
        month: json['month'] as int? ?? 1,
        income: (json['income'] as num? ?? 0).toDouble(),
        spending: (json['spending'] as num? ?? 0).toDouble(),
        recentTransactions: (json['recentTransactions'] as List? ?? [])
            .map((e) => BankTransaction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int year;
  final int month;
  final double income;
  final double spending;
  final List<BankTransaction> recentTransactions;
  double get net => income - spending;
  DateTime get start => DateTime.utc(year, month);
  DateTime get end => DateTime.utc(year, month + 1);
}

class StatisticsHistoryRequest {
  const StatisticsHistoryRequest({
    this.accountId,
    required this.from,
    required this.to,
  });
  final String? accountId;
  final DateTime from;
  final DateTime to;
}
