class PagedTransactions {
  const PagedTransactions({
    required this.items,
  });

  factory PagedTransactions.fromJson(Map<String, dynamic> json) {
    return PagedTransactions(
      items: (json['items'] as List? ?? [])
          .map((item) => BankTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<BankTransaction> items;
}

class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.accountId,
    required this.accountNumber,
    required this.referenceNumber,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAtUtc,
    this.sourceAccountNumber,
    this.destinationAccountNumber,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    return BankTransaction(
      id: json['id']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      referenceNumber: json['referenceNumber']?.toString() ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      sourceAccountNumber: json['sourceAccountNumber']?.toString(),
      destinationAccountNumber: json['destinationAccountNumber']?.toString(),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String accountId;
  final String accountNumber;
  final String referenceNumber;
  final double amount;
  final String description;
  final String status;
  final DateTime createdAtUtc;
  final String? sourceAccountNumber;
  final String? destinationAccountNumber;
}

class MoneyTransferResult {
  const MoneyTransferResult({
    required this.referenceNumber,
    required this.status,
    required this.amount,
    required this.currency,
  });

  factory MoneyTransferResult.fromJson(Map<String, dynamic> json) {
    return MoneyTransferResult(
      referenceNumber: json['referenceNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? '',
    );
  }

  final String referenceNumber;
  final String status;
  final double amount;
  final String currency;
}
