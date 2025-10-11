// lib/screens/facilityscreen/facility_analytics_screen.dart

// ignore_for_file: deprecated_member_use, prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Services'),
            Tab(icon: Icon(Icons.trending_up), text: 'Performance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildServicesTab(),
          _buildPerformanceTab(),
        ],
      ),
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

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildStatCard(
                    'Total Requests',
                    totalRequests.toString(),
                    Icons.medical_services,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Pending',
                    pendingRequests.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Completed',
                    completedRequests.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Cancelled',
                    cancelledRequests.toString(),
                    Icons.cancel,
                    Colors.red,
                  ),
                ],
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
                            'Coming Soon',
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
              trailing: const Text(
                'Coming Soon',
                style: TextStyle(
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
              trailing: const Text(
                'Coming Soon',
                style: TextStyle(
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
}
