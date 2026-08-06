import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Fallback Material Localizations Delegate
/// This delegate provides fallback localizations for languages not supported
/// by Flutter's default Material localizations (e.g., Hausa, Swahili, Fulfulde).
/// It falls back to English for Material widgets.
class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true; // Support all locales

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // For unsupported locales (ha, sw, ff), use English
    const supportedLocales = [
      'en',
      'es',
      'fr',
      'de',
      'it',
      'pt',
      'ar',
      'zh',
      'ja',
      'ko',
    ];

    if (!supportedLocales.contains(locale.languageCode)) {
      // Fallback to English for Material widgets
      return await GlobalMaterialLocalizations.delegate.load(
        const Locale('en'),
      );
    }

    return await GlobalMaterialLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

/// Fallback Cupertino Localizations Delegate
/// This delegate provides fallback localizations for languages not supported
/// by Flutter's default Cupertino localizations.
class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true; // Support all locales

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    // For unsupported locales (ha, sw, ff), use English
    const supportedLocales = [
      'en',
      'es',
      'fr',
      'de',
      'it',
      'pt',
      'ar',
      'zh',
      'ja',
      'ko',
    ];

    if (!supportedLocales.contains(locale.languageCode)) {
      // Fallback to English for Cupertino widgets
      return await GlobalCupertinoLocalizations.delegate.load(
        const Locale('en'),
      );
    }

    return await GlobalCupertinoLocalizations.delegate.load(locale);
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}
