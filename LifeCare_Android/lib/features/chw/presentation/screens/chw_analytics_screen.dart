// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/services/user_analytics_service.dart';

class CHWAnalyticsScreen extends StatefulWidget {
  const CHWAnalyticsScreen({super.key});

  @override
  State<CHWAnalyticsScreen> createState() => _CHWAnalyticsScreenState();
}

class _CHWAnalyticsScreenState extends State<CHWAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final String currentCHWId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoading = false;
  Map<String, dynamic> _analyticsData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    if (currentCHWId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final analytics = await UserAnalyticsService.getUserAnalytics(
        userId: currentCHWId,
        role: 'chw',
      );

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Reports & Analytics'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading your analytics...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                CHWOverviewTab(
                  chwId: currentCHWId,
                  analyticsData: _analyticsData,
                ),
                CHWReportsTab(chwId: currentCHWId),
                CHWAnalyticsTab(
                  chwId: currentCHWId,
                  analyticsData: _analyticsData,
                ),
              ],
            ),
    );
  }
}

class CHWOverviewTab extends StatelessWidget {
  final String chwId;
  final Map<String, dynamic> analyticsData;

  const CHWOverviewTab({
    super.key,
    required this.chwId,
    required this.analyticsData,
  });

  @override
  Widget build(BuildContext context) {
    final activityData =
        analyticsData['activity_analytics'] as Map<String, dynamic>? ?? {};
    final appointments =
        activityData['appointments'] as Map<String, dynamic>? ?? {};
    final consultations =
        activityData['consultations'] as Map<String, dynamic>? ?? {};
    final referrals = activityData['referrals'] as Map<String, dynamic>? ?? {};

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
                  'Consultations',
                  Icons.medical_services,
                  Colors.purple,
                  _getConsultationsStream(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Referrals Made',
                  Icons.send_to_mobile,
                  Colors.orange,
                  _getReferralsStream(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Performance Summary Cards
          if (analyticsData.isNotEmpty) ...[
            const Text(
              'Performance Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildPerformanceCard(
                    'Completed Appointments',
                    '${appointments['completed'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPerformanceCard(
                    'Total Consultations',
                    '${consultations['total'] ?? 0}',
                    Icons.video_call,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildPerformanceCard(
                    'Referrals Made',
                    '${referrals['total'] ?? 0}',
                    Icons.send,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPerformanceCard(
                    'Training Completed',
                    '${analyticsData['training_materials']?['completed_trainings'] ?? 0}',
                    Icons.school,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],

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

  Widget _buildPerformanceCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
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
      ),
    );
  }

  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('consultations')
          .where('chwId', isEqualTo: chwId)
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

        // Sort by createdAt client-side
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = (aData['createdAt'] as Timestamp?)?.toDate();
          final bTime = (bData['createdAt'] as Timestamp?)?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(
                    Icons.medical_services,
                    color: Colors.teal,
                  ),
                  title: Text(data['patientName'] ?? 'Unknown Patient'),
                  subtitle: Text(data['type'] ?? 'Consultation'),
                  trailing: Text(_formatDate(data['createdAt'])),
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
        .where('registeredBy', isEqualTo: chwId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getAppointmentsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('chwId', isEqualTo: chwId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getReferralsStream() {
    return FirebaseFirestore.instance
        .collection('referrals')
        .where('fromProviderId', isEqualTo: chwId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getConsultationsStream() {
    return FirebaseFirestore.instance
        .collection('consultations')
        .where('chwId', isEqualTo: chwId)
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

class CHWReportsTab extends StatelessWidget {
  final String chwId;

  const CHWReportsTab({super.key, required this.chwId});

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
            'Generate a comprehensive report of all your registered patients',
            Icons.people,
            Colors.blue,
            () => _generatePatientReport(context),
          ),

          _buildReportOption(
            context,
            'Consultation History',
            'View and export your consultation history',
            Icons.medical_services,
            Colors.green,
            () => _generateConsultationReport(context),
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
            'Training Progress Report',
            'Review your training completion and performance',
            Icons.school,
            Colors.purple,
            () => _generateTrainingReport(context),
          ),

          _buildReportOption(
            context,
            'Community Health Impact',
            'Assess your impact on community health outcomes',
            Icons.health_and_safety,
            Colors.teal,
            () => _generateImpactReport(context),
          ),

          const SizedBox(height: 32),

          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Export Patient List',
                  Icons.download,
                  Colors.indigo,
                  () => _exportPatientList(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  'Monthly Summary',
                  Icons.calendar_month,
                  Colors.green,
                  () => _generateMonthlySummary(context),
                ),
              ),
            ],
          ),
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

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generatePatientReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientSummaryReportScreen(chwId: chwId),
      ),
    );
  }

  void _generateConsultationReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsultationHistoryReportScreen(chwId: chwId),
      ),
    );
  }

  void _generateReferralReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReferralAnalyticsReportScreen(chwId: chwId),
      ),
    );
  }

  void _generateTrainingReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingProgressReportScreen(chwId: chwId),
      ),
    );
  }

  void _generateImpactReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommunityImpactReportScreen(chwId: chwId),
      ),
    );
  }

  void _exportPatientList(BuildContext context) {
    _showExportDialog(context);
  }

  void _generateMonthlySummary(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MonthlyDataScreen(chwId: chwId)),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Patient List'),
        content: const Text('Choose export format:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportPatientsAsCSV(context);
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportPatientsAsPDF(context);
            },
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportPatientsAsCSV(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting patients as CSV...')),
    );
    // TODO: Implement CSV export functionality
  }

  void _exportPatientsAsPDF(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting patients as PDF...')),
    );
    // TODO: Implement PDF export functionality
  }
}

