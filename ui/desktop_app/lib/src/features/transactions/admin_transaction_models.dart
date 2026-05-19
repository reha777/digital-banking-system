class AdminTransactionPage {
  const AdminTransactionPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory AdminTransactionPage.fromJson(Map<String, dynamic> json) {
    return AdminTransactionPage(
      items: (json['items'] as List? ?? [])
          .map((item) => AdminTransaction.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  final List<AdminTransaction> items;
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

class AdminTransactionSummary {
  const AdminTransactionSummary({
    required this.totalTransactions,
    required this.completedTransactions,
    required this.totalTransferred,
  });

  factory AdminTransactionSummary.fromJson(Map<String, dynamic> json) {
    return AdminTransactionSummary(
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      completedTransactions: json['completedTransactions'] as int? ?? 0,
      totalTransferred: (json['totalTransferred'] as num? ?? 0).toDouble(),
    );
  }

  final int totalTransactions;
  final int completedTransactions;
  final double totalTransferred;
}

class AdminTransaction {
  const AdminTransaction({
    required this.id,
    required this.accountNumber,
    required this.referenceNumber,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdAtUtc,
    this.sourceAccountNumber,
    this.destinationAccountNumber,
    this.sourceCustomerName,
    this.destinationCustomerName,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    return AdminTransaction(
      id: json['id']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      referenceNumber: json['referenceNumber']?.toString() ?? '',
      amount: (json['amount'] as num? ?? 0).toDouble(),
      description: json['description']?.toString() ?? '',
      status: _statusLabel(json['status']),
      sourceAccountNumber: json['sourceAccountNumber']?.toString(),
      destinationAccountNumber: json['destinationAccountNumber']?.toString(),
      sourceCustomerName: json['sourceCustomerName']?.toString(),
      destinationCustomerName: json['destinationCustomerName']?.toString(),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String accountNumber;
  final String referenceNumber;
  final double amount;
  final String description;
  final String status;
  final DateTime createdAtUtc;
  final String? sourceAccountNumber;
  final String? destinationAccountNumber;
  final String? sourceCustomerName;
  final String? destinationCustomerName;
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
