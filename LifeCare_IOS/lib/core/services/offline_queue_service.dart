// Offline Operations Queue Service
// Queues critical operations when offline and retries them when connection returns

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OperationType {
  appointment,
  payment,
  consultation,
  medicalRecord,
  emergency,
  other,
}

class QueuedOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retryCount;
  DateTime? lastRetry;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.lastRetry,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'lastRetry': lastRetry?.toIso8601String(),
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'],
      type: OperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => OperationType.other,
      ),
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
      lastRetry: json['lastRetry'] != null
          ? DateTime.parse(json['lastRetry'])
          : null,
    );
  }
}

class OfflineQueueService {
  static const String _queueKey = 'offline_operations_queue';
  static const int _maxRetries = 5;
  static const Duration _retryBaseDelay = Duration(seconds: 5);

  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final List<QueuedOperation> _queue = [];
  bool _isProcessing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initialize the service and start monitoring connectivity
  Future<void> initialize() async {
    await _loadQueue();
    _startConnectivityMonitoring();
  }

  /// Add an operation to the queue
  Future<void> queueOperation({
    required OperationType type,
    required Map<String, dynamic> data,
  }) async {
    final operation = QueuedOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );

    _queue.add(operation);
    await _saveQueue();

    // Try to process immediately if online
    await _processQueue();
  }

  /// Get pending operations count
  int getPendingCount() => _queue.length;

  /// Get pending operations by type
  List<QueuedOperation> getPendingByType(OperationType type) {
    return _queue.where((op) => op.type == type).toList();
  }

  /// Check if there are pending operations
  bool hasPendingOperations() => _queue.isNotEmpty;

  /// Start monitoring connectivity
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isOnline =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);

      if (isOnline && _queue.isNotEmpty) {
        _processQueue();
      }
    });
  }

  /// Process the queue
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline =
        connectivityResult.isNotEmpty &&
        !connectivityResult.contains(ConnectivityResult.none);

    if (!isOnline) {
      return;
    }

    _isProcessing = true;

    try {
      final operationsToRemove = <QueuedOperation>[];

      for (final operation in List.from(_queue)) {
        try {
          // Check if operation should be retried (exponential backoff)
          if (operation.lastRetry != null) {
            final delay = _retryBaseDelay * (1 << operation.retryCount);
            final nextRetry = operation.lastRetry!.add(delay);
            if (DateTime.now().isBefore(nextRetry)) {
              continue; // Skip this operation for now
            }
          }

          // Process the operation
          final success = await _processOperation(operation);

          if (success) {
            operationsToRemove.add(operation);
          } else {
            operation.retryCount++;
            operation.lastRetry = DateTime.now();

            if (operation.retryCount >= _maxRetries) {
              operationsToRemove.add(operation);
            }
          }
        } catch (e) {
          operation.retryCount++;
          operation.lastRetry = DateTime.now();
        }
      }

      // Remove successfully processed or max-retried operations
      for (final op in operationsToRemove) {
        _queue.remove(op);
      }

      await _saveQueue();
    } finally {
      _isProcessing = false;
    }
  }

  /// Process a single operation
  Future<bool> _processOperation(QueuedOperation operation) async {
    try {
      switch (operation.type) {
        case OperationType.appointment:
          return await _processAppointment(operation.data);
        case OperationType.payment:
          return await _processPayment(operation.data);
        case OperationType.consultation:
          return await _processConsultation(operation.data);
        case OperationType.medicalRecord:
          return await _processMedicalRecord(operation.data);
        case OperationType.emergency:
          return await _processEmergency(operation.data);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Process appointment operation
  Future<bool> _processAppointment(Map<String, dynamic> data) async {
    try {
      final collection = data['collection'] ?? 'appointments';
      final docId = data['docId'];

      if (docId != null) {
        await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .update(data['fields']);
      } else {
        await FirebaseFirestore.instance
            .collection(collection)
            .add(data['fields']);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Process payment operation
  Future<bool> _processPayment(Map<String, dynamic> data) async {
    try {
      final collection = data['collection'] ?? 'escrow_payments';
      await FirebaseFirestore.instance
          .collection(collection)
          .add(data['fields']);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Process consultation operation
  Future<bool> _processConsultation(Map<String, dynamic> data) async {
    try {
      final docId = data['docId'];
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(docId)
            .update(data['fields']);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Process medical record operation
  Future<bool> _processMedicalRecord(Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('medical_records')
          .add(data['fields']);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Process emergency operation
  Future<bool> _processEmergency(Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergency_requests')
          .add(data['fields']);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Load queue from local storage
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson != null) {
        final List<dynamic> queueList = json.decode(queueJson);
        _queue.clear();
        _queue.addAll(
          queueList.map((item) => QueuedOperation.fromJson(item)).toList(),
        );
      }
    } catch (e) {
      // Ignore errors during load
    }
  }

  /// Save queue to local storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = json.encode(_queue.map((op) => op.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      // Ignore errors during save
    }
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
