// Offline Indicator Widget
// Shows a banner when the app is offline or connection is unstable

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';

class OfflineIndicator extends StatelessWidget {
  final Widget child;

  const OfflineIndicator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Lazy initialization of connectivity service
    final connectivity = ConnectivityService();
    connectivity.initialize(); // Safe to call multiple times

    return ChangeNotifierProvider.value(
      value: connectivity,
      child: Consumer<ConnectivityService>(
        builder: (context, connectivity, _) {
          return Column(
            children: [
              if (connectivity.isOffline || connectivity.isUnstable)
                _ConnectionBanner(status: connectivity.status),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;

  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOffline = status == ConnectionStatus.offline;
    final pendingCount = OfflineQueueService().getPendingCount();

    return Material(
      color: isOffline ? Colors.red.shade700 : Colors.orange.shade700,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.signal_cellular_alt,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOffline ? 'You are offline' : 'Unstable connection',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (isOffline && pendingCount > 0)
                      Text(
                        '$pendingCount action(s) will sync when online',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      )
                    else if (isOffline)
                      const Text(
                        'You can view cached data',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      )
                    else
                      const Text(
                        'Some features may be slow',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                  ],
                ),
              ),
              if (isOffline)
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating offline indicator (for use in specific screens)
class FloatingOfflineIndicator extends StatelessWidget {
  const FloatingOfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        if (connectivity.isOnline && !connectivity.isUnstable) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: connectivity.isOffline
                ? Colors.red.shade700
                : Colors.orange.shade700,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    connectivity.isOffline
                        ? Icons.cloud_off
                        : Icons.signal_cellular_alt,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connectivity.isOffline
                        ? 'Offline Mode'
                        : 'Unstable Connection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
