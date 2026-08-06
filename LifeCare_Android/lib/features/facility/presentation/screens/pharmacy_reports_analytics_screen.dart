import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pharmacy Reports & Analytics Screen
///
/// Displays comprehensive statistics and reports for the pharmacy department:
/// - Total medications in inventory
/// - Low stock items requiring reorder
/// - Prescriptions filled today
/// - Pending prescriptions awaiting dispensing
class PharmacyReportsAnalyticsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const PharmacyReportsAnalyticsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<PharmacyReportsAnalyticsScreen> createState() =>
      _PharmacyReportsAnalyticsScreenState();
}

class _PharmacyReportsAnalyticsScreenState
    extends State<PharmacyReportsAnalyticsScreen> {
  // Statistics
  int _totalMedications = 0;
  int _lowStockItems = 0;
  int _prescriptionsFilledToday = 0;
  int _pendingPrescriptions = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfDayTimestamp = Timestamp.fromDate(startOfDay);

      // Get total medications and low stock items from pharmacy inventory
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('pharmacy_inventory')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      int totalMeds = inventorySnapshot.docs.length;
      int lowStock = 0;

      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final quantity = data['quantity'] as int? ?? 0;
        final reorderLevel = data['reorderLevel'] as int? ?? 10;

        if (quantity <= reorderLevel) {
          lowStock++;
        }
      }

      // Get prescriptions filled today from dispensing_history
      final filledTodaySnapshot = await FirebaseFirestore.instance
          .collection('dispensing_history')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('dispensedAt', isGreaterThanOrEqualTo: startOfDayTimestamp)
          .get();

      // Get pending prescriptions
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('pending_prescriptions')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _totalMedications = totalMeds;
        _lowStockItems = lowStock;
        _prescriptionsFilledToday = filledTodaySnapshot.docs.length;
        _pendingPrescriptions = pendingSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading statistics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pharmacy Reports - ${widget.facilityName}'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pharmacy Statistics',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Updated: ${DateTime.now().toString().split('.')[0]}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Column(
                  children: [
                    _buildStatCard(
                      'Total Medications',
                      _totalMedications.toString(),
                      Icons.medication,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Low Stock Items',
                      _lowStockItems.toString(),
                      Icons.warning_amber_rounded,
                      Colors.red,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Filled Today',
                      _prescriptionsFilledToday.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Pending Prescriptions',
                      _pendingPrescriptions.toString(),
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'About These Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoItem(
                        'Total Medications',
                        'Total number of different medication types currently in the pharmacy inventory.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Low Stock Items',
                        'Medications that have reached or fallen below their reorder level and need restocking.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Filled Today',
                        'Number of prescriptions that have been dispensed to patients today.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Pending Prescriptions',
                        'Prescriptions awaiting dispensing from the pharmacy staff.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ],
    );
  }
}
