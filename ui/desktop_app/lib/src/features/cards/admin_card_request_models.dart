class AdminCardRequestPage {
  const AdminCardRequestPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory AdminCardRequestPage.fromJson(Map<String, dynamic> json) {
    return AdminCardRequestPage(
      items: (json['items'] as List? ?? [])
          .map(
            (item) => AdminCardRequest.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  final List<AdminCardRequest> items;
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

class AdminCardRequestSummary {
  const AdminCardRequestSummary({
    required this.totalRequests,
    required this.pendingRequests,
    required this.approvedRequests,
    required this.rejectedRequests,
  });

  factory AdminCardRequestSummary.fromJson(Map<String, dynamic> json) {
    return AdminCardRequestSummary(
      totalRequests: json['totalRequests'] as int? ?? 0,
      pendingRequests: json['pendingRequests'] as int? ?? 0,
      approvedRequests: json['approvedRequests'] as int? ?? 0,
      rejectedRequests: json['rejectedRequests'] as int? ?? 0,
    );
  }

  final int totalRequests;
  final int pendingRequests;
  final int approvedRequests;
  final int rejectedRequests;
}

class AdminCardRequest {
  const AdminCardRequest({
    required this.id,
    required this.customerName,
    required this.customerEmail,
    required this.cardholderName,
    required this.currency,
    required this.documentNumber,
    required this.deliveryAddress,
    required this.note,
    required this.status,
    required this.statusValue,
    required this.createdAtUtc,
    required this.documents,
    this.adminNote,
    this.documentsRequestNote,
    this.documentsRequestedAtUtc,
    this.approvedAccountNumber,
    this.approvedMaskedCardNumber,
    this.reviewedAtUtc,
  });

  factory AdminCardRequest.fromJson(Map<String, dynamic> json) {
    final statusValue = _intValue(json['status']);
    return AdminCardRequest(
      id: json['id']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerEmail: json['customerEmail']?.toString() ?? '',
      cardholderName: json['cardholderName']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      documentNumber: json['documentNumber']?.toString() ?? '',
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      status: _statusLabel(statusValue, json['status']),
      statusValue: statusValue,
      documents: (json['documents'] as List? ?? [])
          .map(
            (item) =>
                AdminCardRequestDocument.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      adminNote: json['adminNote']?.toString(),
      documentsRequestNote: json['documentsRequestNote']?.toString(),
      documentsRequestedAtUtc: DateTime.tryParse(
        json['documentsRequestedAtUtc']?.toString() ?? '',
      ),
      approvedAccountNumber: json['approvedAccountNumber']?.toString(),
      approvedMaskedCardNumber: json['approvedMaskedCardNumber']?.toString(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      reviewedAtUtc: DateTime.tryParse(json['reviewedAtUtc']?.toString() ?? ''),
    );
  }

  final String id;
  final String customerName;
  final String customerEmail;
  final String cardholderName;
  final String currency;
  final String documentNumber;
  final String deliveryAddress;
  final String note;
  final String status;
  final int statusValue;
  final List<AdminCardRequestDocument> documents;
  final String? adminNote;
  final String? documentsRequestNote;
  final DateTime? documentsRequestedAtUtc;
  final String? approvedAccountNumber;
  final String? approvedMaskedCardNumber;
  final DateTime createdAtUtc;
  final DateTime? reviewedAtUtc;
}

class AdminCardRequestDocument {
  const AdminCardRequestDocument({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAtUtc,
  });

  factory AdminCardRequestDocument.fromJson(Map<String, dynamic> json) {
    return AdminCardRequestDocument(
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

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }

  final text = value?.toString().toLowerCase();
  return switch (text) {
    '1' || 'pending' => 1,
    '2' || 'approved' => 2,
    '3' || 'rejected' => 3,
    '4' || 'documentsrequested' || 'documents requested' => 4,
    _ => 0,
  };
}

String _statusLabel(int statusValue, Object? rawValue) {
  return switch (statusValue) {
    1 => 'Pending',
    2 => 'Approved',
    3 => 'Rejected',
    4 => 'Documents requested',
    _ => rawValue?.toString() ?? 'Unknown',
  };
}
