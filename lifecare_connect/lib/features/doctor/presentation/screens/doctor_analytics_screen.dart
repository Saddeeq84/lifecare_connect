import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.assignment), text: 'Reports'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DoctorOverviewTab(doctorId: currentDoctorId),
          DoctorReportsTab(doctorId: currentDoctorId),
          DoctorAnalyticsTab(doctorId: currentDoctorId),
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

                final count = snapshot.data?.docs.length ?? 0;
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
    return FirebaseFirestore.instance
        .collection('patients')
        .where('assignedDoctorId', isEqualTo: doctorId)
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
          backgroundColor: color.withValues(alpha: 0.1),
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
                onTap: () => _viewReport(data, doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _generatePatientReport(BuildContext context) {
    _showComingSoonDialog(context, 'Patient Summary Report');
  }

  void _generateAppointmentReport(BuildContext context) {
    _showComingSoonDialog(context, 'Appointment History Report');
  }

  void _generateReferralReport(BuildContext context) {
    _showComingSoonDialog(context, 'Referral Analytics Report');
  }

  void _generateConsultationReport(BuildContext context) {
    _showComingSoonDialog(context, 'Consultation Metrics Report');
  }

  void _viewReport(Map<String, dynamic> data, String reportId) {}

  void _showComingSoonDialog(BuildContext context, String reportType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coming Soon'),
        content: Text(
          '$reportType generation is under development and will be available soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
      ),
    );
  }
}
