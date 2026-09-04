import 'dart:ui' show Locale;

/// Languages the UI ships in, with their names in the language itself
/// (shown as-is in the language picker, never translated).
const List<Locale> kSupportedUiLocales = [
  Locale('en'),
  Locale('hi'),
  Locale('es'),
  Locale('fr'),
  Locale('de'),
  Locale('pt'),
  Locale('ar'),
  Locale('zh'),
  Locale('ru'),
  Locale('id'),
];

const Map<String, String> kLanguageNames = {
  'en': 'English',
  'hi': 'हिन्दी',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt': 'Português',
  'ar': 'العربية',
  'zh': '中文',
  'ru': 'Русский',
  'id': 'Bahasa Indonesia',
};

String languageNameOf(Locale locale) =>
    kLanguageNames[locale.languageCode] ?? locale.toLanguageTag();