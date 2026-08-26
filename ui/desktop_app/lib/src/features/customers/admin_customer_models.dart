import '../../core/currency_amount.dart';

class AdminCustomerPage {
  const AdminCustomerPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  factory AdminCustomerPage.fromJson(Map<String, dynamic> json) {
    return AdminCustomerPage(
      items: (json['items'] as List? ?? [])
          .map((item) => AdminCustomer.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
    );
  }

  final List<AdminCustomer> items;
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

class AdminCustomerSummary {
  const AdminCustomerSummary({
    required this.totalCustomers,
    required this.activeCustomers,
    required this.inactiveCustomers,
    required this.blockedCustomers,
  });

  factory AdminCustomerSummary.fromJson(Map<String, dynamic> json) {
    return AdminCustomerSummary(
      totalCustomers: json['totalCustomers'] as int? ?? 0,
      activeCustomers: json['activeCustomers'] as int? ?? 0,
      inactiveCustomers: json['inactiveCustomers'] as int? ?? 0,
      blockedCustomers: json['blockedCustomers'] as int? ?? 0,
    );
  }

  final int totalCustomers;
  final int activeCustomers;
  final int inactiveCustomers;
  final int blockedCustomers;
}

class AdminCustomer {
  const AdminCustomer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.status,
    required this.statusValue,
    required this.accountCount,
    required this.balances,
    required this.createdAtUtc,
  });

  factory AdminCustomer.fromJson(Map<String, dynamic> json) {
    return AdminCustomer(
      id: json['id']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      status: _statusLabel(json['status']),
      statusValue: _statusValue(json['status']),
      accountCount: json['accountCount'] as int? ?? 0,
      balances: (json['balances'] as List? ?? [])
          .map((item) => CurrencyAmount.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String status;
  final int statusValue;
  final int accountCount;
  final List<CurrencyAmount> balances;
  final DateTime createdAtUtc;
}

String _statusLabel(Object? value) {
  return switch (value?.toString()) {
    '1' => 'Active',
    '2' => 'Inactive',
    '3' => 'Blocked',
    final label when label != null && label.isNotEmpty => label,
    _ => 'Unknown',
  };
}

int _statusValue(Object? value) {
  return switch (value?.toString()) {
    '1' || 'Active' => 1,
    '2' || 'Inactive' => 2,
    '3' || 'Blocked' => 3,
    _ => 0,
  };
}
