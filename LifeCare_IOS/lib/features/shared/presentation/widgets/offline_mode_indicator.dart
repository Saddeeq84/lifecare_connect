// Offline Mode Indicator Widget
// Shows connection status and pending sync operations

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/batch_sync_manager.dart';

class OfflineModeIndicator extends StatefulWidget {
  const OfflineModeIndicator({super.key});

  @override
  State<OfflineModeIndicator> createState() => _OfflineModeIndicatorState();
}

class _OfflineModeIndicatorState extends State<OfflineModeIndicator> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);
    });
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      setState(() {
        _isOnline =
            results.isNotEmpty && !results.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BatchSyncManager>(
      builder: (context, syncManager, child) {
        if (_isOnline && syncManager.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _isOnline ? Colors.blue.shade50 : Colors.orange.shade50,
          child: Row(
            children: [
              Icon(
                _isOnline ? Icons.sync : Icons.wifi_off,
                size: 20,
                color: _isOnline
                    ? Colors.blue.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline
                          ? (syncManager.isSyncing
                                ? 'Syncing data...'
                                : '${syncManager.pendingCount} items pending sync')
                          : 'Offline Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isOnline
                            ? Colors.blue.shade900
                            : Colors.orange.shade900,
                        fontSize: 14,
                      ),
                    ),
                    if (!_isOnline)
                      Text(
                        'Your changes will sync when you reconnect',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    if (_isOnline && syncManager.isSyncing)
                      LinearProgressIndicator(
                        backgroundColor: Colors.blue.shade100,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.blue.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              if (_isOnline &&
                  syncManager.pendingCount > 0 &&
                  !syncManager.isSyncing)
                TextButton(
                  onPressed: () => syncManager.triggerManualSync(),
                  child: const Text('Sync Now'),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Offline Features List Widget
/// Shows which features are available offline
class OfflineFeaturesList extends StatelessWidget {
  const OfflineFeaturesList({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Offline Features'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Available Offline:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              Icons.login,
              'Login with cached credentials',
              true,
            ),
            _buildFeatureItem(Icons.calendar_today, 'Book appointments', true),
            _buildFeatureItem(Icons.people, 'View patient list', true),
            _buildFeatureItem(
              Icons.medical_information,
              'View medical records',
              true,
            ),
            _buildFeatureItem(Icons.person_add, 'Register new patients', true),
            _buildFeatureItem(Icons.settings, 'Update preferences', true),
            _buildFeatureItem(Icons.book, 'Access training materials', true),

            const SizedBox(height: 16),
            const Text(
              'Requires Internet:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.video_call, 'Video consultations', false),
            _buildFeatureItem(Icons.payment, 'Payment processing', false),
            _buildFeatureItem(Icons.cloud_upload, 'File uploads', false),
            _buildFeatureItem(Icons.chat, 'Real-time messaging', false),
            _buildFeatureItem(Icons.notifications, 'Push notifications', false),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All offline actions will automatically sync when you reconnect to the internet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool available) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: available ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: available ? Colors.black87 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