class CHWAnalyticsTab extends StatelessWidget {
  final String chwId;
  final Map<String, dynamic> analyticsData;

  const CHWAnalyticsTab({
    super.key,
    required this.chwId,
    required this.analyticsData,
  });

  @override
  Widget build(BuildContext context) {
    final performanceData =
        analyticsData['performance_metrics'] as Map<String, dynamic>? ?? {};
    final trainingData =
        analyticsData['training_materials'] as Map<String, dynamic>? ?? {};

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

          _buildPerformanceMetrics(performanceData),

          const SizedBox(height: 32),

          const Text(
            'Training Progress',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildTrainingProgress(trainingData),

          const SizedBox(height: 32),

          const Text(
            'Community Impact',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildCommunityImpact(),

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

  Widget _buildPerformanceMetrics(Map<String, dynamic> performanceData) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Performance Score',
                '${(performanceData['performance_score'] ?? 85.0).toStringAsFixed(1)}%',
                Icons.score,
                Colors.green,
                'Based on patient feedback',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Monthly Activities',
                '${performanceData['this_month_activities'] ?? 0}',
                Icons.calendar_month,
                Colors.blue,
                '${performanceData['activity_trend_percentage'] ?? 0 >= 0 ? '+' : ''}${(performanceData['activity_trend_percentage'] ?? 0).toStringAsFixed(1)}% from last month',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Response Time',
                '18 min',
                Icons.schedule,
                Colors.purple,
                'Average response time',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Patient Satisfaction',
                '4.7/5.0',
                Icons.thumb_up,
                Colors.orange,
                'Based on 25 reviews',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrainingProgress(Map<String, dynamic> trainingData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildTrainingCard(
                    'Videos Watched',
                    '${trainingData['videos_watched'] ?? 0}',
                    Icons.play_circle,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTrainingCard(
                    'Materials Read',
                    '${trainingData['materials_read'] ?? 0}',
                    Icons.description,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTrainingCard(
                    'Completed Courses',
                    '${trainingData['completed_trainings'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTrainingCard(
                    'Study Time',
                    '${(trainingData['total_training_time_minutes'] ?? 0).toInt()} min',
                    Icons.access_time,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityImpact() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Community Health Metrics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildImpactCard(
                    'People Reached',
                    '127',
                    Icons.people_outline,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImpactCard(
                    'Health Screenings',
                    '45',
                    Icons.health_and_safety,
                    Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildImpactCard(
                    'Referrals Success',
                    '89%',
                    Icons.check,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildImpactCard(
                    'Follow-ups',
                    '32',
                    Icons.follow_the_signs,
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

  Widget _buildInsightsSection() {
    return Column(
      children: [
        _buildInsightCard(
          'Peak Activity Hours',
          'Your busiest consultation hours are between 10 AM - 2 PM',
          Icons.schedule,
          Colors.blue,
        ),
        _buildInsightCard(
          'Common Health Issues',
          'Hypertension and diabetes screening are most requested',
          Icons.health_and_safety,
          Colors.green,
        ),
        _buildInsightCard(
          'Training Recommendation',
          'Consider maternal health course to expand your expertise',
          Icons.school,
          Colors.purple,
        ),
        _buildInsightCard(
          'Community Feedback',
          'Patients appreciate your follow-up care and availability',
          Icons.feedback,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
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
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingCard(
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
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactCard(
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
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

// Patient Summary Report Screen
class PatientSummaryReportScreen extends StatefulWidget {
  final String chwId;

  const PatientSummaryReportScreen({super.key, required this.chwId});

  @override
  State<PatientSummaryReportScreen> createState() =>
      _PatientSummaryReportScreenState();
}

class _PatientSummaryReportScreenState
    extends State<PatientSummaryReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _patients = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('registeredBy', isEqualTo: widget.chwId)
          .get();

      setState(() {
        _patients = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading patients: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Summary Report'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareReport),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  const Text(
                    'Patient List',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPatientsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards() {
    final totalPatients = _patients.length;
    final malePatients = _patients
        .where((p) => p['gender']?.toString().toLowerCase() == 'male')
        .length;
    final femalePatients = _patients
        .where((p) => p['gender']?.toString().toLowerCase() == 'female')
        .length;
    final activePatients = _patients
        .where((p) => p['status']?.toString().toLowerCase() == 'active')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Patients',
                totalPatients.toString(),
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Active Patients',
                activePatients.toString(),
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Male Patients',
                malePatients.toString(),
                Colors.indigo,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Female Patients',
                femalePatients.toString(),
                Colors.pink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    if (_patients.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No patients registered yet')),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _patients.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final patient = _patients[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text((patient['name'] ?? 'Unknown')[0].toUpperCase()),
            ),
            title: Text(patient['name'] ?? 'Unknown'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age: ${patient['age'] ?? 'N/A'} | Gender: ${patient['gender'] ?? 'N/A'}',
                ),
                Text('Phone: ${patient['phone'] ?? 'N/A'}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: patient['status']?.toString().toLowerCase() == 'active'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                patient['status'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  color: patient['status']?.toString().toLowerCase() == 'active'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _shareReport() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }
}

// Consultation History Report Screen
class ConsultationHistoryReportScreen extends StatefulWidget {
  final String chwId;

  const ConsultationHistoryReportScreen({super.key, required this.chwId});

  @override
  State<ConsultationHistoryReportScreen> createState() =>
      _ConsultationHistoryReportScreenState();
}

class _ConsultationHistoryReportScreenState
    extends State<ConsultationHistoryReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _consultations = [];

  @override
  void initState() {
    super.initState();
    _loadConsultations();
  }

  Future<void> _loadConsultations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where('chwId', isEqualTo: widget.chwId)
          .get();

      setState(() {
        _consultations = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // Sort by createdAt client-side
        _consultations.sort((a, b) {
          final aTime = (a['createdAt'] as Timestamp?)?.toDate();
          final bTime = (b['createdAt'] as Timestamp?)?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading consultations: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConsultationStats(),
                  const SizedBox(height: 24),
                  const Text(
                    'Consultation History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildConsultationsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildConsultationStats() {
    final totalConsultations = _consultations.length;
    final completedConsultations = _consultations
        .where((c) => c['status'] == 'completed')
        .length;
    final videoConsultations = _consultations
        .where((c) => c['type'] == 'video')
        .length;
    final chatConsultations = _consultations
        .where((c) => c['type'] == 'chat')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Consultation Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                totalConsultations.toString(),
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Completed',
                completedConsultations.toString(),
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Video Calls',
                videoConsultations.toString(),
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Chat Sessions',
                chatConsultations.toString(),
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationsList() {
    if (_consultations.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No consultations recorded yet')),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _consultations.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final consultation = _consultations[index];
          return ListTile(
            leading: Icon(
              consultation['type'] == 'video' ? Icons.video_call : Icons.chat,
              color: Colors.teal,
            ),
            title: Text(consultation['patientName'] ?? 'Unknown Patient'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type: ${consultation['type']?.toUpperCase() ?? 'Unknown'}',
                ),
                Text('Date: ${_formatDate(consultation['createdAt'])}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(consultation['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                consultation['status']?.toUpperCase() ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(consultation['status']),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
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

    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Referral Analytics Report Screen
class ReferralAnalyticsReportScreen extends StatefulWidget {
  final String chwId;

  const ReferralAnalyticsReportScreen({super.key, required this.chwId});

  @override
  State<ReferralAnalyticsReportScreen> createState() =>
      _ReferralAnalyticsReportScreenState();
}

class _ReferralAnalyticsReportScreenState
    extends State<ReferralAnalyticsReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _referrals = [];

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .where('fromProviderId', isEqualTo: widget.chwId)
          .get();

      setState(() {
        _referrals = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // Sort by createdAt client-side
        _referrals.sort((a, b) {
          final aTime = (a['createdAt'] as Timestamp?)?.toDate();
          final bTime = (b['createdAt'] as Timestamp?)?.toDate();

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading referrals: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Analytics'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReferralStats(),
                  const SizedBox(height: 24),
                  const Text(
                    'Referral History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildReferralsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildReferralStats() {
    final totalReferrals = _referrals.length;
    final completedReferrals = _referrals
        .where((r) => r['status'] == 'completed')
        .length;
    final pendingReferrals = _referrals
        .where((r) => r['status'] == 'pending')
        .length;
    final successRate = totalReferrals > 0
        ? (completedReferrals / totalReferrals * 100).round()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Referral Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                totalReferrals.toString(),
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Success Rate',
                '$successRate%',
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pending',
                pendingReferrals.toString(),
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Completed',
                completedReferrals.toString(),
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralsList() {
    if (_referrals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No referrals made yet')),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _referrals.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final referral = _referrals[index];
          return ListTile(
            leading: const Icon(Icons.send, color: Colors.orange),
            title: Text(referral['patientName'] ?? 'Unknown Patient'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('To: ${referral['facilityName'] ?? 'Unknown Facility'}'),
                Text('Reason: ${referral['reason'] ?? 'Not specified'}'),
                Text('Date: ${_formatDate(referral['createdAt'])}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(referral['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                referral['status']?.toUpperCase() ?? 'Unknown',
                style: TextStyle(
                  fontSize: 12,
                  color: _getStatusColor(referral['status']),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
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

// Training Progress Report Screen
class TrainingProgressReportScreen extends StatefulWidget {
  final String chwId;

  const TrainingProgressReportScreen({super.key, required this.chwId});

  @override
  State<TrainingProgressReportScreen> createState() =>
      _TrainingProgressReportScreenState();
}

class _TrainingProgressReportScreenState
    extends State<TrainingProgressReportScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trainingMaterials = [];
  Map<String, dynamic> _trainingStats = {};

  @override
  void initState() {
    super.initState();
    _loadTrainingData();
  }

  Future<void> _loadTrainingData() async {
    try {
      // Load training materials and user interactions
      final materialsSnapshot = await FirebaseFirestore.instance
          .collection('training_materials')
          .get();

      final userInteractionsSnapshot = await FirebaseFirestore.instance
          .collection('user_training_interactions')
          .where('userId', isEqualTo: widget.chwId)
          .get();

      final interactions = <String, Map<String, dynamic>>{};
      for (final doc in userInteractionsSnapshot.docs) {
        final data = doc.data();
        interactions[data['materialId']] = data;
      }

      final materialsWithProgress = materialsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['userInteraction'] = interactions[doc.id];
        return data;
      }).toList();

      // Calculate stats
      final totalMaterials = materialsWithProgress.length;
      final completedMaterials = materialsWithProgress
          .where((m) => m['userInteraction']?['completed'] == true)
          .length;
      final videosWatched = materialsWithProgress
          .where(
            (m) =>
                m['type'] == 'video' &&
                m['userInteraction']?['completed'] == true,
          )
          .length;
      final documentsRead = materialsWithProgress
          .where(
            (m) =>
                m['type'] == 'document' &&
                m['userInteraction']?['completed'] == true,
          )
          .length;

      setState(() {
        _trainingMaterials = materialsWithProgress;
        _trainingStats = {
          'total': totalMaterials,
          'completed': completedMaterials,
          'videos_watched': videosWatched,
          'documents_read': documentsRead,
          'completion_rate': totalMaterials > 0
              ? (completedMaterials / totalMaterials * 100).round()
              : 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading training data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Progress'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrainingStats(),
                  const SizedBox(height: 24),
                  const Text(
                    'Training Materials',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTrainingMaterialsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildTrainingStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Training Statistics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completion Rate',
                '${_trainingStats['completion_rate']}%',
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Completed',
                '${_trainingStats['completed']}',
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Videos Watched',
                '${_trainingStats['videos_watched']}',
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Documents Read',
                '${_trainingStats['documents_read']}',
                Colors.indigo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingMaterialsList() {
    if (_trainingMaterials.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No training materials available')),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _trainingMaterials.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final material = _trainingMaterials[index];
          final interaction =
              material['userInteraction'] as Map<String, dynamic>?;
          final isCompleted = interaction?['completed'] == true;

          return ListTile(
            leading: Icon(
              material['type'] == 'video'
                  ? Icons.play_circle
                  : Icons.description,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
            title: Text(material['title'] ?? 'Unknown Title'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${material['type']?.toUpperCase() ?? 'Unknown'}'),
                if (interaction != null && interaction['last_accessed'] != null)
                  Text(
                    'Last accessed: ${_formatDate(interaction['last_accessed'])}',
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted ? 'COMPLETED' : 'PENDING',
                style: TextStyle(
                  fontSize: 12,
                  color: isCompleted ? Colors.green : Colors.orange,
                ),
              ),
            ),
          );
        },
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

// Community Impact Report Screen
class CommunityImpactReportScreen extends StatefulWidget {
  final String chwId;

  const CommunityImpactReportScreen({super.key, required this.chwId});

  @override
  State<CommunityImpactReportScreen> createState() =>
      _CommunityImpactReportScreenState();
}

class _CommunityImpactReportScreenState
    extends State<CommunityImpactReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _impactData = {};

  @override
  void initState() {
    super.initState();
    _calculateImpactMetrics();
  }

  Future<void> _calculateImpactMetrics() async {
    try {
      // Load various data points to calculate impact
      final patientsSnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('registeredBy', isEqualTo: widget.chwId)
          .get();

      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where('chwId', isEqualTo: widget.chwId)
          .get();

      final referralsSnapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .where('fromProviderId', isEqualTo: widget.chwId)
          .get();

      // Calculate impact metrics
      final totalPatients = patientsSnapshot.docs.length;
      final totalConsultations = consultationsSnapshot.docs.length;
      final totalReferrals = referralsSnapshot.docs.length;
      final completedReferrals = referralsSnapshot.docs
          .where((doc) => doc.data()['status'] == 'completed')
          .length;

      // Calculate demographics
      final malePatients = patientsSnapshot.docs
          .where(
            (doc) => doc.data()['gender']?.toString().toLowerCase() == 'male',
          )
          .length;
      final femalePatients = patientsSnapshot.docs
          .where(
            (doc) => doc.data()['gender']?.toString().toLowerCase() == 'female',
          )
          .length;

      // Calculate age groups
      final childrenPatients = patientsSnapshot.docs.where((doc) {
        final age = int.tryParse(doc.data()['age']?.toString() ?? '0') ?? 0;
        return age < 18;
      }).length;

      final adultPatients = patientsSnapshot.docs.where((doc) {
        final age = int.tryParse(doc.data()['age']?.toString() ?? '0') ?? 0;
        return age >= 18 && age < 65;
      }).length;

      final elderlyPatients = patientsSnapshot.docs.where((doc) {
        final age = int.tryParse(doc.data()['age']?.toString() ?? '0') ?? 0;
        return age >= 65;
      }).length;

      setState(() {
        _impactData = {
          'total_patients': totalPatients,
          'total_consultations': totalConsultations,
          'total_referrals': totalReferrals,
          'completed_referrals': completedReferrals,
          'referral_success_rate': totalReferrals > 0
              ? (completedReferrals / totalReferrals * 100).round()
              : 0,
          'male_patients': malePatients,
          'female_patients': femalePatients,
          'children_patients': childrenPatients,
          'adult_patients': adultPatients,
          'elderly_patients': elderlyPatients,
          'average_consultations_per_patient': totalPatients > 0
              ? (totalConsultations / totalPatients).toStringAsFixed(1)
              : '0',
          'community_reach_score': _calculateCommunityReachScore(
            totalPatients,
            totalConsultations,
            completedReferrals,
          ),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error calculating impact: $e')));
      }
    }
  }

  int _calculateCommunityReachScore(
    int patients,
    int consultations,
    int referrals,
  ) {
    // Simple scoring algorithm
    int score = 0;
    score += (patients * 10).clamp(0, 300);
    score += (consultations * 5).clamp(0, 200);
    score += (referrals * 15).clamp(0, 200);
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Impact Report'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImpactOverview(),
                  const SizedBox(height: 24),
                  _buildDemographicsBreakdown(),
                  const SizedBox(height: 24),
                  _buildServiceDelivery(),
                  const SizedBox(height: 24),
                  _buildImpactInsights(),
                ],
              ),
            ),
    );
  }

  Widget _buildImpactOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Community Impact Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'People Reached',
                '${_impactData['total_patients']}',
                Colors.teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Impact Score',
                '${_impactData['community_reach_score']}%',
                Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Consultations',
                '${_impactData['total_consultations']}',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Successful Referrals',
                '${_impactData['referral_success_rate']}%',
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemographicsBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Demographics Breakdown',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Gender Distribution',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDemoCard(
                        'Male',
                        '${_impactData['male_patients']}',
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDemoCard(
                        'Female',
                        '${_impactData['female_patients']}',
                        Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Age Groups',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDemoCard(
                        'Children',
                        '${_impactData['children_patients']}',
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDemoCard(
                        'Adults',
                        '${_impactData['adult_patients']}',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDemoCard(
                        'Elderly',
                        '${_impactData['elderly_patients']}',
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDelivery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Service Delivery Metrics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Avg Consultations/Patient',
                _impactData['average_consultations_per_patient'],
                Colors.indigo,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Referrals',
                '${_impactData['total_referrals']}',
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImpactInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Insights',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInsightItem(
                  'Population Reach',
                  'You have registered ${_impactData['total_patients']} patients, showing strong community engagement.',
                  Icons.people,
                  Colors.teal,
                ),
                const Divider(),
                _buildInsightItem(
                  'Healthcare Access',
                  'With ${_impactData['total_consultations']} consultations, you\'re improving healthcare accessibility.',
                  Icons.medical_services,
                  Colors.blue,
                ),
                const Divider(),
                _buildInsightItem(
                  'Referral Efficiency',
                  '${_impactData['referral_success_rate']}% referral success rate demonstrates effective care coordination.',
                  Icons.send,
                  Colors.green,
                ),
                const Divider(),
                _buildInsightItem(
                  'Community Impact',
                  'Your impact score of ${_impactData['community_reach_score']}% reflects significant positive community health outcomes.',
                  Icons.health_and_safety,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInsightItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Monthly Summary Screen
class MonthlyDataScreen extends StatefulWidget {
  final String chwId;

  const MonthlyDataScreen({super.key, required this.chwId});

  @override
  State<MonthlyDataScreen> createState() => _MonthlyDataScreenState();
}

class _MonthlyDataScreenState extends State<MonthlyDataScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _monthlyData = {};
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    setState(() => _isLoading = true);

    try {
      final startOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      );

      // Load data for the selected month
      final patientsSnapshot = await FirebaseFirestore.instance
          .collection('patients')
          .where('registeredBy', isEqualTo: widget.chwId)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          )
          .get();

      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where('chwId', isEqualTo: widget.chwId)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'createdAt',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          )
          .get();

      setState(() {
        _monthlyData = {
          'new_patients': patientsSnapshot.docs.length,
          'consultations': consultationsSnapshot.docs.length,
          'month_name': _getMonthName(_selectedMonth.month),
          'year': _selectedMonth.year,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading monthly data: $e')),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectMonth,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary for ${_monthlyData['month_name']} ${_monthlyData['year']}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'New Patients',
                          '${_monthlyData['new_patients']}',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Consultations',
                          '${_monthlyData['consultations']}',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Performance Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Performance for ${_monthlyData['month_name']} ${_monthlyData['year']}',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Registered ${_monthlyData['new_patients']} new patients',
                          ),
                          Text(
                            '• Conducted ${_monthlyData['consultations']} consultations',
                          ),
                          const SizedBox(height: 12),
                          if (_monthlyData['new_patients'] > 0 ||
                              _monthlyData['consultations'] > 0)
                            const Text(
                              'Great work! You\'ve been actively serving your community this month.',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            const Text(
                              'Consider increasing your community outreach activities.',
                              style: TextStyle(color: Colors.orange),
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Month',
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
      });
      _loadMonthlyData();
    }
  }
}
