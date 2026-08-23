import '../features/settings/admin_formatters.dart';

class CurrencyAmount {
  const CurrencyAmount({required this.currency, required this.amount});

  factory CurrencyAmount.fromJson(Map<String, dynamic> json) => CurrencyAmount(
    currency: json['currency']?.toString().toUpperCase() ?? '',
    amount: (json['amount'] as num? ?? 0).toDouble(),
  );

  final String currency;
  final double amount;

  String get formatted =>
      '${currency.isEmpty ? '---' : currency} ${AdminFormatters.number(amount)}';
}

String formatCurrencyAmounts(List<CurrencyAmount> values) => values.isEmpty
    ? 'No balances'
    : values.map((value) => value.formatted).join('\n');
