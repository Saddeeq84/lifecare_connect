// Local Cache Service
// Caches critical data locally for offline access

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  static const String _prefix = 'cache_';
  static const Duration _defaultExpiry = Duration(days: 7);

  /// Cache data with optional expiry
  Future<void> set({
    required String key,
    required dynamic data,
    Duration? expiry,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'expiry': (expiry ?? _defaultExpiry).inMilliseconds,
      };
      await prefs.setString('$_prefix$key', json.encode(cacheData));
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Get cached data
  Future<dynamic> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString('$_prefix$key');

      if (cacheString == null) return null;

      final cacheData = json.decode(cacheString);
      final timestamp = DateTime.parse(cacheData['timestamp']);
      final expiry = Duration(milliseconds: cacheData['expiry']);

      // Check if expired
      if (DateTime.now().difference(timestamp) > expiry) {
        await remove(key);
        return null;
      }

      return cacheData['data'];
    } catch (e) {
      return null;
    }
  }

  /// Remove cached item
  Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (e) {
      // Ignore
    }
  }

  /// Clear all cache
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Ignore
    }
  }

  /// Cache user profile
  Future<void> cacheUserProfile(
    String userId,
    Map<String, dynamic> profile,
  ) async {
    await set(
      key: 'user_profile_$userId',
      data: profile,
      expiry: const Duration(hours: 24),
    );
  }

  /// Get cached user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final data = await get('user_profile_$userId');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Cache patient list
  Future<void> cachePatientList(
    String userId,
    List<Map<String, dynamic>> patients,
  ) async {
    await set(
      key: 'patients_$userId',
      data: patients,
      expiry: const Duration(hours: 6),
    );
  }

  /// Get cached patient list
  Future<List<Map<String, dynamic>>?> getPatientList(String userId) async {
    final data = await get('patients_$userId');
    if (data != null && data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// Cache appointments
  Future<void> cacheAppointments(
    String userId,
    List<Map<String, dynamic>> appointments,
  ) async {
    await set(
      key: 'appointments_$userId',
      data: appointments,
      expiry: const Duration(hours: 2),
    );
  }

  /// Get cached appointments
  Future<List<Map<String, dynamic>>?> getAppointments(String userId) async {
    final data = await get('appointments_$userId');
    if (data != null && data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// Cache medical records
  Future<void> cacheMedicalRecord(
    String recordId,
    Map<String, dynamic> record,
  ) async {
    await set(
      key: 'medical_record_$recordId',
      data: record,
      expiry: const Duration(days: 1),
    );
  }

  /// Get cached medical record
  Future<Map<String, dynamic>?> getMedicalRecord(String recordId) async {
    final data = await get('medical_record_$recordId');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Cache vital signs
  Future<void> cacheVitalSigns(
    String patientId,
    List<Map<String, dynamic>> vitals,
  ) async {
    await set(
      key: 'vitals_$patientId',
      data: vitals,
      expiry: const Duration(hours: 12),
    );
  }

  /// Get cached vital signs
  Future<List<Map<String, dynamic>>?> getVitalSigns(String patientId) async {
    final data = await get('vitals_$patientId');
    if (data != null && data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// Cache medications
  Future<void> cacheMedications(
    String patientId,
    List<Map<String, dynamic>> medications,
  ) async {
    await set(
      key: 'medications_$patientId',
      data: medications,
      expiry: const Duration(hours: 12),
    );
  }

  /// Get cached medications
  Future<List<Map<String, dynamic>>?> getMedications(String patientId) async {
    final data = await get('medications_$patientId');
    if (data != null && data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// Cache lookup data (diagnoses, medications, procedures)
  Future<void> cacheLookupData(
    String type,
    List<Map<String, dynamic>> data,
  ) async {
    await set(
      key: 'lookup_$type',
      data: data,
      expiry: const Duration(
        days: 30,
      ), // Long expiry for relatively static data
    );
  }

  /// Get cached lookup data
  Future<List<Map<String, dynamic>>?> getLookupData(String type) async {
    final data = await get('lookup_$type');
    if (data != null && data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// Cache dashboard stats
  Future<void> cacheDashboardStats(
    String userId,
    Map<String, dynamic> stats,
  ) async {
    await set(
      key: 'dashboard_stats_$userId',
      data: stats,
      expiry: const Duration(hours: 1),
    );
  }

  /// Get cached dashboard stats
  Future<Map<String, dynamic>?> getDashboardStats(String userId) async {
    final data = await get('dashboard_stats_$userId');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  /// Get cache size info
  Future<Map<String, int>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys = prefs.getKeys().where((k) => k.startsWith(_prefix));

      int totalItems = cacheKeys.length;
      int totalSize = 0;

      for (final key in cacheKeys) {
        final value = prefs.getString(key);
        if (value != null) {
          totalSize += value.length;
        }
      }

      return {'items': totalItems, 'sizeBytes': totalSize};
    } catch (e) {
      return {'items': 0, 'sizeBytes': 0};
    }
  }
}
