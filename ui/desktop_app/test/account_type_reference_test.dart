import 'package:desktop_app/src/features/account_types/account_type_service.dart';
import 'package:desktop_app/src/features/customers/customer_details_models.dart';
import 'package:desktop_app/src/features/loans/models/admin_loan_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin account type list parses arbitrary reference value', () {
    final value = AccountTypeItem.fromJson({
      'id': '1',
      'code': 'BUSINESS',
      'name': 'Business Account',
      'isActive': false,
    });
    expect(value.code, 'BUSINESS');
    expect(value.name, 'Business Account');
    expect(value.isActive, isFalse);
  });
  test(
    'customer account display prefers accountTypeName without enum mapping',
    () {
      final value = AdminCustomerAccount.fromJson({
        'id': '1',
        'accountNumber': 'BA-1',
        'accountTypeName': 'Business Account',
        'accountType': '1',
        'status': 'Active',
        'balance': 0,
        'currency': 'USD',
        'createdAtUtc': '2026-01-01T00:00:00Z',
      });
      expect(value.accountType, 'Business Account');
    },
  );
  test('customer account keeps seeded reference names', () {
    Map<String, dynamic> account(String name) => {
      'id': '1',
      'accountNumber': 'BA-1',
      'accountTypeName': name,
      'status': 'Active',
      'balance': 0,
      'currency': 'BAM',
      'createdAtUtc': '2026-01-01T00:00:00Z',
    };

    expect(
      AdminCustomerAccount.fromJson(account('Checking')).accountType,
      'Checking',
    );
    expect(
      AdminCustomerAccount.fromJson(account('Savings')).accountType,
      'Savings',
    );
  });
  test('loan destination account renders the dynamic type name', () {
    final value = AdminLoanDestinationAccount.fromJson({
      'accountId': 'account-1',
      'maskedAccountNumber': '****0001',
      'accountTypeName': 'Business Account',
      'accountType': '2',
      'currency': 'BAM',
      'currentBalance': 120,
    });

    expect(value.accountType, 'Business Account');
    expect(value.accountType, isNot('Savings'));
  });
  test('loan destination account has no numeric enum mapping', () {
    final value = AdminLoanDestinationAccount.fromJson({
      'accountId': 'account-1',
      'maskedAccountNumber': '****0001',
      'accountType': '2',
      'currency': 'BAM',
      'currentBalance': 120,
    });

    expect(value.accountType, '2');
    expect(value.accountType, isNot('Savings'));
  });
}
