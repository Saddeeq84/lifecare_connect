import 'package:flutter/material.dart';

class AppLanguage {
  final String code;
  final String name;

  const AppLanguage(this.code, this.name);
}

class SettingsProvider with ChangeNotifier {
  static const supportedLanguages = [
    AppLanguage('en', 'English'),
    AppLanguage('ha', 'Hausa'),
    AppLanguage('ig', 'Igbo'),
    AppLanguage('yo', 'Yoruba'),
  ];

  String _languageCode = 'en';

  String get languageCode => _languageCode;

  AppLanguage get language => supportedLanguages.firstWhere(
        (item) => item.code == _languageCode,
        orElse: () => supportedLanguages.first,
      );

  void setLanguage(String code) {
    if (_languageCode == code) return;
    if (!supportedLanguages.any((item) => item.code == code)) return;
    _languageCode = code;
    notifyListeners();
  }
}
