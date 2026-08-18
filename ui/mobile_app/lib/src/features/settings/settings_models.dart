class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.displayName,
    required this.localeCode,
  });

  final String code;
  final String displayName;
  final String localeCode;
}

const supportedLanguages = <SupportedLanguage>[
  SupportedLanguage(code: 'en', displayName: 'English', localeCode: 'en'),
  SupportedLanguage(code: 'de', displayName: 'German', localeCode: 'de'),
  SupportedLanguage(code: 'bs', displayName: 'Bosnian', localeCode: 'bs'),
  SupportedLanguage(code: 'fr', displayName: 'French', localeCode: 'fr'),
  SupportedLanguage(code: 'it', displayName: 'Italian', localeCode: 'it'),
];
