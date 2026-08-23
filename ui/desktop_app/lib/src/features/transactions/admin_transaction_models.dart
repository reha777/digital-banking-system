import '../../core/currency_amount.dart';

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
          .map(
            (item) => AdminTransaction.fromJson(item as Map<String, dynamic>),
          )
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
    required this.transferredByCurrency,
  });

  factory AdminTransactionSummary.fromJson(Map<String, dynamic> json) {
    return AdminTransactionSummary(
      totalTransactions: json['totalTransactions'] as int? ?? 0,
      completedTransactions: json['completedTransactions'] as int? ?? 0,
      transferredByCurrency: (json['transferredByCurrency'] as List? ?? [])
          .map((item) => CurrencyAmount.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int totalTransactions;
  final int completedTransactions;
  final List<CurrencyAmount> transferredByCurrency;
}

class AdminTransaction {
  const AdminTransaction({
    required this.id,
    required this.accountNumber,
    required this.referenceNumber,
    required this.amount,
    required this.currency,
    required this.type,
    required this.description,
    required this.status,
    required this.statusValue,
    required this.isHighRiskReview,
    required this.createdAtUtc,
    this.reviewReason,
    this.documentsRequestNote,
    this.adminNote,
    this.reviewedAtUtc,
    this.documents = const [],
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
      currency: json['currency']?.toString().toUpperCase() ?? '',
      type: _transactionType(json['type']),
      description: json['description']?.toString() ?? '',
      statusValue: _statusValue(json['status']),
      status: _statusLabel(json['status']),
      isHighRiskReview: json['isHighRiskReview'] as bool? ?? false,
      reviewReason: json['reviewReason']?.toString(),
      documentsRequestNote: json['documentsRequestNote']?.toString(),
      adminNote: json['adminNote']?.toString(),
      reviewedAtUtc: DateTime.tryParse(json['reviewedAtUtc']?.toString() ?? ''),
      documents: (json['documents'] as List? ?? [])
          .map(
            (item) =>
                AdminTransactionDocument.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      sourceAccountNumber: json['sourceAccountNumber']?.toString(),
      destinationAccountNumber: json['destinationAccountNumber']?.toString(),
      sourceCustomerName: json['sourceCustomerName']?.toString(),
      destinationCustomerName: json['destinationCustomerName']?.toString(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String accountNumber;
  final String referenceNumber;
  final double amount;
  final String currency;
  final AdminTransactionType type;
  final String description;
  final String status;
  final int statusValue;
  final bool isHighRiskReview;
  final DateTime createdAtUtc;
  final String? reviewReason;
  final String? documentsRequestNote;
  final String? adminNote;
  final DateTime? reviewedAtUtc;
  final List<AdminTransactionDocument> documents;
  final String? sourceAccountNumber;
  final String? destinationAccountNumber;
  final String? sourceCustomerName;
  final String? destinationCustomerName;
}

class AdminTransactionDocument {
  const AdminTransactionDocument({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAtUtc,
  });

  factory AdminTransactionDocument.fromJson(Map<String, dynamic> json) {
    return AdminTransactionDocument(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      sizeBytes: json['sizeBytes'] as int? ?? 0,
      uploadedAtUtc:
          DateTime.tryParse(json['uploadedAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final DateTime uploadedAtUtc;
}

String _statusLabel(Object? value) {
  return switch (value?.toString()) {
    '1' => 'Pending',
    '2' => 'Completed',
    '3' => 'Failed',
    '4' => 'Cancelled',
    '5' => 'Documents requested',
    'DocumentsRequested' => 'Documents requested',
    final label when label != null && label.isNotEmpty => label,
    _ => 'Unknown',
  };
}

int _statusValue(Object? value) {
  return switch (value?.toString()) {
    'Pending' => 1,
    'Completed' => 2,
    'Failed' => 3,
    'Cancelled' => 4,
    'DocumentsRequested' => 5,
    final label when label != null => int.tryParse(label) ?? 0,
    _ => 0,
  };
}

enum AdminTransactionType {
  transfer('Transfer'),
  internalTransfer('Internal Transfer'),
  loanDisbursement('Loan Disbursement'),
  loanRepayment('Loan Repayment');

  const AdminTransactionType(this.label);
  final String label;
}

AdminTransactionType _transactionType(Object? value) =>
    switch (value?.toString().toLowerCase()) {
      '2' || 'internaltransfer' => AdminTransactionType.internalTransfer,
      '3' || 'loandisbursement' => AdminTransactionType.loanDisbursement,
      '4' || 'loanrepayment' => AdminTransactionType.loanRepayment,
      _ => AdminTransactionType.transfer,
    };
