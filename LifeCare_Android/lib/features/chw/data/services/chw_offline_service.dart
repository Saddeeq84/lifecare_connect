import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle offline data caching and synchronization for CHW services
class CHWOfflineService {
  static const String _keyPrefix = 'chw_offline_';
  static const String _keyPendingSync = '${_keyPrefix}pending_sync';
  static const String _keyCachedPatients = '${_keyPrefix}cached_patients';
  static const String _keyCachedServices = '${_keyPrefix}cached_services';
  static const String _keyCachedTransactions =
      '${_keyPrefix}cached_transactions';
  static const String _keyLastSyncTime = '${_keyPrefix}last_sync_time';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();

  /// Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet);
  }

  /// Cache CHW patients locally
  Future<void> cachePatients(String chwId) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final snapshot = await _firestore
          .collection('chw_patients')
          .where('registeredBy', isEqualTo: chwId)
          .get();

      final patientsData = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      await prefs.setString(_keyCachedPatients, jsonEncode(patientsData));
      await _setLastSyncTime();

      print('Cached ${patientsData.length} patients locally');
    } catch (e) {
      print('Error caching patients: $e');
      rethrow;
    }
  }

  /// Get cached patients from local storage
  Future<List<Map<String, dynamic>>> getCachedPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final patientsJson = prefs.getString(_keyCachedPatients);

    if (patientsJson == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(patientsJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading cached patients: $e');
      return [];
    }
  }

  /// Cache service prices locally
  Future<void> cacheServicePrices(String chwId) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final doc = await _firestore.collection('chw_services').doc(chwId).get();

      if (doc.exists) {
        await prefs.setString(_keyCachedServices, jsonEncode(doc.data()));
        await _setLastSyncTime();

        print('Cached service prices locally');
      }
    } catch (e) {
      print('Error caching service prices: $e');
      rethrow;
    }
  }

  /// Get cached service prices
  Future<Map<String, dynamic>?> getCachedServicePrices() async {
    final prefs = await SharedPreferences.getInstance();
    final servicesJson = prefs.getString(_keyCachedServices);

    if (servicesJson == null) {
      return null;
    }

    try {
      return jsonDecode(servicesJson) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading cached services: $e');
      return null;
    }
  }

  /// Save form data offline for later sync
  Future<void> saveFormOffline({
    required String formType,
    required String patientId,
    required Map<String, dynamic> formData,
    required String chwId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing pending items
    final pendingJson = prefs.getString(_keyPendingSync) ?? '[]';
    final List<dynamic> pendingItems = jsonDecode(pendingJson);

    // Add new item
    final newItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': formType,
      'patientId': patientId,
      'chwId': chwId,
      'data': formData,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': false,
    };

    pendingItems.add(newItem);

    // Save back to storage
    await prefs.setString(_keyPendingSync, jsonEncode(pendingItems));

    print('Saved $formType form offline for patient: $patientId');
  }

  /// Get all pending sync items
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingJson = prefs.getString(_keyPendingSync) ?? '[]';

    try {
      final List<dynamic> decoded = jsonDecode(pendingJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading pending sync items: $e');
      return [];
    }
  }

  /// Sync all pending items to Firestore
  Future<SyncResult> syncPendingData() async {
    if (!await isOnline()) {
      return SyncResult(
        success: false,
        message: 'Device is offline',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    final pendingItems = await getPendingSyncItems();

    if (pendingItems.isEmpty) {
      return SyncResult(
        success: true,
        message: 'No pending data to sync',
        syncedCount: 0,
        failedCount: 0,
      );
    }

    int syncedCount = 0;
    int failedCount = 0;
    List<String> syncedIds = [];

    for (final item in pendingItems) {
      if (item['synced'] == true) {
        syncedIds.add(item['id']);
        continue;
      }

      try {
        await _syncSingleItem(item);
        syncedIds.add(item['id']);
        syncedCount++;
      } catch (e) {
        print('Error syncing item ${item['id']}: $e');
        failedCount++;
      }
    }

    // Remove synced items
    if (syncedIds.isNotEmpty) {
      await _removeSyncedItems(syncedIds);
    }

    return SyncResult(
      success: failedCount == 0,
      message: failedCount == 0
          ? 'Successfully synced $syncedCount items'
          : 'Synced $syncedCount items, $failedCount failed',
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  }

  /// Sync a single item to Firestore
  Future<void> _syncSingleItem(Map<String, dynamic> item) async {
    final type = item['type'] as String;
    final patientId = item['patientId'] as String;
    final data = item['data'] as Map<String, dynamic>;

    // Determine collection based on type
    String collection;
    switch (type) {
      case 'anc':
        collection = 'anc_visits';
        break;
      case 'pnc':
        collection = 'pnc_visits';
        break;
      case 'home_visit':
        collection = 'home_visits';
        break;
      case 'immunization':
        collection = 'immunizations';
        break;
      case 'appointment':
        collection = 'appointments';
        break;
      default:
        throw Exception('Unknown form type: $type');
    }

    // Add to Firestore
    await _firestore
        .collection('chw_patient_records')
        .doc(patientId)
        .collection(collection)
        .add(data);

    print('Synced $type for patient: $patientId');
  }

  /// Remove synced items from pending queue
  Future<void> _removeSyncedItems(List<String> syncedIds) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingItems = await getPendingSyncItems();

    // Filter out synced items
    final remaining = pendingItems
        .where((item) => !syncedIds.contains(item['id']))
        .toList();

    await prefs.setString(_keyPendingSync, jsonEncode(remaining));
  }

  /// Get count of pending sync items
  Future<int> getPendingSyncCount() async {
    final items = await getPendingSyncItems();
    return items.where((item) => item['synced'] != true).length;
  }

  /// Clear all cached data
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedPatients);
    await prefs.remove(_keyCachedServices);
    await prefs.remove(_keyCachedTransactions);
    await prefs.remove(_keyPendingSync);
    await prefs.remove(_keyLastSyncTime);

    print('Cleared all cached data');
  }

  /// Set last sync time
  Future<void> _setLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSyncTime, DateTime.now().toIso8601String());
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_keyLastSyncTime);

    if (timeStr == null) {
      return null;
    }

    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  /// Cache recent transactions
  Future<void> cacheTransactions(String chwId, {int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final snapshot = await _firestore
          .collection('chw_transactions')
          .where('chwId', isEqualTo: chwId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final transactionsData = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          // Convert Timestamp to ISO string for JSON serialization
          'timestamp': (data['timestamp'] as Timestamp?)
              ?.toDate()
              .toIso8601String(),
        };
      }).toList();

      await prefs.setString(
        _keyCachedTransactions,
        jsonEncode(transactionsData),
      );
      await _setLastSyncTime();

      print('Cached ${transactionsData.length} transactions locally');
    } catch (e) {
      print('Error caching transactions: $e');
      rethrow;
    }
  }

  /// Get cached transactions
  Future<List<Map<String, dynamic>>> getCachedTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getString(_keyCachedTransactions);

    if (transactionsJson == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(transactionsJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error reading cached transactions: $e');
      return [];
    }
  }

  /// Full sync - cache all CHW data
  Future<void> fullSync(String chwId) async {
    if (!await isOnline()) {
      throw Exception('Device is offline. Cannot perform full sync.');
    }

    await cachePatients(chwId);
    await cacheServicePrices(chwId);
    await cacheTransactions(chwId);
    await syncPendingData();

    print('Full sync completed for CHW: $chwId');
  }
}

/// Result of sync operation
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;

  SyncResult({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
  });
}
