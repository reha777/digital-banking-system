const supportedCurrencies = <String>['USD', 'EUR', 'BAM'];

final supportedCurrencyOptions = <String, String>{
  for (final currency in supportedCurrencies) currency: currency,
};
