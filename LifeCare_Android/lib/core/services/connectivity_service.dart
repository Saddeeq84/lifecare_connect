// Network Connectivity Service
// Monitors network status and provides real-time connectivity updates

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum ConnectionStatus { online, offline, unstable }

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  ConnectionStatus _status = ConnectionStatus.online;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _stabilityCheckTimer;
  int _connectionDrops = 0;
  DateTime? _lastStatusChange;
  bool _isInitialized = false;

  ConnectionStatus get status => _status;
  bool get isOnline => _status != ConnectionStatus.offline;
  bool get isOffline => _status == ConnectionStatus.offline;
  bool get isUnstable => _status == ConnectionStatus.unstable;

  /// Initialize connectivity monitoring (lazy - only when needed)
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent double initialization

    _isInitialized = true;

    // Check initial connectivity
    await _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // Start stability monitoring
    _startStabilityMonitoring();
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = isOnline;
    final isNowOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (wasOnline != isNowOnline) {
      _connectionDrops++;
      _lastStatusChange = DateTime.now();
    }

    _updateStatus(isNowOnline);
  }

  /// Check current connectivity
  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final isConnected =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _updateStatus(isConnected);
  }

  /// Update connection status
  void _updateStatus(bool isConnected) {
    final newStatus = isConnected
        ? (_connectionDrops > 2
              ? ConnectionStatus.unstable
              : ConnectionStatus.online)
        : ConnectionStatus.offline;

    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();

      if (kDebugMode) {
        print('📡 Connection Status: $_status');
      }
    }
  }

  /// Monitor connection stability
  void _startStabilityMonitoring() {
    _stabilityCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      // Reset connection drops counter if stable for 5 minutes
      if (_lastStatusChange != null) {
        final timeSinceLastChange = DateTime.now().difference(
          _lastStatusChange!,
        );
        if (timeSinceLastChange.inMinutes >= 5 && _connectionDrops > 0) {
          _connectionDrops = 0;
          if (_status == ConnectionStatus.unstable) {
            _status = ConnectionStatus.online;
            notifyListeners();
          }
        }
      }
    });
  }

  /// Get connection type details
  Future<String> getConnectionType() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return 'Offline';
    }

    if (results.contains(ConnectivityResult.wifi)) {
      return 'WiFi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      return 'Mobile Data';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    }

    return 'Connected';
  }

  /// Force refresh connectivity status
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _stabilityCheckTimer?.cancel();
    super.dispose();
  }
}
