import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LowDataModeService extends ChangeNotifier {
  static final LowDataModeService _instance = LowDataModeService._internal();
  factory LowDataModeService() => _instance;
  LowDataModeService._internal();

  static const String _key = 'low_data_mode_enabled';

  bool _enabled = true;
  bool _initialized = false;

  bool get enabled => _enabled;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    notifyListeners();
  }
}
