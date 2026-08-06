import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  // Supported languages
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'ha', 'name': 'Hausa', 'nativeName': 'Hausa'},
    {'code': 'sw', 'name': 'Swahili', 'nativeName': 'Kiswahili'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español'},
    {'code': 'ig', 'name': 'Igbo', 'nativeName': 'Igbo'},
    {'code': 'yo', 'name': 'Yoruba', 'nativeName': 'Yorùbá'},
  ];

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale)) return;

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }

  bool _isSupported(Locale locale) {
    return supportedLanguages.any(
      (lang) => lang['code'] == locale.languageCode,
    );
  }

  String getLanguageName(String code) {
    final lang = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'name': 'English'},
    );
    return lang['name'] ?? 'English';
  }

  String getLanguageNativeName(String code) {
    final lang = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'nativeName': 'English'},
    );
    return lang['nativeName'] ?? 'English';
  }
}
