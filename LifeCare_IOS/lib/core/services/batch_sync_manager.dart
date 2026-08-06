// Batch Sync Manager
// Efficiently syncs offline data when connectivity is restored

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'offline_database_service.dart';
import 'offline_auth_service.dart';

class BatchSyncManager extends ChangeNotifier {
  static final BatchSyncManager _instance = BatchSyncManager._internal();
  factory BatchSyncManager() => _instance;
  BatchSyncManager._internal();

  final OfflineDatabaseService _db = OfflineDatabaseService();
  final OfflineAuthService _auth = OfflineAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  int _pendingCount = 0;
  int _syncedCount = 0;
  int _failedCount = 0;
  String _syncStatus = 'idle';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  int get syncedCount => _syncedCount;
  int get failedCount => _failedCount;
  String get syncStatus => _syncStatus;

  /// Initialize sync manager and monitor connectivity
  Future<void> initialize() async {
    await _updatePendingCount();
    _startConnectivityMonitoring();
  }

  /// Start monitoring connectivity for auto-sync
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final isOnline =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);

      if (isOnline && _pendingCount > 0 && !_isSyncing) {
        await syncAll();
      }
    });
  }

  /// Update pending count
  Future<void> _updatePendingCount() async {
    _pendingCount = await _db.getPendingSyncCount();
    notifyListeners();
  }

  /// Sync all pending operations
  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncedCount = 0;
    _failedCount = 0;
    _syncStatus = 'syncing';
    notifyListeners();

    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (!isOnline) {
        _syncStatus = 'offline';
        _isSyncing = false;
        notifyListeners();
        return;
      }

      // Sync pending registrations first
      await _auth.syncPendingRegistrations();

      // Get all pending sync operations
      final pendingOps = await _db.getPendingSyncOperations();

      for (final op in pendingOps) {
        try {
          await _processSyncOperation(op);
          await _db.markSyncComplete(op['id']);
          _syncedCount++;
        } catch (e) {
          await _db.incrementSyncRetry(op['id']);
          _failedCount++;
          debugPrint('Sync operation failed: ${e.toString()}');
        }
      }

      // Update appointments sync status
      await _syncAppointments();

      // Update patients sync status
      await _syncPatients();

      _syncStatus = 'completed';
      await _updatePendingCount();
    } catch (e) {
      _syncStatus = 'error';
      debugPrint('Batch sync failed: ${e.toString()}');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Process a single sync operation
  Future<void> _processSyncOperation(Map<String, dynamic> op) async {
    final operationType = op['operationType'];
    final entityType = op['entityType'];
    final entityId = op['entityId'];
    final operationData = op['operationData'] as Map<String, dynamic>;

    switch (entityType) {
      case 'appointment':
        await _syncAppointmentOperation(operationType, entityId, operationData);
        break;
      case 'patient':
        await _syncPatientOperation(operationType, entityId, operationData);
        break;
      case 'medical_record':
        await _syncMedicalRecordOperation(
          operationType,
          entityId,
          operationData,
        );
        break;
      case 'user':
        await _syncUserOperation(operationType, entityId, operationData);
        break;
      default:
        throw Exception('Unknown entity type: $entityType');
    }
  }

  /// Sync appointment operation
  Future<void> _syncAppointmentOperation(
    String operationType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    switch (operationType) {
      case 'create':
        // Check if this was created offline with temporary ID
        if (entityId.startsWith('offline_')) {
          // Create new document in Firestore
          final docRef = await _firestore.collection('appointments').add(data);

          // Update local database with real ID
          data['id'] = docRef.id;
          await _db.saveAppointment(data);
        } else {
          await _firestore.collection('appointments').doc(entityId).set(data);
        }
        break;
      case 'update':
        await _firestore.collection('appointments').doc(entityId).update(data);
        break;
      case 'delete':
        await _firestore.collection('appointments').doc(entityId).delete();
        break;
    }
  }

  /// Sync patient operation
  Future<void> _syncPatientOperation(
    String operationType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    switch (operationType) {
      case 'create':
        if (entityId.startsWith('offline_')) {
          final docRef = await _firestore.collection('patients').add(data);
          data['uid'] = docRef.id;
          await _db.savePatient(data);
        } else {
          await _firestore.collection('patients').doc(entityId).set(data);
        }
        break;
      case 'update':
        await _firestore.collection('patients').doc(entityId).update(data);
        break;
      case 'delete':
        await _firestore.collection('patients').doc(entityId).delete();
        break;
    }
  }

  /// Sync medical record operation
  Future<void> _syncMedicalRecordOperation(
    String operationType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    switch (operationType) {
      case 'create':
        if (entityId.startsWith('offline_')) {
          await _firestore.collection('medical_records').add(data);
        } else {
          await _firestore
              .collection('medical_records')
              .doc(entityId)
              .set(data);
        }
        break;
      case 'update':
        await _firestore
            .collection('medical_records')
            .doc(entityId)
            .update(data);
        break;
    }
  }

  /// Sync user operation
  Future<void> _syncUserOperation(
    String operationType,
    String entityId,
    Map<String, dynamic> data,
  ) async {
    if (entityId.startsWith('offline_')) {
      // Skip - user registration is handled separately
      return;
    }

    switch (operationType) {
      case 'update':
        await _firestore.collection('users').doc(entityId).update(data);
        break;
    }
  }

  /// Sync all appointments with pending status
  Future<void> _syncAppointments() async {
    final appointments = await _db.getAppointments();

    for (final appointment in appointments) {
      if (appointment['syncStatus'] == 'pending') {
        try {
          final id = appointment['id'];

          if (id.startsWith('offline_')) {
            // Create new appointment in Firestore
            final docRef = await _firestore
                .collection('appointments')
                .add(appointment);
            appointment['id'] = docRef.id;
            appointment['syncStatus'] = 'synced';
            await _db.saveAppointment(appointment);
          } else {
            // Update existing appointment
            await _firestore
                .collection('appointments')
                .doc(id)
                .set(appointment, SetOptions(merge: true));

            appointment['syncStatus'] = 'synced';
            await _db.saveAppointment(appointment);
          }
        } catch (e) {
          debugPrint('Failed to sync appointment: ${e.toString()}');
        }
      }
    }
  }

  /// Sync all patients with pending status
  Future<void> _syncPatients() async {
    final patients = await _db.getPatients();

    for (final patient in patients) {
      if (patient['syncStatus'] == 'pending') {
        try {
          final uid = patient['uid'];

          if (uid.startsWith('offline_')) {
            // Create new patient in Firestore
            final docRef = await _firestore.collection('patients').add(patient);
            patient['uid'] = docRef.id;
            patient['syncStatus'] = 'synced';
            await _db.savePatient(patient);
          } else {
            // Update existing patient
            await _firestore
                .collection('patients')
                .doc(uid)
                .set(patient, SetOptions(merge: true));

            patient['syncStatus'] = 'synced';
            await _db.savePatient(patient);
          }
        } catch (e) {
          debugPrint('Failed to sync patient: ${e.toString()}');
        }
      }
    }
  }

  /// Manual sync trigger
  Future<void> triggerManualSync() async {
    await syncAll();
  }

  /// Get sync summary
  Map<String, dynamic> getSyncSummary() {
    return {
      'isSyncing': _isSyncing,
      'pendingCount': _pendingCount,
      'syncedCount': _syncedCount,
      'failedCount': _failedCount,
      'status': _syncStatus,
    };
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
