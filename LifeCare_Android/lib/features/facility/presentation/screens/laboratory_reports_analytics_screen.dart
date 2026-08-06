import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Laboratory Reports & Analytics Screen
///
/// Displays comprehensive statistics and reports for the laboratory department:
/// - Total test requests received
/// - Pending tests awaiting sample collection
/// - Tests in progress (samples collected and being processed)
/// - Completed test results today
class LaboratoryReportsAnalyticsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const LaboratoryReportsAnalyticsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<LaboratoryReportsAnalyticsScreen> createState() =>
      _LaboratoryReportsAnalyticsScreenState();
}

class _LaboratoryReportsAnalyticsScreenState
    extends State<LaboratoryReportsAnalyticsScreen> {
  // Statistics
  int _totalTestRequests = 0;
  int _pendingTests = 0;
  int _testsInProgress = 0;
  int _completedToday = 0;
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

      // Get pending lab tests
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'pending')
          .get();

      // Get tests in progress (samples collected, being processed)
      final inProgressSnapshot = await FirebaseFirestore.instance
          .collection('lab_samples')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', whereIn: ['collected', 'processing'])
          .get();

      // Get completed results today
      final completedTodaySnapshot = await FirebaseFirestore.instance
          .collection('health_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('recordType', isEqualTo: 'laboratory')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDayTimestamp)
          .get();

      // Calculate total test requests (all-time)
      final allTestsSnapshot = await FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      setState(() {
        _totalTestRequests = allTestsSnapshot.docs.length;
        _pendingTests = pendingSnapshot.docs.length;
        _testsInProgress = inProgressSnapshot.docs.length;
        _completedToday = completedTodaySnapshot.docs.length;
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
        title: Text('Laboratory Reports - ${widget.facilityName}'),
        backgroundColor: Colors.purple.shade700,
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
                'Laboratory Statistics',
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
                      'Total Test Requests',
                      _totalTestRequests.toString(),
                      Icons.assignment,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Pending Tests',
                      _pendingTests.toString(),
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Tests In Progress',
                      _testsInProgress.toString(),
                      Icons.science,
                      Colors.purple,
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      'Completed Today',
                      _completedToday.toString(),
                      Icons.check_circle,
                      Colors.green,
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
                        'Total Test Requests',
                        'Total number of laboratory test requests received by the facility (all-time).',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Pending Tests',
                        'Tests that have been requested but samples have not yet been collected.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Tests In Progress',
                        'Tests where samples have been collected and are currently being processed/analyzed.',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        'Completed Today',
                        'Number of test results that were completed and recorded today.',
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
