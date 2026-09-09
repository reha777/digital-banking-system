import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/src/features/accounts/account_models.dart';

void main() {
  test('account parser prefers dynamic accountTypeName', () {
    final account = Account.fromJson({
      'id': '1',
      'accountNumber': 'BA-1',
      'balance': 10,
      'currency': 'USD',
      'accountTypeName': 'Business Account',
      'accountType': 'Legacy',
    });
    expect(account.accountType, 'Business Account');
  });

  test('account parser has no numeric enum mapping', () {
    final account = Account.fromJson({
      'id': '1',
      'accountNumber': 'BA-1',
      'balance': 10,
      'currency': 'USD',
      'accountType': '1',
    });
    expect(account.accountType, '1');
    expect(account.accountType, isNot('Checking'));
  });

  test('seeded and admin-created types resolve from reference data', () {
    final summary = AccountBalanceSummary.fromJson({
      'totals': const [],
      'accounts': [
        {
          'id': '1',
          'accountNumber': 'BA-1',
          'balance': 10,
          'currency': 'BAM',
          'accountTypeId': 'type-checking',
          'accountTypeCode': 'CHECKING',
          'accountTypeName': 'Checking',
          'accountType': 'Checking',
        },
        {
          'id': '2',
          'accountNumber': 'BA-2',
          'balance': 20,
          'currency': 'BAM',
          'accountTypeId': 'type-savings',
          'accountTypeCode': 'SAVINGS',
          'accountTypeName': 'Savings',
          'accountType': 'Savings',
        },
        {
          'id': '3',
          'accountNumber': 'BA-3',
          'balance': 30,
          'currency': 'BAM',
          'accountTypeId': 'type-business',
          'accountTypeCode': 'BUSINESS',
          'accountTypeName': 'Business Account',
          'accountType': 'Business Account',
        },
      ],
    });

    expect(summary.accounts.map((account) => account.accountType), [
      'Checking',
      'Savings',
      'Business Account',
    ]);
  });

  test('renamed reference data flows through without a code change', () {
    Account named(String name) => Account.fromJson({
      'id': '3',
      'accountNumber': 'BA-3',
      'balance': 30,
      'currency': 'BAM',
      'accountTypeCode': 'BUSINESS',
      'accountTypeName': name,
    });

    expect(named('Business').accountType, 'Business');
    expect(named('Business Account').accountType, 'Business Account');
  });

  test('missing account type falls back to a neutral label', () {
    final account = Account.fromJson({
      'id': '4',
      'accountNumber': 'BA-4',
      'balance': 0,
      'currency': 'BAM',
    });

    expect(account.accountType, 'Account');
    expect(account.accountType, isNot('Checking'));
  });
}
