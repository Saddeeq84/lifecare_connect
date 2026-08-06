import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalRecordsReportsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffName;

  const MedicalRecordsReportsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffName,
  });

  @override
  State<MedicalRecordsReportsScreen> createState() =>
      _MedicalRecordsReportsScreenState();
}

class _MedicalRecordsReportsScreenState
    extends State<MedicalRecordsReportsScreen> {
  bool _loading = true;
  int _totalRecords = 0;
  int _newRecordsToday = 0;
  int _pendingApprovals = 0;
  int _totalPatients = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      // Get all records for this facility (fetch once and filter in memory)
      final recordsSnapshot = await FirebaseFirestore.instance
          .collection('health_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      final allRecords = recordsSnapshot.docs;
      _totalRecords = allRecords.length;

      // Filter new records today in memory to avoid composite index
      _newRecordsToday = allRecords.where((doc) {
        final data = doc.data();
        final createdAt = data['created_at'];
        if (createdAt is Timestamp) {
          return createdAt.toDate().isAfter(startOfToday) ||
              createdAt.toDate().isAtSameMomentAs(startOfToday);
        }
        return false;
      }).length;

      // Filter pending approvals in memory to avoid composite index
      _pendingApprovals = allRecords.where((doc) {
        final data = doc.data();
        return data['status'] == 'pending';
      }).length;

      // Get total patients
      final patientsSnapshot = await FirebaseFirestore.instance
          .collection('facility_patients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();
      _totalPatients = patientsSnapshot.docs.length;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading statistics: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildDetailedStats(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assessment, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medical Records Reports',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.facilityName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple.shade100,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated: ${DateTime.now().toString().substring(0, 19)}',
            style: TextStyle(fontSize: 12, color: Colors.purple.shade100),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview Statistics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          'Total Health Records',
          _totalRecords.toString(),
          Icons.folder,
          Colors.blue,
          'Total number of patient health records in the system',
        ),
        const SizedBox(height: 12),
        _buildDetailCard(
          'New Records Today',
          _newRecordsToday.toString(),
          Icons.fiber_new,
          Colors.green,
          'Health records created today (${DateTime.now().toString().substring(0, 10)})',
        ),
        const SizedBox(height: 12),
        _buildDetailCard(
          'Total Patients',
          _totalPatients.toString(),
          Icons.people,
          Colors.purple,
          'Total number of registered patients in the facility',
        ),
        const SizedBox(height: 12),
        _buildDetailCard(
          'Pending Approvals',
          _pendingApprovals.toString(),
          Icons.pending,
          Colors.orange,
          'Health records awaiting approval or review',
        ),
        const SizedBox(height: 24),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildDetailCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pull down to refresh statistics. Data is updated in real-time from the database.',
                style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
