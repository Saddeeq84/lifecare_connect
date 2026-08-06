// Offline Support Mixin
// Provides offline functionality helpers for screens and widgets

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/local_cache_service.dart';

mixin OfflineSupport<T extends StatefulWidget> on State<T> {
  final ConnectivityService _connectivity = ConnectivityService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final LocalCacheService _cache = LocalCacheService();

  /// Check if device is online
  bool get isOnline => _connectivity.isOnline;

  /// Check if device is offline
  bool get isOffline => _connectivity.isOffline;

  /// Check if connection is unstable
  bool get isUnstable => _connectivity.isUnstable;

  /// Show offline message to user
  void showOfflineMessage(BuildContext context, {String? customMessage}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customMessage ??
                    'You are offline. This action will be queued and synced when online.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  /// Show success message after operation is queued
  void showQueuedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Action queued. Will sync when connection is restored.',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Queue a Firestore write operation
  Future<void> queueFirestoreWrite({
    required OperationType type,
    required String collection,
    required Map<String, dynamic> data,
    String? docId,
  }) async {
    await _offlineQueue.queueOperation(
      type: type,
      data: {'collection': collection, 'fields': data, 'docId': ?docId},
    );
  }

  /// Fetch data with offline fallback
  Future<List<Map<String, dynamic>>> fetchWithCache<T>({
    required Query<Map<String, dynamic>> query,
    required String cacheKey,
    required Future<void> Function(List<Map<String, dynamic>>) onCache,
  }) async {
    try {
      final snapshot = await query.get();
      final data = snapshot.docs.map((doc) => doc.data()).toList();

      // Cache the data
      await onCache(data);

      return data;
    } catch (e) {
      // If offline, try to get from cache
      final cached = await _cache.get(cacheKey);
      if (cached != null && cached is List) {
        return cached.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      rethrow;
    }
  }

  /// Safe Firestore operation with offline handling
  Future<T?> safeFirestoreOperation<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? offlineMessage,
    bool showQueuedSnackbar = true,
  }) async {
    try {
      return await operation();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || isOffline) {
        if (context.mounted) {
          showOfflineMessage(context, customMessage: offlineMessage);
          if (showQueuedSnackbar) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) showQueuedMessage(context);
            });
          }
        }
      } else {
        rethrow;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending operations count
  int get pendingOperationsCount => _offlineQueue.getPendingCount();

  /// Check if has pending operations
  bool get hasPendingOperations => _offlineQueue.hasPendingOperations();

  /// Get connection status text
  String get connectionStatusText {
    if (isOffline) return 'Offline';
    if (isUnstable) return 'Unstable Connection';
    return 'Online';
  }

  /// Get connection status color
  Color get connectionStatusColor {
    if (isOffline) return Colors.red;
    if (isUnstable) return Colors.orange;
    return Colors.green;
  }
}

/// Extension on BuildContext for offline awareness
extension OfflineContext on BuildContext {
  /// Show a dialog informing user about offline mode
  Future<bool?> showOfflineDialog({String? title, String? message}) {
    return showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title ?? 'Offline Mode'),
          ],
        ),
        content: Text(
          message ??
              'You are currently offline. This action will be saved and synced automatically when your connection is restored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue Offline'),
          ),
        ],
      ),
    );
  }
}
