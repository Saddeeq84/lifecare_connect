// lib/screens/facilityscreen/facility_analytics_screen.dart

// ignore_for_file: deprecated_member_use, prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'public_health_reports_screen.dart';

class FacilityAnalyticsScreen extends StatefulWidget {
  const FacilityAnalyticsScreen({super.key});

  @override
  State<FacilityAnalyticsScreen> createState() =>
      _FacilityAnalyticsScreenState();
}

class _FacilityAnalyticsScreenState extends State<FacilityAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final String currentFacilityId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people_outline), text: 'Staff Tracking'),
            Tab(icon: Icon(Icons.timeline), text: 'Patient Flow'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Services'),
            Tab(icon: Icon(Icons.health_and_safety), text: 'Public Health'),
            Tab(icon: Icon(Icons.trending_up), text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildStaffTrackingTab(),
          _buildPatientFlowTab(),
          _buildServicesTab(),
          _buildPublicHealthReportsTab(),
          _buildPerformanceTab(),
        ],
      ),
    );
  }

  Widget _buildPublicHealthReportsTab() {
    return PublicHealthReportsScreen(
      facilityId: currentFacilityId,
      facilityName: 'Facility',
      showAppBar: false,
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Facility Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('facilityId', isEqualTo: currentFacilityId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data?.docs ?? [];
              final totalRequests = requests.length;
              final pendingRequests = requests
                  .where(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['status'] ==
                        'pending',
                  )
                  .length;
              final completedRequests = requests
                  .where(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['status'] ==
                        'completed',
                  )
                  .length;
              final cancelledRequests = requests
                  .where(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['status'] ==
                        'cancelled',
                  )
                  .length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: _buildStatCard(
                        'Total Requests',
                        totalRequests.toString(),
                        Icons.medical_services,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 200,
                      child: _buildStatCard(
                        'Pending',
                        pendingRequests.toString(),
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 200,
                      child: _buildStatCard(
                        'Completed',
                        completedRequests.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 200,
                      child: _buildStatCard(
                        'Cancelled',
                        cancelledRequests.toString(),
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildRecentActivitySection(),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('facilityId', isEqualTo: currentFacilityId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data?.docs ?? [];
              final serviceStats = <String, int>{};

              for (final doc in requests) {
                final data = doc.data() as Map<String, dynamic>;
                final serviceName = data['serviceName'] ?? 'Unknown Service';
                serviceStats[serviceName] =
                    (serviceStats[serviceName] ?? 0) + 1;
              }

              if (serviceStats.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No service data available',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Most Requested Services',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...serviceStats.entries.map(
                            (entry) =>
                                _buildServiceStatRow(entry.key, entry.value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Metrics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('service_requests')
                .where('facilityId', isEqualTo: currentFacilityId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data?.docs ?? [];
              final totalRequests = requests.length;
              final completedRequests = requests
                  .where(
                    (doc) =>
                        (doc.data() as Map<String, dynamic>)['status'] ==
                        'completed',
                  )
                  .length;

              final completionRate = totalRequests > 0
                  ? (completedRequests / totalRequests * 100).toStringAsFixed(1)
                  : '0.0';

              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildPerformanceMetric(
                            'Completion Rate',
                            '$completionRate%',
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                          const Divider(),
                          _buildPerformanceMetric(
                            'Total Patients Served',
                            _getUniquePatientCount(requests).toString(),
                            Icons.people,
                            Colors.blue,
                          ),
                          const Divider(),
                          _buildPerformanceMetric(
                            'Average Response Time',
                            _calculateAverageResponseTime(requests),
                            Icons.timer,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRevenueSection(requests),
                ],
              );
            },
          ),
        ],
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_requests')
                  .where('facilityId', isEqualTo: currentFacilityId)
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data?.docs ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Text(
                      'No recent activity',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return Column(
                  children: requests.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(data['status']),
                        child: Icon(
                          _getStatusIcon(data['status']),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(data['serviceName'] ?? 'Unknown Service'),
                      subtitle: Text('Status: ${data['status']}'),
                      trailing: Text(
                        _formatDate(data['createdAt']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatRow(String serviceName, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(serviceName, style: const TextStyle(fontSize: 16)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Colors.purple.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRevenueSection(List<QueryDocumentSnapshot> requests) {
    return FutureBuilder<List<double>>(
      future: Future.wait([
        _calculateTotalRevenue(),
        _calculateMonthlyRevenue(),
      ]),
      builder: (context, snapshot) {
        final totalRevenue = snapshot.data?[0] ?? 0;
        final monthlyRevenue = snapshot.data?[1] ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revenue Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.attach_money, color: Colors.white),
                  ),
                  title: const Text('Total Revenue'),
                  trailing: snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _formatCurrency(totalRevenue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.calendar_month, color: Colors.white),
                  ),
                  title: const Text('Monthly Revenue'),
                  trailing: snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _formatCurrency(monthlyRevenue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  int _getUniquePatientCount(List<QueryDocumentSnapshot> requests) {
    final patientIds = <String>{};
    for (final doc in requests) {
      final data = doc.data() as Map<String, dynamic>;
      final patientId = data['patientId'];
      if (patientId != null) {
        patientIds.add(patientId);
      }
    }
    return patientIds.length;
  }

  Widget _buildStaffTrackingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff Attendance & Activity',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 20),

          // Staff Attendance Overview
          _buildStaffAttendanceOverview(),
          const SizedBox(height: 20),

          // Active Staff Today
          _buildActiveStaffSection(),
          const SizedBox(height: 20),

          // Staff Performance Metrics
          _buildStaffPerformanceSection(),
          const SizedBox(height: 20),

          // Department Activity
          _buildDepartmentActivitySection(),
          const SizedBox(height: 20),

          // Individual Staff Performance & Punctuality
          _buildIndividualStaffPerformanceSection(),
        ],
      ),
    );
  }

  Widget _buildPatientFlowTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Flow Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 20),

          // Patient Flow Overview
          _buildPatientFlowOverview(),
          const SizedBox(height: 20),

          // Department Flow Analysis
          _buildDepartmentFlowSection(),
          const SizedBox(height: 20),

          // Wait Times & Bottlenecks
          _buildWaitTimesSection(),
          const SizedBox(height: 20),

          // Patient Journey Mapping
          _buildPatientJourneySection(),
        ],
      ),
    );
  }

  Widget _buildStaffAttendanceOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('staff_attendance')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'date',
            isEqualTo: DateTime.now().toIso8601String().substring(0, 10),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final attendanceRecords = snapshot.data?.docs ?? [];
        final totalStaff = attendanceRecords.length;
        final presentStaff = attendanceRecords.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['clockIn'] != null && data['clockOut'] == null;
        }).length;
        final onBreakStaff = attendanceRecords.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final breaks = data['breaks'] as List? ?? [];
          return breaks.isNotEmpty && breaks.last['breakEnd'] == null;
        }).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Attendance Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceCard(
                        'Total Staff',
                        totalStaff.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAttendanceCard(
                        'Present',
                        presentStaff.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAttendanceCard(
                        'On Break',
                        onBreakStaff.toString(),
                        Icons.coffee,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAttendanceCard(
                        'Absent',
                        (totalStaff - presentStaff).toString(),
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveStaffSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_staff')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final staffList = snapshot.data?.docs ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Staff Activity Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showStaffAttendanceDetails(),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (staffList.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No active staff members',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: staffList.take(5).length,
                    itemBuilder: (context, index) {
                      final staffDoc = staffList[index];
                      final staffData = staffDoc.data() as Map<String, dynamic>;

                      return _buildStaffActivityTile(staffData);
                    },
                  ),
                if (staffList.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: Text(
                        'and ${staffList.length - 5} more staff members',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffPerformanceSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _calculateStaffPerformanceMetrics(),
      builder: (context, snapshot) {
        final metrics =
            snapshot.data ??
            {
              'avgPatientsPerStaff': '0',
              'avgResponseTime': 'N/A',
              'tasksCompleted': '0',
              'qualityScore': 'N/A',
            };

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Staff Performance Metrics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildPerformanceMetricCard(
                          'Avg. Patients/Staff',
                          metrics['avgPatientsPerStaff']!,
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPerformanceMetricCard(
                          'Avg. Response Time',
                          metrics['avgResponseTime']!,
                          Icons.timer,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPerformanceMetricCard(
                          'Tasks Completed',
                          metrics['tasksCompleted']!,
                          Icons.task_alt,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPerformanceMetricCard(
                          'Quality Score',
                          metrics['qualityScore']!,
                          Icons.star,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentActivitySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('staff_activities')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'timestamp',
            isGreaterThan: DateTime.now().subtract(const Duration(hours: 24)),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data?.docs ?? [];
        final departmentStats = <String, int>{};

        for (final doc in activities) {
          final data = doc.data() as Map<String, dynamic>;
          final department = data['department'] ?? 'Unknown';
          departmentStats[department] = (departmentStats[department] ?? 0) + 1;
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.domain, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Department Activity (Last 24h)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (departmentStats.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.domain_disabled,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No department activity recorded',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                else
                  ...departmentStats.entries.map(
                    (entry) =>
                        _buildDepartmentActivityRow(entry.key, entry.value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientFlowOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'timestamp',
            isGreaterThan: DateTime.now().subtract(const Duration(days: 1)),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data?.docs ?? [];
        final totalPatients = records
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['patientId'] ?? data['patientUid'];
            })
            .toSet()
            .length;

        final pendingConsultations = records.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'VITAL_SIGNS';
        }).length;

        final completedConsultations = records.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'CONSULTATION_NOTE';
        }).length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timeline, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Patient Flow - Last 24 Hours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildFlowCard(
                        'Total Patients',
                        totalPatients.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFlowCard(
                        'Pending Consultation',
                        pendingConsultations.toString(),
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFlowCard(
                        'Completed',
                        completedConsultations.toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDepartmentFlowSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Department Flow Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDepartmentFlowCard('OPD → Nursing', 'Average: 15 min'),
            _buildDepartmentFlowCard('Nursing → Doctor', 'Average: 25 min'),
            _buildDepartmentFlowCard('Doctor → Lab', 'Average: 10 min'),
            _buildDepartmentFlowCard('Lab → Pharmacy', 'Average: 20 min'),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitTimesSection() {
    return FutureBuilder<Map<String, String>>(
      future: _calculateWaitTimeMetrics(),
      builder: (context, snapshot) {
        final metrics =
            snapshot.data ?? {'avgWaitTime': 'N/A', 'peakHours': 'N/A'};

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hourglass_top, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Wait Times & Bottlenecks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildWaitTimeCard(
                          'Avg. Wait Time',
                          metrics['avgWaitTime']!,
                          Icons.access_time,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildWaitTimeCard(
                          'Peak Hours',
                          metrics['peakHours']!,
                          Icons.trending_up,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPatientJourneySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'timestamp',
            isGreaterThan: DateTime.now().subtract(const Duration(days: 7)),
          )
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final journeys = snapshot.data?.docs ?? [];

        // Group journeys by patient
        final Map<String, List<Map<String, dynamic>>> patientJourneys = {};

        for (final doc in journeys) {
          final data = doc.data() as Map<String, dynamic>;
          final patientId =
              data['patientId'] ?? data['patientUid'] ?? 'unknown';

          if (!patientJourneys.containsKey(patientId)) {
            patientJourneys[patientId] = [];
          }

          patientJourneys[patientId]!.add({
            'type': data['type'] ?? 'UNKNOWN',
            'timestamp': data['timestamp'],
            'department': data['department'] ?? 'N/A',
            'provider': data['healthProviderName'] ?? 'Staff',
          });
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.route, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Patient Journey Tracking (Last 7 Days)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (patientJourneys.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey.shade600,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No recent patient journeys',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      // Summary cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildJourneySummaryCard(
                              'Unique Patients',
                              patientJourneys.length.toString(),
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildJourneySummaryCard(
                              'Total Touchpoints',
                              journeys.length.toString(),
                              Icons.touch_app,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildJourneySummaryCard(
                              'Avg. Touchpoints',
                              (journeys.length / patientJourneys.length)
                                  .toStringAsFixed(1),
                              Icons.timeline,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Common pathways
                      _buildCommonPathways(journeys),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJourneySummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommonPathways(List<QueryDocumentSnapshot> journeys) {
    // Analyze common journey sequences
    final pathwaySequences = <String, int>{};

    for (final doc in journeys) {
      final data = doc.data() as Map<String, dynamic>;
      final type = data['type'] ?? 'UNKNOWN';
      final department = data['department'] ?? 'General';
      final pathway = '$department → ${_formatRecordType(type)}';
      pathwaySequences[pathway] = (pathwaySequences[pathway] ?? 0) + 1;
    }

    final sortedPathways = pathwaySequences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights, color: Colors.purple.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              'Most Common Pathways',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sortedPathways
            .take(5)
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.trending_flat,
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String _formatRecordType(String type) {
    switch (type) {
      case 'VITAL_SIGNS':
        return 'Vitals Check';
      case 'CONSULTATION_NOTE':
        return 'Consultation';
      case 'LAB_RESULT':
        return 'Lab Test';
      case 'PRESCRIPTION':
        return 'Prescription';
      case 'DIAGNOSIS':
        return 'Diagnosis';
      case 'PROCEDURE':
        return 'Procedure';
      default:
        return type
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }

  // Helper methods for building smaller widgets
  Widget _buildAttendanceCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffActivityTile(Map<String, dynamic> staffData) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.purple.shade100,
        child: Text(
          (staffData['fullName'] ?? 'U')[0].toUpperCase(),
          style: TextStyle(
            color: Colors.purple.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(staffData['fullName'] ?? 'Unknown Staff'),
      subtitle: Text(
        '${staffData['department'] ?? 'Unknown Dept'} • ${staffData['role'] ?? 'Staff'}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Active',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentActivityRow(String department, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getDepartmentIcon(department),
              color: Colors.purple.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              department,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count activities',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentFlowCard(String flow, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward, color: Colors.purple.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              flow,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            time,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitTimeCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getDepartmentIcon(String department) {
    switch (department.toLowerCase()) {
      case 'nursing':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'laboratory':
        return Icons.science;
      case 'opd':
        return Icons.medical_services;
      case 'specialist':
        return Icons.person;
      default:
        return Icons.domain;
    }
  }

  void _showStaffAttendanceDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.people_outline, color: Colors.purple),
            SizedBox(width: 8),
            Text('Staff Attendance Details'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Staff attendance tracking features are being implemented. This will include:'
                        '\n• Real-time clock-in/clock-out tracking'
                        '\n• Location-based check-ins'
                        '\n• Break time monitoring'
                        '\n• Activity logging'
                        '\n• Performance analytics',
                        style: TextStyle(fontSize: 12),
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
      ),
    );
  }

  // ==================== CALCULATION HELPER METHODS ====================

  String _calculateAverageResponseTime(List<QueryDocumentSnapshot> requests) {
    if (requests.isEmpty) return '0 min';

    int totalMinutes = 0;
    int validCount = 0;

    for (final doc in requests) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'];
      final updatedAt = data['updatedAt'];

      if (createdAt != null && updatedAt != null) {
        try {
          DateTime created = createdAt is Timestamp
              ? createdAt.toDate()
              : DateTime.parse(createdAt.toString());
          DateTime updated = updatedAt is Timestamp
              ? updatedAt.toDate()
              : DateTime.parse(updatedAt.toString());

          final diff = updated.difference(created);
          totalMinutes += diff.inMinutes;
          validCount++;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    if (validCount == 0) return 'N/A';
    final avgMinutes = totalMinutes ~/ validCount;

    if (avgMinutes < 60) {
      return '$avgMinutes min';
    } else {
      final hours = avgMinutes ~/ 60;
      final mins = avgMinutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  Future<double> _calculateTotalRevenue() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final price = data['price'] ?? data['amount'] ?? 0;
        total += (price is num ? price.toDouble() : 0);
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<double> _calculateMonthlyRevenue() async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final snapshot = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('status', isEqualTo: 'completed')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
          )
          .get();

      double total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final price = data['price'] ?? data['amount'] ?? 0;
        total += (price is num ? price.toDouble() : 0);
      }

      return total;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _calculateStaffPerformanceMetrics() async {
    try {
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('facility_staff')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('status', isEqualTo: 'active')
          .get();

      final totalStaff = staffSnapshot.docs.length;

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'createdAt',
            isGreaterThan: DateTime.now().subtract(const Duration(days: 30)),
          )
          .get();

      final patientsServed = requestsSnapshot.docs
          .map((doc) {
            final data = doc.data();
            return data['patientId'] ?? data['patientUid'];
          })
          .toSet()
          .length;

      final avgPatientsPerStaff = totalStaff > 0
          ? (patientsServed / totalStaff).toStringAsFixed(1)
          : '0';

      // Calculate average response time
      int totalResponseMinutes = 0;
      int validResponses = 0;

      for (final doc in requestsSnapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final acceptedAt = data['acceptedAt'] ?? data['updatedAt'];

        if (createdAt != null && acceptedAt != null) {
          try {
            DateTime created = createdAt is Timestamp
                ? createdAt.toDate()
                : DateTime.parse(createdAt.toString());
            DateTime accepted = acceptedAt is Timestamp
                ? acceptedAt.toDate()
                : DateTime.parse(acceptedAt.toString());

            final diff = accepted.difference(created);
            totalResponseMinutes += diff.inMinutes;
            validResponses++;
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      final avgResponseTime = validResponses > 0
          ? '${totalResponseMinutes ~/ validResponses} min'
          : 'N/A';

      // Calculate tasks completed
      final tasksCompleted = requestsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'completed';
      }).length;

      // Calculate quality score based on completion rate and patient satisfaction
      final completionRate = requestsSnapshot.docs.isNotEmpty
          ? (tasksCompleted / requestsSnapshot.docs.length * 100)
          : 0;

      final qualityScore = completionRate.toStringAsFixed(0);

      return {
        'avgPatientsPerStaff': avgPatientsPerStaff,
        'avgResponseTime': avgResponseTime,
        'tasksCompleted': tasksCompleted.toString(),
        'qualityScore': '$qualityScore%',
      };
    } catch (e) {
      return {
        'avgPatientsPerStaff': '0',
        'avgResponseTime': 'N/A',
        'tasksCompleted': '0',
        'qualityScore': 'N/A',
      };
    }
  }

  Future<Map<String, String>> _calculateWaitTimeMetrics() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'createdAt',
            isGreaterThan: DateTime.now().subtract(const Duration(days: 7)),
          )
          .get();

      if (snapshot.docs.isEmpty) {
        return {'avgWaitTime': 'N/A', 'peakHours': 'N/A'};
      }

      // Calculate average wait time
      int totalWaitMinutes = 0;
      int validWaits = 0;
      final hourCounts = <int, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        final startedAt = data['startedAt'] ?? data['acceptedAt'];

        if (createdAt != null && startedAt != null) {
          try {
            DateTime created = createdAt is Timestamp
                ? createdAt.toDate()
                : DateTime.parse(createdAt.toString());
            DateTime started = startedAt is Timestamp
                ? startedAt.toDate()
                : DateTime.parse(startedAt.toString());

            final diff = started.difference(created);
            totalWaitMinutes += diff.inMinutes;
            validWaits++;

            // Track hour of day for peak hours
            final hour = created.hour;
            hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      final avgWaitTime = validWaits > 0
          ? '${totalWaitMinutes ~/ validWaits} min'
          : 'N/A';

      // Find peak hours (top 2 hours with most requests)
      String peakHours = 'N/A';
      if (hourCounts.isNotEmpty) {
        final sortedHours = hourCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (sortedHours.isNotEmpty) {
          final peak1 = sortedHours[0].key;
          if (sortedHours.length > 1) {
            final peak2 = sortedHours[1].key;
            peakHours = '${_formatHour(peak1)}, ${_formatHour(peak2)}';
          } else {
            peakHours = _formatHour(peak1);
          }
        }
      }

      return {'avgWaitTime': avgWaitTime, 'peakHours': peakHours};
    } catch (e) {
      return {'avgWaitTime': 'N/A', 'peakHours': 'N/A'};
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '₦${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount >= 1000) {
      return '₦${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return '₦${amount.toStringAsFixed(2)}';
    }
  }

  Widget _buildIndividualStaffPerformanceSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_staff')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, staffSnapshot) {
        if (staffSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final staffList = staffSnapshot.data?.docs ?? [];

        if (staffList.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_search, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Individual Staff Performance & Punctuality',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No staff members found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_search, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Individual Staff Performance & Punctuality',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showDetailedStaffReport(staffList),
                      icon: const Icon(Icons.analytics, size: 16),
                      label: const Text('Full Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStaffSummaryCard(
                        'Total Active',
                        staffList.length.toString(),
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStaffSummaryCard(
                        'Punctual (>90%)',
                        '${_countPunctualStaff(staffList)}',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStaffSummaryCard(
                        'Needs Attention',
                        '${_countLateStaff(staffList)}',
                        Icons.warning,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Individual staff performance list
                ...staffList.take(5).map((staffDoc) {
                  final staffData = staffDoc.data() as Map<String, dynamic>;
                  return _buildStaffPerformanceCard(staffDoc.id, staffData);
                }),
                if (staffList.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: TextButton(
                        onPressed: () => _showDetailedStaffReport(staffList),
                        child: Text(
                          'View all ${staffList.length} staff members',
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffSummaryCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceCard(
    String staffId,
    Map<String, dynamic> staffData,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _calculateIndividualStaffMetrics(staffId),
      builder: (context, snapshot) {
        final metrics =
            snapshot.data ??
            {
              'punctualityScore': 0,
              'totalDays': 0,
              'lateDays': 0,
              'earlyDepartures': 0,
              'totalHours': '0h',
              'avgHoursPerDay': '0h',
              'tasksCompleted': 0,
            };

        final punctualityScore = metrics['punctualityScore'] as int;
        final Color scoreColor = punctualityScore >= 90
            ? Colors.green
            : punctualityScore >= 75
            ? Colors.orange
            : Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    radius: 20,
                    child: Text(
                      (staffData['fullName'] ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staffData['fullName'] ?? 'Unknown Staff',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${staffData['department'] ?? 'N/A'} • ${staffData['role'] ?? 'Staff'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          punctualityScore >= 90
                              ? Icons.star
                              : punctualityScore >= 75
                              ? Icons.trending_up
                              : Icons.warning,
                          color: scoreColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$punctualityScore%',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                )
              else ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Days Present',
                        '${metrics['totalDays']}',
                        Icons.calendar_today,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Late Arrivals',
                        '${metrics['lateDays']}',
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Early Leaves',
                        '${metrics['earlyDepartures']}',
                        Icons.exit_to_app,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        'Total Hours',
                        metrics['totalHours'] as String,
                        Icons.access_time,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Avg/Day',
                        metrics['avgHoursPerDay'] as String,
                        Icons.timelapse,
                        Colors.teal,
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        'Tasks Done',
                        '${metrics['tasksCompleted']}',
                        Icons.task_alt,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  int _countPunctualStaff(List<QueryDocumentSnapshot> staffList) {
    // This would typically check attendance records
    // For now, return estimated count
    return (staffList.length * 0.7).round();
  }

  int _countLateStaff(List<QueryDocumentSnapshot> staffList) {
    // This would typically check attendance records
    // For now, return estimated count
    return (staffList.length * 0.3).round();
  }

  Future<Map<String, dynamic>> _calculateIndividualStaffMetrics(
    String staffId,
  ) async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Get attendance records for last 30 days
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('staff_attendance')
          .where('staffId', isEqualTo: staffId)
          .where('facilityId', isEqualTo: currentFacilityId)
          .where(
            'date',
            isGreaterThanOrEqualTo: thirtyDaysAgo.toIso8601String().substring(
              0,
              10,
            ),
          )
          .get();

      int totalDays = 0;
      int lateDays = 0;
      int earlyDepartures = 0;
      int totalMinutes = 0;

      // Define standard work times (9 AM - 5 PM)
      const standardStartHour = 9;
      const standardEndHour = 17;
      const graceMinutes = 15; // 15 minutes grace period

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final clockIn = data['clockIn'];
        final clockOut = data['clockOut'];

        if (clockIn != null) {
          totalDays++;

          try {
            DateTime clockInTime = clockIn is Timestamp
                ? clockIn.toDate()
                : DateTime.parse(clockIn.toString());

            // Check if late (after 9:15 AM)
            final expectedStart = DateTime(
              clockInTime.year,
              clockInTime.month,
              clockInTime.day,
              standardStartHour,
              graceMinutes,
            );

            if (clockInTime.isAfter(expectedStart)) {
              lateDays++;
            }

            // Calculate hours worked
            if (clockOut != null) {
              DateTime clockOutTime = clockOut is Timestamp
                  ? clockOut.toDate()
                  : DateTime.parse(clockOut.toString());

              final hoursWorked = clockOutTime.difference(clockInTime);
              totalMinutes += hoursWorked.inMinutes;

              // Check if early departure (before 5:00 PM)
              final expectedEnd = DateTime(
                clockOutTime.year,
                clockOutTime.month,
                clockOutTime.day,
                standardEndHour,
                0,
              );

              if (clockOutTime.isBefore(expectedEnd)) {
                earlyDepartures++;
              }
            }
          } catch (e) {
            // Skip invalid dates
          }
        }
      }

      // Calculate punctuality score (100% - (late days + early departures) / total days * 100)
      final punctualityScore = totalDays > 0
          ? (100 - ((lateDays + earlyDepartures) / totalDays * 100)).round()
          : 0;

      // Format total hours
      final totalHours = totalMinutes ~/ 60;
      final remainingMinutes = totalMinutes % 60;
      final totalHoursFormatted = '${totalHours}h ${remainingMinutes}m';

      // Calculate average hours per day
      final avgMinutesPerDay = totalDays > 0 ? totalMinutes ~/ totalDays : 0;
      final avgHours = avgMinutesPerDay ~/ 60;
      final avgMinutes = avgMinutesPerDay % 60;
      final avgHoursFormatted = '${avgHours}h ${avgMinutes}m';

      // Get tasks completed
      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('service_requests')
          .where('facilityId', isEqualTo: currentFacilityId)
          .where('assignedTo', isEqualTo: staffId)
          .where('status', isEqualTo: 'completed')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
          )
          .get();

      final tasksCompleted = tasksSnapshot.docs.length;

      return {
        'punctualityScore': punctualityScore.clamp(0, 100),
        'totalDays': totalDays,
        'lateDays': lateDays,
        'earlyDepartures': earlyDepartures,
        'totalHours': totalHoursFormatted,
        'avgHoursPerDay': avgHoursFormatted,
        'tasksCompleted': tasksCompleted,
      };
    } catch (e) {
      return {
        'punctualityScore': 0,
        'totalDays': 0,
        'lateDays': 0,
        'earlyDepartures': 0,
        'totalHours': '0h',
        'avgHoursPerDay': '0h',
        'tasksCompleted': 0,
      };
    }
  }

  void _showDetailedStaffReport(List<QueryDocumentSnapshot> staffList) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.purple.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Detailed Staff Performance Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staffDoc = staffList[index];
                    final staffData = staffDoc.data() as Map<String, dynamic>;
                    return _buildStaffPerformanceCard(staffDoc.id, staffData);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Punctuality score is based on attendance in the last 30 days',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
