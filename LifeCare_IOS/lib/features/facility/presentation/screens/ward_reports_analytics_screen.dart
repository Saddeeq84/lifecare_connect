import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_daily_report_screen.dart';

/// Ward Reports & Analytics Screen
/// Shows statistics for ward management
class WardReportsAnalyticsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String? wardId;
  final String staffId;
  final String staffName;

  const WardReportsAnalyticsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.wardId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<WardReportsAnalyticsScreen> createState() =>
      _WardReportsAnalyticsScreenState();
}

class _WardReportsAnalyticsScreenState
    extends State<WardReportsAnalyticsScreen> {
  int _totalInPatients = 0;
  int _admittedToday = 0;
  int _dischargedToday = 0;
  int _criticalPatients = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _loadingStats = true);

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final startOfDayTimestamp = Timestamp.fromDate(startOfDay);
      final endOfDayTimestamp = Timestamp.fromDate(endOfDay);

      // Build base query for currently admitted patients
      Query inPatientsQuery = FirebaseFirestore.instance
          .collection('inpatients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'admitted');

      // If wardId is specified, filter by that ward
      if (widget.wardId != null) {
        inPatientsQuery = inPatientsQuery.where(
          'wardId',
          isEqualTo: widget.wardId,
        );
      }

      final inPatientsSnapshot = await inPatientsQuery.get();

      // Filter out any records that might have isActive: false (discharged but status not updated)
      final activeInPatients = inPatientsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final isActive = data['isActive'];
        // If isActive field doesn't exist, treat as active (for backward compatibility)
        return isActive == null || isActive == true;
      }).toList();

      final totalInPatients = activeInPatients.length;

      // Count admissions today - check admittedAt timestamp
      final admittedTodayCount = activeInPatients.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final admittedAt = (data['admittedAt'] as Timestamp?)?.toDate();
        return admittedAt != null &&
            admittedAt.isAfter(startOfDay) &&
            admittedAt.isBefore(endOfDay);
      }).length;

      // Count discharges today - query discharged patients
      Query dischargesQuery = FirebaseFirestore.instance
          .collection('inpatients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'discharged')
          .where('dischargeDate', isGreaterThanOrEqualTo: startOfDayTimestamp)
          .where('dischargeDate', isLessThan: endOfDayTimestamp);

      if (widget.wardId != null) {
        dischargesQuery = dischargesQuery.where(
          'wardId',
          isEqualTo: widget.wardId,
        );
      }

      final dischargesSnapshot = await dischargesQuery.get();
      final dischargedTodayCount = dischargesSnapshot.docs.length;

      // Count critical patients (only among currently admitted)
      final criticalCount = activeInPatients.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final condition = (data['condition'] ?? '').toString().toLowerCase();
        return condition == 'critical' || condition == 'severe';
      }).length;

      if (mounted) {
        setState(() {
          _totalInPatients = totalInPatients;
          _admittedToday = admittedTodayCount;
          _dischargedToday = dischargedTodayCount;
          _criticalPatients = criticalCount;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
      print('Error loading ward statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.wardId != null
              ? 'Ward Reports - ${widget.facilityName}'
              : 'Ward Reports - ${widget.facilityName}',
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.analytics, size: 40, color: Colors.white),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ward Reports & Analytics',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.wardId != null
                                ? 'Statistics for your assigned ward'
                                : 'Statistics across all wards',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Report Actions
              Text(
                'Report Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 2,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Patient Daily Reports',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Text(
                    '24-hour nursing reports for admitted patients',
                    style: TextStyle(fontSize: 13),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientDailyReportScreen(
                          facilityId: widget.facilityId,
                          facilityName: widget.facilityName,
                          staffId: widget.staffId,
                          staffName: widget.staffName,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Statistics Section
              Text(
                'Ward Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              if (_loadingStats)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildStatisticsGrid(),

              const SizedBox(height: 24),

              // Additional Information
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'About Ward Statistics',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Total In-Patients: Current admitted patients in the ward\n'
                        '• Admitted Today: New admissions in the last 24 hours\n'
                        '• Discharged Today: Patients discharged in the last 24 hours\n'
                        '• Critical Patients: Patients with critical or severe conditions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
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

  Widget _buildStatisticsGrid() {
    final stats = [
      {
        'title': 'Total In-Patients',
        'value': _totalInPatients.toString(),
        'icon': Icons.hotel,
        'color': Colors.blue,
      },
      {
        'title': 'Admitted Today',
        'value': _admittedToday.toString(),
        'icon': Icons.login,
        'color': Colors.green,
      },
      {
        'title': 'Discharged Today',
        'value': _dischargedToday.toString(),
        'icon': Icons.logout,
        'color': Colors.orange,
      },
      {
        'title': 'Critical Patients',
        'value': _criticalPatients.toString(),
        'icon': Icons.warning,
        'color': Colors.red,
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildStatCard(
            stat['title'] as String,
            stat['value'] as String,
            stat['icon'] as IconData,
            stat['color'] as Color,
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }
}
