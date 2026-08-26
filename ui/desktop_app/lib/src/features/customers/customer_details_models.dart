import '../../core/currency_amount.dart';

class AdminCustomerDetails {
  const AdminCustomerDetails({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.status,
    required this.statusValue,
    required this.createdAtUtc,
    required this.balances,
    required this.accounts,
    required this.summary,
  });

  factory AdminCustomerDetails.fromJson(Map<String, dynamic> json) =>
      AdminCustomerDetails(
        id: json['id']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        status: _customerStatus(json['status']),
        statusValue: _int(json['status']),
        createdAtUtc:
            DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        balances: (json['balances'] as List? ?? [])
            .map(
              (item) => CurrencyAmount.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        accounts: (json['accounts'] as List? ?? [])
            .map(
              (item) =>
                  AdminCustomerAccount.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        summary: AdminCustomerRelationshipSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {},
        ),
      );

  final String id, firstName, lastName, fullName, email, phoneNumber, status;
  final int statusValue;
  final DateTime createdAtUtc;
  final List<CurrencyAmount> balances;
  final List<AdminCustomerAccount> accounts;
  final AdminCustomerRelationshipSummary summary;
}

class AdminCustomerAccount {
  const AdminCustomerAccount({
    required this.id,
    required this.accountNumber,
    required this.accountType,
    required this.balance,
    required this.currency,
    required this.createdAtUtc,
    this.card,
  });
  factory AdminCustomerAccount.fromJson(Map<String, dynamic> json) =>
      AdminCustomerAccount(
        id: json['id']?.toString() ?? '',
        accountNumber: json['accountNumber']?.toString() ?? '',
        accountType: switch (json['accountType']?.toString().toLowerCase()) {
          '1' || 'checking' => 'Checking',
          '2' || 'savings' => 'Savings',
          _ => 'Account',
        },
        balance: (json['balance'] as num? ?? 0).toDouble(),
        currency: json['currency']?.toString() ?? '',
        createdAtUtc:
            DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        card: json['card'] is Map<String, dynamic>
            ? AdminCustomerCard.fromJson(json['card'] as Map<String, dynamic>)
            : null,
      );
  final String id, accountNumber, accountType, currency;
  final double balance;
  final DateTime createdAtUtc;
  final AdminCustomerCard? card;
}

class AdminCustomerCard {
  const AdminCustomerCard({
    required this.id,
    required this.maskedCardNumber,
    required this.cardholderName,
    required this.expiryDate,
    required this.brand,
    required this.status,
    required this.createdAtUtc,
  });
  factory AdminCustomerCard.fromJson(Map<String, dynamic> json) =>
      AdminCustomerCard(
        id: json['id']?.toString() ?? '',
        maskedCardNumber: json['maskedCardNumber']?.toString() ?? '',
        cardholderName: json['cardholderName']?.toString() ?? '',
        expiryDate:
            DateTime.tryParse(json['expiryDate']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        brand: switch (json['brand']?.toString().toLowerCase()) {
          '1' || 'visa' => 'Visa',
          '2' || 'mastercard' => 'Mastercard',
          final value when value != null && value.isNotEmpty => value,
          _ => 'Card',
        },
        status: switch (json['status']?.toString().toLowerCase()) {
          '1' || 'active' => 'Active',
          '2' || 'blocked' => 'Blocked',
          '3' || 'expired' => 'Expired',
          final value when value != null && value.isNotEmpty => value,
          _ => 'Unknown',
        },
        createdAtUtc:
            DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
  final String id, maskedCardNumber, cardholderName, brand, status;
  final DateTime expiryDate, createdAtUtc;
}

class AdminCustomerRelationshipSummary {
  const AdminCustomerRelationshipSummary({
    required this.accountCount,
    required this.cardCount,
    required this.activeLoanCount,
    required this.pendingCardRequestCount,
    required this.pendingTransactionReviewCount,
    required this.pendingLoanApplicationCount,
  });
  factory AdminCustomerRelationshipSummary.fromJson(
    Map<String, dynamic> json,
  ) => AdminCustomerRelationshipSummary(
    accountCount: _int(json['accountCount']),
    cardCount: _int(json['cardCount']),
    activeLoanCount: _int(json['activeLoanCount']),
    pendingCardRequestCount: _int(json['pendingCardRequestCount']),
    pendingTransactionReviewCount: _int(json['pendingTransactionReviewCount']),
    pendingLoanApplicationCount: _int(json['pendingLoanApplicationCount']),
  );
  final int accountCount,
      cardCount,
      activeLoanCount,
      pendingCardRequestCount,
      pendingTransactionReviewCount,
      pendingLoanApplicationCount;
}

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
String _customerStatus(Object? value) =>
    switch (value?.toString().toLowerCase()) {
      '1' || 'active' => 'Active',
      '2' || 'inactive' => 'Inactive',
      '3' || 'blocked' => 'Blocked',
      _ => 'Unknown',
    };
