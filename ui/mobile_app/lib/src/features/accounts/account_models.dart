class AccountBalanceSummary {
  const AccountBalanceSummary({required this.totals, required this.accounts});

  factory AccountBalanceSummary.fromJson(Map<String, dynamic> json) {
    return AccountBalanceSummary(
      totals: (json['totals'] as List? ?? [])
          .map((item) => CurrencyBalance.fromJson(item as Map<String, dynamic>))
          .toList(),
      accounts: (json['accounts'] as List? ?? [])
          .map((item) => Account.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<CurrencyBalance> totals;
  final List<Account> accounts;

  Account? get primaryAccount => accounts.isEmpty ? null : accounts.first;

  CurrencyBalance? get primaryTotal => totals.isEmpty ? null : totals.first;
}

class CurrencyBalance {
  const CurrencyBalance({required this.currency, required this.balance});

  factory CurrencyBalance.fromJson(Map<String, dynamic> json) {
    return CurrencyBalance(
      currency: json['currency']?.toString() ?? '',
      balance: (json['balance'] as num? ?? 0).toDouble(),
    );
  }

  final String currency;
  final double balance;
}

class Account {
  const Account({
    required this.id,
    required this.accountNumber,
    required this.balance,
    required this.currency,
    this.accountType = 'Account',
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      balance: (json['balance'] as num? ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? '',
      accountType: _accountTypeLabel(json),
    );
  }

  final String id;
  final String accountNumber;
  final double balance;
  final String currency;
  final String accountType;
}

String _accountTypeLabel(Map<String, dynamic> json) {
  final name = json['accountTypeName']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final compatibility = json['accountType']?.toString().trim();
  return compatibility != null && compatibility.isNotEmpty
      ? compatibility
      : 'Account';
}
