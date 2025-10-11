// ignore_for_file: use_build_context_synchronously, prefer_final_fields, avoid_print

import 'package:flutter/material.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart'; // Unused import // Unused import
// // import 'package:firebase_auth/firebase_auth.dart'; // Unused import // Unused import
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/services/health_data_service.dart';

class HealthStatusIndicator extends StatefulWidget {
  const HealthStatusIndicator({super.key});

  @override
  State<HealthStatusIndicator> createState() => _HealthStatusIndicatorState();
}

class _HealthStatusIndicatorState extends State<HealthStatusIndicator> {
  bool _isOnline = true;
  bool _hasPendingSync = false;
  Map<String, dynamic>? _healthSummary;

  @override
  void initState() {
    super.initState();
    _initializeStatus();
  }

  Future<void> _initializeStatus() async {
    // Monitor connectivity
    HealthDataService.getConnectivityStream().listen((connectivityResults) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResults.any(
            (result) => result != ConnectivityResult.none,
          );
        });
      }
    });

    // Load health summary
    try {
      final summary = await HealthDataService.getHealthSummary();
      if (mounted) {
        setState(() {
          _healthSummary = summary;
        });
      }
    } catch (e) {
      print('Error loading health summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isOnline
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: _isOnline ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isOnline ? 'Synced' : 'Offline Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isOnline ? Colors.green : Colors.orange,
                ),
              ),
              const Spacer(),
              if (_hasPendingSync)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Syncing...',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
            ],
          ),
          if (_healthSummary != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSummaryItem(
                  'Records',
                  _healthSummary!['totalRecords']?.toString() ?? '0',
                  Icons.medical_information,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildSummaryItem(
                  'Lab Results',
                  _healthSummary!['labResults']?.toString() ?? '0',
                  Icons.science,
                  Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildSummaryItem(
                  'Consultations',
                  _healthSummary!['completedConsultations']?.toString() ?? '0',
                  Icons.video_call,
                  Colors.green,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String count,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          count,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}
