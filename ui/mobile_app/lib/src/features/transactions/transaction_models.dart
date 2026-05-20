class PagedTransactions {
  const PagedTransactions({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory PagedTransactions.fromJson(Map<String, dynamic> json) {
    return PagedTransactions(
      items: (json['items'] as List? ?? [])
          .map((item) => BankTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  final List<BankTransaction> items;
  final int page;
  final int pageSize;
  final int totalCount;

  int get totalPages {
    if (totalCount == 0) {
      return 1;
    }

    return ((totalCount + pageSize - 1) / pageSize).floor();
  }
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
      status: _statusLabel(json['status']),
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

String _statusLabel(Object? value) {
  return switch (value?.toString()) {
    '1' => 'Pending',
    '2' => 'Completed',
    '3' => 'Failed',
    '4' => 'Cancelled',
    final label when label != null && label.isNotEmpty => label,
    _ => 'Unknown',
  };
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
