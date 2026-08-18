class BankCardModel {
  const BankCardModel({
    required this.id,
    required this.accountId,
    required this.accountNumber,
    required this.cardNumber,
    required this.maskedCardNumber,
    required this.cardholderName,
    required this.cvv,
    required this.expiryDate,
    required this.brand,
    required this.status,
    required this.balance,
    required this.currency,
  });

  factory BankCardModel.fromJson(Map<String, dynamic> json) {
    return BankCardModel(
      id: json['id']?.toString() ?? '',
      accountId: json['accountId']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      cardNumber: json['cardNumber']?.toString() ?? '',
      maskedCardNumber: json['maskedCardNumber']?.toString() ?? '',
      cardholderName: json['cardholderName']?.toString() ?? '',
      cvv: json['cvv']?.toString() ?? '',
      expiryDate:
          DateTime.tryParse(json['expiryDate']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      brand: _brandLabel(json['brand']),
      status: _statusLabel(json['status']),
      balance: (json['balance'] as num? ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? '',
    );
  }

  final String id;
  final String accountId;
  final String accountNumber;
  final String cardNumber;
  final String maskedCardNumber;
  final String cardholderName;
  final String cvv;
  final DateTime expiryDate;
  final String brand;
  final String status;
  final double balance;
  final String currency;

  bool get isActive => status == 'Active';
  bool get isFrozen => status == 'Blocked';
  bool get canTransfer => isActive;

  BankCardModel copyWith({String? status, String? cardNumber, String? cvv}) =>
      BankCardModel(
        id: id,
        accountId: accountId,
        accountNumber: accountNumber,
        cardNumber: cardNumber ?? this.cardNumber,
        maskedCardNumber: maskedCardNumber,
        cardholderName: cardholderName,
        cvv: cvv ?? this.cvv,
        expiryDate: expiryDate,
        brand: brand,
        status: status ?? this.status,
        balance: balance,
        currency: currency,
      );
}

class CardRequestModel {
  const CardRequestModel({
    required this.id,
    required this.status,
    required this.statusValue,
    required this.currency,
    required this.documentsRequestNote,
    required this.documents,
    required this.createdAtUtc,
    this.adminNote,
  });

  factory CardRequestModel.fromJson(Map<String, dynamic> json) {
    return CardRequestModel(
      id: json['id']?.toString() ?? '',
      status: _requestStatusLabel(json['status']),
      statusValue: _requestStatusValue(json['status']),
      currency: json['currency']?.toString() ?? '',
      documentsRequestNote: json['documentsRequestNote']?.toString(),
      documents: (json['documents'] as List? ?? [])
          .map(
            (item) =>
                CardRequestDocumentModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      adminNote: json['adminNote']?.toString(),
    );
  }

  final String id;
  final String status;
  final int statusValue;
  final String currency;
  final String? documentsRequestNote;
  final List<CardRequestDocumentModel> documents;
  final DateTime createdAtUtc;
  final String? adminNote;

  bool get requiresDocuments => statusValue == 4;
  bool get hasSubmittedDocuments => requiresDocuments && documents.isNotEmpty;
}

class CardRequestDocumentModel {
  const CardRequestDocumentModel({
    required this.id,
    required this.fileName,
    required this.uploadedAtUtc,
  });

  factory CardRequestDocumentModel.fromJson(Map<String, dynamic> json) {
    return CardRequestDocumentModel(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? 'Document',
      uploadedAtUtc:
          DateTime.tryParse(json['uploadedAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String fileName;
  final DateTime uploadedAtUtc;
}

String _brandLabel(Object? value) {
  return switch (value?.toString()) {
    '1' => 'Mastercard',
    '2' => 'Visa',
    final label when label != null && label.isNotEmpty => label,
    _ => 'Mastercard',
  };
}

String _statusLabel(Object? value) {
  return switch (value?.toString()) {
    '1' => 'Active',
    '2' => 'Blocked',
    '3' => 'Expired',
    final label when label != null && label.isNotEmpty => label,
    _ => 'Active',
  };
}

String _requestStatusLabel(Object? value) {
  return switch (value?.toString()) {
    '1' => 'Pending',
    '2' => 'Approved',
    '3' => 'Rejected',
    '4' => 'Documents requested',
    final label when label != null && label.isNotEmpty => label,
    _ => 'Pending',
  };
}

int _requestStatusValue(Object? value) {
  return switch (value?.toString()) {
    'Pending' => 1,
    'Approved' => 2,
    'Rejected' => 3,
    'DocumentsRequested' => 4,
    'Documents requested' => 4,
    final label when label != null => int.tryParse(label) ?? 1,
    _ => 1,
  };
}
