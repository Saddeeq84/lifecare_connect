import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/data/services/user_analytics_service.dart';
import '../../../shared/presentation/widgets/charts/analytics_charts.dart';
import '../../../../core/services/error_handler.dart';
import '../../../../core/services/loading_service.dart';

class DoctorAnalyticsScreen extends StatefulWidget {
  const DoctorAnalyticsScreen({super.key});

  @override
  State<DoctorAnalyticsScreen> createState() => _DoctorAnalyticsScreenState();
}

class _DoctorAnalyticsScreenState extends State<DoctorAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final String currentDoctorId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        backgroundColor: Colors.indigo,
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
            Tab(icon: Icon(Icons.trending_up), text: 'Performance'),
            Tab(icon: Icon(Icons.people_alt), text: 'Patients'),
            Tab(icon: Icon(Icons.assignment), text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DoctorOverviewTab(doctorId: currentDoctorId),
          DoctorPerformanceTab(doctorId: currentDoctorId),
          DoctorPatientsTab(doctorId: currentDoctorId),
          DoctorReportsTab(doctorId: currentDoctorId),
        ],
      ),
    );
  }
}

class DoctorOverviewTab extends StatelessWidget {
  final String doctorId;

  const DoctorOverviewTab({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Patients',
                  Icons.people,
                  Colors.blue,
                  _getPatientsStream(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Appointments',
                  Icons.calendar_today,
                  Colors.green,
                  _getAppointmentsStream(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Referrals Made',
                  Icons.send_to_mobile,
                  Colors.orange,
                  _getReferralsStream(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Consultations',
                  Icons.video_call,
                  Colors.purple,
                  _getConsultationsStream(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color color,
    Stream<QuerySnapshot> stream,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                int count = 0;
                if (title == 'Total Patients') {
                  // For patients, count unique patient IDs from appointments
                  final docs = snapshot.data?.docs ?? [];
                  final uniquePatientIds = <String>{};
                  for (var doc in docs) {
                    final patientId = doc.data() as Map<String, dynamic>?;
                    final id = patientId?['patientId'] as String?;
                    if (id != null) {
                      uniquePatientIds.add(id);
                    }
                  }
                  count = uniquePatientIds.length;
                } else {
                  count = snapshot.data?.docs.length ?? 0;
                }

                return Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activity'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Colors.indigo,
                  ),
                  title: Text(data['patientName'] ?? 'Unknown Patient'),
                  subtitle: Text(data['type'] ?? 'Appointment'),
                  trailing: Text(_formatDate(data['appointmentDate'])),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getPatientsStream() {
    // Get appointments for this doctor to count unique patients
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getAppointmentsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getReferralsStream() {
    return FirebaseFirestore.instance
        .collection('referrals')
        .where('referringDoctorId', isEqualTo: doctorId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getConsultationsStream() {
    return FirebaseFirestore.instance
        .collection('consultations')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'Unknown';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class DoctorReportsTab extends StatelessWidget {
  final String doctorId;

  const DoctorReportsTab({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildReportOption(
            context,
            'Patient Summary Report',
            'Generate a comprehensive report of all your patients',
            Icons.people,
            Colors.blue,
            () => _generatePatientReport(context),
          ),

          _buildReportOption(
            context,
            'Appointment History',
            'View and export your appointment history',
            Icons.calendar_today,
            Colors.green,
            () => _generateAppointmentReport(context),
          ),

          _buildReportOption(
            context,
            'Referral Analytics',
            'Analyze your referral patterns and outcomes',
            Icons.send_to_mobile,
            Colors.orange,
            () => _generateReferralReport(context),
          ),

          _buildReportOption(
            context,
            'Consultation Metrics',
            'Review your consultation statistics',
            Icons.video_call,
            Colors.purple,
            () => _generateConsultationReport(context),
          ),

          const SizedBox(height: 32),

          const Text(
            'Recent Reports',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildRecentReports(),
        ],
      ),
    );
  }

  Widget _buildReportOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No reports generated yet'),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.description, color: Colors.indigo),
                title: Text(data['title'] ?? 'Report'),
                subtitle: Text(data['type'] ?? 'Unknown'),
                trailing: Text(_formatDate(data['createdAt'])),
                onTap: () => _viewReport(context, data, doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _generatePatientReport(BuildContext context) {
    _showPatientSummaryReport(context);
  }

  void _generateAppointmentReport(BuildContext context) {
    _showAppointmentHistoryReport(context);
  }

  void _generateReferralReport(BuildContext context) {
    _showReferralAnalyticsReport(context);
  }

  void _generateConsultationReport(BuildContext context) {
    _showConsultationMetricsReport(context);
  }

  void _viewReport(
    BuildContext context,
    Map<String, dynamic> data,
    String reportId,
  ) {
    // Open detailed report view
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${data['type'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Generated: ${_formatDate(data['createdAt'])}'),
            const SizedBox(height: 8),
            Text('Content: ${data['summary'] ?? 'No summary available'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPatientSummaryReport(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Patient Summary Report'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('doctorId', isEqualTo: doctorId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No patient data available'));
              }

              // Process patient data
              Map<String, Map<String, dynamic>> patientsData = {};
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final patientId = data['patientId'] as String?;
                final patientName = data['patientName'] as String? ?? 'Unknown';

                if (patientId != null) {
                  patientsData.putIfAbsent(
                    patientId,
                    () => {
                      'name': patientName,
                      'appointments': 0,
                      'lastVisit': null,
                    },
                  );

                  patientsData[patientId]!['appointments']++;

                  final timestamp = data['appointmentDate'];
                  if (timestamp != null) {
                    final date = timestamp is Timestamp
                        ? timestamp.toDate()
                        : DateTime.tryParse(timestamp.toString());
                    if (date != null) {
                      final current =
                          patientsData[patientId]!['lastVisit'] as DateTime?;
                      if (current == null || date.isAfter(current)) {
                        patientsData[patientId]!['lastVisit'] = date;
                      }
                    }
                  }
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Patients: ${patientsData.length}'),
                    const SizedBox(height: 16),
                    const Text(
                      'Patient List:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...patientsData.entries.map((entry) {
                      final patient = entry.value;
                      final lastVisit = patient['lastVisit'] as DateTime?;
                      return Card(
                        child: ListTile(
                          title: Text(patient['name']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Appointments: ${patient['appointments']}'),
                              Text(
                                'Last Visit: ${lastVisit != null ? DateFormat('MMM dd, yyyy').format(lastVisit) : 'Never'}',
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAppointmentHistoryReport(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Appointment History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('doctorId', isEqualTo: doctorId)
                .orderBy('appointmentDate', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No appointments found'));
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Appointments: ${snapshot.data!.docs.length}'),
                    const SizedBox(height: 16),
                    ...snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final status = data['status'] as String? ?? 'Unknown';
                      final patientName =
                          data['patientName'] as String? ?? 'Unknown Patient';
                      final appointmentDate = data['appointmentDate'];

                      String dateStr = 'Unknown Date';
                      if (appointmentDate != null) {
                        final date = appointmentDate is Timestamp
                            ? appointmentDate.toDate()
                            : DateTime.tryParse(appointmentDate.toString());
                        if (date != null) {
                          dateStr = DateFormat(
                            'MMM dd, yyyy - HH:mm',
                          ).format(date);
                        }
                      }

                      return Card(
                        child: ListTile(
                          title: Text(patientName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: $dateStr'),
                              Text('Status: $status'),
                              if (data['reason'] != null)
                                Text('Reason: ${data['reason']}'),
                            ],
                          ),
                          trailing: _getStatusIcon(status),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showReferralAnalyticsReport(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Referral Analytics'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('referrals')
                .where('referringDoctorId', isEqualTo: doctorId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No referrals found'));
              }

              // Process referral analytics
              Map<String, int> facilityCount = {};
              Map<String, int> statusCount = {};
              int totalReferrals = snapshot.data!.docs.length;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final facility =
                    data['facilityName'] as String? ?? 'Unknown Facility';
                final status = data['status'] as String? ?? 'pending';

                facilityCount[facility] = (facilityCount[facility] ?? 0) + 1;
                statusCount[status] = (statusCount[status] ?? 0) + 1;
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Referrals: $totalReferrals'),
                    const SizedBox(height: 16),

                    const Text(
                      'By Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...statusCount.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'By Facility:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...facilityCount.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Recent Referrals:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...snapshot.data!.docs.take(10).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text(data['patientName'] ?? 'Unknown Patient'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Facility: ${data['facilityName'] ?? 'Unknown'}',
                              ),
                              Text('Status: ${data['status'] ?? 'pending'}'),
                              Text('Date: ${_formatDate(data['createdAt'])}'),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showConsultationMetricsReport(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Consultation Metrics'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('consultations')
                .where('doctorId', isEqualTo: doctorId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No consultations found'));
              }

              // Process consultation metrics
              Map<String, int> monthlyCount = {};
              Map<String, int> statusCount = {};
              int totalConsultations = snapshot.data!.docs.length;
              int totalDuration = 0;

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as String? ?? 'completed';
                final duration = data['duration'] as int? ?? 0;

                statusCount[status] = (statusCount[status] ?? 0) + 1;
                totalDuration += duration;

                final timestamp = data['createdAt'];
                if (timestamp != null) {
                  final date = timestamp is Timestamp
                      ? timestamp.toDate()
                      : DateTime.tryParse(timestamp.toString());
                  if (date != null) {
                    final monthKey = DateFormat('MMM yyyy').format(date);
                    monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
                  }
                }
              }

              final avgDuration = totalConsultations > 0
                  ? totalDuration / totalConsultations
                  : 0;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Consultations: $totalConsultations'),
                    Text(
                      'Average Duration: ${avgDuration.toStringAsFixed(1)} minutes',
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'By Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...statusCount.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Monthly Distribution:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...monthlyCount.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${entry.key}: ${entry.value}'),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Recent Consultations:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...snapshot.data!.docs.take(10).map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text(data['patientName'] ?? 'Unknown Patient'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Duration: ${data['duration'] ?? 0} minutes',
                              ),
                              Text('Status: ${data['status'] ?? 'completed'}'),
                              Text('Date: ${_formatDate(data['createdAt'])}'),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'cancelled':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'pending':
        return const Icon(Icons.schedule, color: Colors.orange);
      default:
        return const Icon(Icons.help, color: Colors.grey);
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      return 'Unknown';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class DoctorAnalyticsTab extends StatelessWidget {
  final String doctorId;

  const DoctorAnalyticsTab({super.key, required this.doctorId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildPerformanceMetrics(),

          const SizedBox(height: 32),

          const Text(
            'Trends & Patterns',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildTrendsSection(),

          const SizedBox(height: 32),

          const Text(
            'Key Insights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildInsightsSection(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Patient Satisfaction',
                '4.8/5.0',
                Icons.thumb_up,
                Colors.green,
                '+0.2 from last month',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Response Time',
                '15 min',
                Icons.schedule,
                Colors.blue,
                '-5 min from last month',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Appointment Success',
                '92%',
                Icons.check_circle,
                Colors.purple,
                '+3% from last month',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Referral Accuracy',
                '89%',
                Icons.send_to_mobile,
                Colors.orange,
                '+1% from last month',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Activity Trends',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.show_chart, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Chart visualization coming soon',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      children: [
        _buildInsightCard(
          'Peak Hours',
          'Your busiest consultation hours are between 2-4 PM',
          Icons.schedule,
          Colors.blue,
        ),
        _buildInsightCard(
          'Patient Demographics',
          'Most patients are in the 25-45 age range',
          Icons.pie_chart,
          Colors.green,
        ),
        _buildInsightCard(
          'Common Conditions',
          'Hypertension and diabetes are most frequent',
          Icons.health_and_safety,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildInsightCard(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }
}

// Enhanced Performance Analytics Tab
class DoctorPerformanceTab extends StatefulWidget {
  final String doctorId;

  const DoctorPerformanceTab({super.key, required this.doctorId});

  @override
  State<DoctorPerformanceTab> createState() => _DoctorPerformanceTabState();
}

class _DoctorPerformanceTabState extends State<DoctorPerformanceTab> {
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPerformanceData();
  }

  Future<void> _loadPerformanceData() async {
    setState(() => _isLoading = true);

    try {
      final analytics = await UserAnalyticsService.getUserAnalytics(
        userId: widget.doctorId,
        role: 'doctor',
      );
      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      ErrorHandler.handleError(
        e,
        context: 'Loading performance analytics',
        buildContext: context,
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return LoadingService.buildShimmerList(itemCount: 5, itemHeight: 120);
    }

    final activityData =
        _analyticsData['activity_analytics'] as Map<String, dynamic>? ?? {};
    final performanceData =
        _analyticsData['performance_metrics'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadPerformanceData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPerformanceOverview(activityData, performanceData),
            const SizedBox(height: 20),
            _buildKPICards(activityData),
            const SizedBox(height: 20),
            _buildPerformanceTrends(performanceData),
            const SizedBox(height: 20),
            _buildBenchmarking(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceOverview(
    Map<String, dynamic> activityData,
    Map<String, dynamic> performanceData,
  ) {
    final score = performanceData['performance_score']?.toDouble() ?? 0.0;
    final appointments =
        activityData['appointments'] as Map<String, dynamic>? ?? {};
    final consultations =
        activityData['consultations'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.indigo.shade400, Colors.indigo.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Overview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clinical Score',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completion Rate',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _calculateCompletionRate(appointments, consultations),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards(Map<String, dynamic> activityData) {
    final appointments =
        activityData['appointments'] as Map<String, dynamic>? ?? {};
    final consultations =
        activityData['consultations'] as Map<String, dynamic>? ?? {};
    final referrals = activityData['referrals'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'Patient Load',
                '${appointments['total'] ?? 0}',
                'Total appointments',
                Icons.people_alt,
                Colors.blue,
                trend: '+12%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                'Success Rate',
                '${_calculateSuccessPercentage(consultations)}%',
                'Completed consultations',
                Icons.check_circle,
                Colors.green,
                trend: '+5%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                'Referrals',
                '${referrals['total'] ?? 0}',
                'Cases referred',
                Icons.send,
                Colors.orange,
                trend: '+3%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKPICard(
                'Response Time',
                '~24h',
                'Average response',
                Icons.schedule,
                Colors.purple,
                trend: '-2h',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    String? trend,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                if (trend != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: trend.startsWith('+')
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      trend,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: trend.startsWith('+')
                            ? Colors.green
                            : Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTrends(Map<String, dynamic> performanceData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Performance Trends',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AnalyticsLineChart(
              data: [
                ChartDataPoint(x: 1, y: 85, label: 'Jan'),
                ChartDataPoint(x: 2, y: 78, label: 'Feb'),
                ChartDataPoint(x: 3, y: 92, label: 'Mar'),
                ChartDataPoint(x: 4, y: 88, label: 'Apr'),
                ChartDataPoint(x: 5, y: 95, label: 'May'),
                ChartDataPoint(x: 6, y: 91, label: 'Jun'),
              ],
              title: '',
              primaryColor: Colors.indigo,
              height: 200,
              xAxisLabel: 'Performance Over Time',
            ),
            const SizedBox(height: 16),
            _buildTrendMetrics(performanceData),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendMetrics(Map<String, dynamic> performanceData) {
    final activityTrend =
        performanceData['activity_trend_percentage']?.toDouble() ?? 0.0;
    final thisMonth = performanceData['this_month_activities'] ?? 0;
    final lastMonth = performanceData['last_month_activities'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildTrendMetric(
            'Activity Trend',
            '${activityTrend >= 0 ? '+' : ''}${activityTrend.toStringAsFixed(1)}%',
            activityTrend >= 0 ? Icons.trending_up : Icons.trending_down,
            activityTrend >= 0 ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTrendMetric(
            'This Month',
            '$thisMonth activities',
            Icons.calendar_month,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTrendMetric(
            'Last Month',
            '$lastMonth activities',
            Icons.history,
            Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarking() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Benchmarking',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildBenchmarkItem('Patient Satisfaction', 4.2, 4.0),
            _buildBenchmarkItem('Response Time', 3.8, 4.1),
            _buildBenchmarkItem('Consultation Quality', 4.5, 4.2),
            _buildBenchmarkItem('Treatment Success', 4.1, 3.9),
          ],
        ),
      ),
    );
  }

  Widget _buildBenchmarkItem(String metric, double yourScore, double average) {
    final isAboveAverage = yourScore > average;
    final color = isAboveAverage ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metric, style: const TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Text(
                    '${yourScore.toStringAsFixed(1)}/5.0',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isAboveAverage ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: (yourScore * 20).round(),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Expanded(
                flex: (100 - (yourScore * 20)).round(),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Average: ${average.toStringAsFixed(1)}/5.0',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _calculateCompletionRate(
    Map<String, dynamic> appointments,
    Map<String, dynamic> consultations,
  ) {
    final totalAppointments = appointments['total'] ?? 0;
    final completedAppointments = appointments['completed'] ?? 0;

    if (totalAppointments == 0) return '0%';

    final rate = (completedAppointments / totalAppointments * 100)
        .toStringAsFixed(0);
    return '$rate%';
  }

  int _calculateSuccessPercentage(Map<String, dynamic> consultations) {
    final total = consultations['total'] ?? 0;
    final completed = consultations['completed'] ?? 0;

    if (total == 0) return 0;

    return ((completed / total) * 100).round();
  }
}

// Enhanced Patients Management Tab
class DoctorPatientsTab extends StatefulWidget {
  final String doctorId;

  const DoctorPatientsTab({super.key, required this.doctorId});

  @override
  State<DoctorPatientsTab> createState() => _DoctorPatientsTabState();
}

class _DoctorPatientsTabState extends State<DoctorPatientsTab> {
  String _selectedFilter = 'all';
  String _searchQuery = '';
  Set<String> _doctorPatientIds = {};
  bool _isLoadingPatientIds = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorPatientIds();
  }

  Future<void> _loadDoctorPatientIds() async {
    setState(() => _isLoadingPatientIds = true);

    try {
      Set<String> patientIds = {};

      // Get patients from appointments
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      for (var doc in appointmentsSnapshot.docs) {
        final patientId = doc.data()['patientId'] as String?;
        if (patientId != null) {
          patientIds.add(patientId);
        }
      }

      // Get patients from consultations
      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where('doctorId', isEqualTo: widget.doctorId)
          .get();

      for (var doc in consultationsSnapshot.docs) {
        final patientId = doc.data()['patientId'] as String?;
        if (patientId != null) {
          patientIds.add(patientId);
        }
      }

      setState(() {
        _doctorPatientIds = patientIds;
        _isLoadingPatientIds = false;
      });
    } catch (e) {
      ErrorHandler.handleError(
        e,
        context: 'Loading doctor patient data',
        buildContext: context,
      );
      setState(() => _isLoadingPatientIds = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPatientFilters(),
        Expanded(child: _buildPatientsList()),
      ],
    );
  }

  Widget _buildPatientFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search your patients...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadDoctorPatientIds,
                tooltip: 'Refresh patient list',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Patients', 'all'),
                _buildFilterChip('Recent', 'recent'),
                _buildFilterChip('High Risk', 'high_risk'),
                _buildFilterChip('Follow-up', 'follow_up'),
                _buildFilterChip('Chronic Care', 'chronic'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = value);
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.indigo.withOpacity(0.2),
        checkmarkColor: Colors.indigo,
      ),
    );
  }

  Widget _buildPatientsList() {
    if (_isLoadingPatientIds) {
      return LoadingService.buildShimmerList(itemCount: 3, itemHeight: 140);
    }

    if (_doctorPatientIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No patients in your care yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Patients will appear here when you have appointments or consultations with them',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getPatientsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No patients found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final allAppointments = snapshot.data!.docs;

        // Group appointments by patient to get unique patients
        Map<String, Map<String, dynamic>> uniquePatients = {};

        for (var doc in allAppointments) {
          final data = doc.data() as Map<String, dynamic>;
          final patientId = data['patientId'] as String?;
          final patientName =
              data['patientName'] as String? ?? 'Unknown Patient';

          if (patientId != null && patientName != 'Unknown Patient') {
            if (!uniquePatients.containsKey(patientId)) {
              uniquePatients[patientId] = {
                'id': patientId,
                'fullName': patientName,
                'name': patientName,
                'appointmentCount': 1,
                'lastAppointment': data['appointmentDate'],
                'lastAppointmentStatus': data['status'],
                'gender': data['patientGender'] ?? 'Unknown',
                'dateOfBirth': data['patientDOB'],
                'riskLevel': 'low', // Default risk level
                'primaryCondition': data['reason'] ?? 'General',
                'phone': data['patientPhone'] ?? '',
                'email': data['patientEmail'] ?? '',
              };
            } else {
              uniquePatients[patientId]!['appointmentCount']++;
              // Update with latest appointment if newer
              final currentDate = uniquePatients[patientId]!['lastAppointment'];
              final newDate = data['appointmentDate'];
              if (newDate != null &&
                  (currentDate == null ||
                      (newDate is Timestamp &&
                          currentDate is Timestamp &&
                          newDate.toDate().isAfter(currentDate.toDate())))) {
                uniquePatients[patientId]!['lastAppointment'] = newDate;
                uniquePatients[patientId]!['lastAppointmentStatus'] =
                    data['status'];
              }
            }
          }
        }

        final patientsList = uniquePatients.values.toList();

        // Filter patients based on search query
        final filteredPatients = _searchQuery.isEmpty
            ? patientsList
            : patientsList.where((patient) {
                final name = (patient['fullName'] ?? patient['name'] ?? '')
                    .toString()
                    .toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();

        if (filteredPatients.isEmpty && _searchQuery.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No patients found for "$_searchQuery"',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPatients.length,
          itemBuilder: (context, index) {
            final patient = filteredPatients[index];
            return _buildPatientCard(patient, patient['id']);
          },
        );
      },
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, String patientId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.indigo.withOpacity(0.1),
                  child: Text(
                    _getInitials(
                      patient['fullName'] ?? patient['name'] ?? 'Unknown',
                    ),
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient['fullName'] ??
                            patient['name'] ??
                            'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Age: ${_calculateAge(patient['dateOfBirth'])} • ${patient['gender'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                _buildRiskBadge(patient['riskLevel'] ?? 'low'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPatientMetric(
                    'Appointments',
                    _getAppointmentCount(patientId, patient),
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildPatientMetric(
                    'Last Visit',
                    _formatLastVisit(patient['lastAppointment']),
                    Icons.history,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildPatientMetric(
                    'Condition',
                    patient['primaryCondition'] ?? 'General',
                    Icons.medical_services,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(String riskLevel) {
    Color color;
    switch (riskLevel.toLowerCase()) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '${riskLevel.toUpperCase()} RISK',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPatientMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getPatientsStream() {
    // Instead of querying users collection, let's query appointments and show patient info from there
    // This ensures we only show patients who actually have appointments with this doctor
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('doctorId', isEqualTo: widget.doctorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  String _getInitials(String name) {
    return name
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0] : '')
        .join('')
        .substring(0, 2)
        .toUpperCase();
  }

  String _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return 'Unknown';

    try {
      DateTime birthDate;
      if (dateOfBirth is Timestamp) {
        birthDate = dateOfBirth.toDate();
      } else if (dateOfBirth is String) {
        birthDate = DateTime.parse(dateOfBirth);
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      int age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      return age.toString();
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getAppointmentCount(
    String patientId, [
    Map<String, dynamic>? patientData,
  ]) {
    // Use the appointment count from our processed data if available
    if (patientData != null && patientData['appointmentCount'] != null) {
      return patientData['appointmentCount'].toString();
    }
    return '0';
  }

  String _formatLastVisit(dynamic lastVisit) {
    if (lastVisit == null) return 'Never';

    try {
      DateTime visitDate;
      if (lastVisit is Timestamp) {
        visitDate = lastVisit.toDate();
      } else if (lastVisit is String) {
        visitDate = DateTime.parse(lastVisit);
      } else {
        return 'Unknown';
      }

      final difference = DateTime.now().difference(visitDate).inDays;
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Yesterday';
      if (difference < 7) return '${difference}d ago';
      if (difference < 30) return '${(difference / 7).round()}w ago';
      return '${(difference / 30).round()}mo ago';
    } catch (e) {
      return 'Unknown';
    }
  }
}
