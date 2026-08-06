// ignore_for_file: prefer_const_constructors, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../shared/data/services/user_analytics_service.dart';
import '../../../shared/presentation/widgets/charts/analytics_charts.dart';

class PatientAnalyticsScreen extends StatefulWidget {
  const PatientAnalyticsScreen({super.key});

  @override
  State<PatientAnalyticsScreen> createState() => _PatientAnalyticsScreenState();
}

class _PatientAnalyticsScreenState extends State<PatientAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;
  String? _userId;
  Map<String, dynamic>? _latestVitals;
  List<Map<String, dynamic>> _healthRecords = [];
  List<Map<String, dynamic>> _vitalsTrends = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Starting to load analytics for user: $_userId');

      // Load Overview analytics
      final analytics =
          await UserAnalyticsService.getUserAnalytics(
            userId: _userId!,
            role: 'patient',
          ).timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('⚠️ Analytics loading timed out after 10 seconds');
              // Return minimal data structure
              return {
                'activity_analytics': {
                  'appointments': {'total': 0, 'completed': 0, 'cancelled': 0},
                  'referrals': {'total': 0, 'completed': 0},
                  'education': {
                    'health_tips_read': 0,
                    'educational_videos_watched': 0,
                  },
                },
                'performance_metrics': {
                  'activity_trend_percentage': 0.0,
                  'performance_score': 0.0,
                  'this_month_activities': 0,
                  'last_month_activities': 0,
                },
                'training_materials': {
                  'videos_watched': 0,
                  'materials_read': 0,
                  'materials_downloaded': 0,
                  'completed_trainings': 0,
                  'total_training_time_minutes': 0.0,
                  'progress_details': [],
                },
              };
            },
          );

      print('Analytics loaded successfully: ${analytics.keys}');

      // Load Health Records data for other tabs
      await _loadHealthRecords();
      await _loadLatestVitals();
      await _loadVitalsTrends();

      // Check if timeout occurred
      if (analytics['error'] == 'timeout') {
        throw Exception('Loading analytics timed out. Please try again.');
      }

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading analytics: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load analytics. Using default view.'),
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: _loadAnalyticsData,
            ),
          ),
        );
      }
    }
  }

  /// Load health records for timeline (Health Journey tab)
  Future<void> _loadHealthRecords() async {
    try {
      final query = FirebaseFirestore.instance
          .collection('health_records')
          .where('userId', isEqualTo: _userId)
          .orderBy('timestamp', descending: true)
          .limit(10);

      final snapshot = await query.get().timeout(Duration(seconds: 5));

      _healthRecords = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      print('Loaded ${_healthRecords.length} health records');
    } catch (e) {
      print('Error loading health records: $e');
      _healthRecords = [];
    }
  }

  /// Load latest vitals for Wellness tab
  Future<void> _loadLatestVitals() async {
    try {
      final query = FirebaseFirestore.instance
          .collection('health_records')
          .where('userId', isEqualTo: _userId)
          .where('type', isEqualTo: 'vital_signs')
          .orderBy('timestamp', descending: true)
          .limit(1);

      final snapshot = await query.get().timeout(Duration(seconds: 5));

      if (snapshot.docs.isNotEmpty) {
        _latestVitals = snapshot.docs.first.data();
        print('Loaded latest vitals: ${_latestVitals?.keys}');
      } else {
        _latestVitals = null;
        print('No vitals found');
      }
    } catch (e) {
      print('Error loading latest vitals: $e');
      _latestVitals = null;
    }
  }

  /// Load vitals trends for Progress tab
  Future<void> _loadVitalsTrends() async {
    try {
      // Get vitals from last 8 weeks
      final eightWeeksAgo = DateTime.now().subtract(Duration(days: 56));

      final query = FirebaseFirestore.instance
          .collection('health_records')
          .where('userId', isEqualTo: _userId)
          .where('type', isEqualTo: 'vital_signs')
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(eightWeeksAgo),
          )
          .orderBy('timestamp', descending: false);

      final snapshot = await query.get().timeout(Duration(seconds: 5));

      _vitalsTrends = snapshot.docs.map((doc) => doc.data()).toList();
      print('Loaded ${_vitalsTrends.length} vitals trend records');
    } catch (e) {
      print('Error loading vitals trends: $e');
      _vitalsTrends = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Health Analytics'),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Health Journey', icon: Icon(Icons.timeline)),
            Tab(text: 'Wellness', icon: Icon(Icons.favorite)),
            Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHealthJourneyTab(),
                _buildWellnessTab(),
                _buildProgressTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final activityData =
        (_analyticsData['activity_analytics'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};
    final performanceData =
        (_analyticsData['performance_metrics'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};
    final trainingData =
        (_analyticsData['training_materials'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};

    return RefreshIndicator(
      onRefresh: _loadAnalyticsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            _buildWelcomeCard(),
            const SizedBox(height: 16),

            // Key Statistics
            _buildStatisticsSection(activityData, performanceData),
            const SizedBox(height: 16),

            // Health Score Card
            _buildHealthScoreCard(performanceData),
            const SizedBox(height: 16),

            // Recent Activity
            _buildRecentActivityCard(trainingData),
            const SizedBox(height: 16),

            // Quick Actions
            _buildQuickActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final userData =
        (_analyticsData['user_info'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};
    final userName = userData['fullName'] ?? userData['name'] ?? 'Patient';

    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.teal.shade400, Colors.teal.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track your health journey and wellness progress',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Last updated: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(
    Map<String, dynamic> activityData,
    Map<String, dynamic> performanceData,
  ) {
    final appointments =
        (activityData['appointments'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};
    final referrals =
        (activityData['referrals'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};
    final education =
        (activityData['education'] as Map<dynamic, dynamic>?)
            ?.cast<String, dynamic>() ??
        {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Statistics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Appointments',
                '${appointments['total'] ?? 0}',
                Icons.calendar_today,
                Colors.blue,
                subtitle: '${appointments['completed'] ?? 0} completed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Referrals',
                '${referrals['total'] ?? 0}',
                Icons.share,
                Colors.orange,
                subtitle: '${referrals['completed'] ?? 0} completed',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Health Tips',
                '${education['health_tips_read'] ?? 0}',
                Icons.lightbulb,
                Colors.green,
                subtitle: 'Tips read',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Educational Videos',
                '${education['educational_videos_watched'] ?? 0}',
                Icons.play_circle,
                Colors.purple,
                subtitle: 'Videos watched',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(Map<String, dynamic> performanceData) {
    final score = (performanceData['performance_score'] is int)
        ? (performanceData['performance_score'] as int).toDouble()
        : (performanceData['performance_score'] as double? ?? 0.0);
    final scoreColor = score >= 80
        ? Colors.green
        : score >= 60
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: scoreColor),
                const SizedBox(width: 8),
                Text(
                  'Health Engagement Score',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        _getScoreDescription(score),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Based on appointment attendance and health engagement activities',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getScoreDescription(double score) {
    if (score >= 80) return 'Excellent engagement';
    if (score >= 60) return 'Good engagement';
    if (score >= 40) return 'Fair engagement';
    return 'Needs improvement';
  }

  Widget _buildRecentActivityCard(Map<String, dynamic> trainingData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Recent Learning Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActivityMetric(
                  'Materials Read',
                  '${trainingData['materials_read'] ?? 0}',
                  Icons.book,
                  Colors.blue,
                ),
                _buildActivityMetric(
                  'Videos Watched',
                  '${trainingData['videos_watched'] ?? 0}',
                  Icons.play_circle,
                  Colors.red,
                ),
                _buildActivityMetric(
                  'Downloads',
                  '${trainingData['materials_downloaded'] ?? 0}',
                  Icons.download,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Book Appointment',
                    Icons.calendar_today,
                    Colors.blue,
                    () => _navigateToAppointments(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Health Education',
                    Icons.school,
                    Colors.orange,
                    () => _navigateToEducation(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthJourneyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Health Journey Timeline',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTimelineCard(),
          const SizedBox(height: 16),
          _buildMilestonesCard(),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Recent Health Activities',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Display real health records
            if (_healthRecords.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No health records found. Start tracking your health!',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ..._healthRecords.take(5).map((record) {
                final type = record['type']?.toString() ?? 'Unknown';
                final timestamp = record['timestamp'] as Timestamp?;
                final date = timestamp?.toDate() ?? DateTime.now();

                // Map type to display info
                String title;
                String subtitle;
                IconData icon;
                Color color;

                switch (type) {
                  case 'ANC_VISIT':
                    title = 'ANC Visit';
                    subtitle = 'Antenatal Care Visit';
                    icon = Icons.pregnant_woman;
                    color = Colors.pink;
                    break;
                  case 'DOCTOR_CONSULTATION':
                    final data = record['data'] as Map<String, dynamic>?;
                    title = 'Doctor Consultation';
                    subtitle =
                        data?['reason']?.toString() ?? 'Medical consultation';
                    icon = Icons.medical_services;
                    color = Colors.blue;
                    break;
                  case 'CHW_CONSULTATION':
                    final data = record['data'] as Map<String, dynamic>?;
                    title = 'CHW Consultation';
                    subtitle =
                        data?['diagnosis']?.toString() ??
                        'Community health worker visit';
                    icon = Icons.health_and_safety;
                    color = Colors.green;
                    break;
                  case 'SELF_REPORTED_VITALS':
                  case 'vital_signs':
                    final data = record['data'] as Map<String, dynamic>?;
                    final bmi =
                        record['bmi']?.toString() ?? data?['bmi']?.toString();
                    final bp =
                        record['bloodPressure']?.toString() ??
                        data?['bloodPressure']?.toString();
                    title = 'Vitals Recorded';
                    subtitle = bmi != null && bp != null
                        ? 'BMI: $bmi, BP: $bp'
                        : bp != null
                        ? 'BP: $bp'
                        : bmi != null
                        ? 'BMI: $bmi'
                        : 'Health vitals recorded';
                    icon = Icons.favorite;
                    color = Colors.red;
                    break;
                  case 'LAB_RESULTS':
                    title = 'Lab Results';
                    subtitle = 'Laboratory test results available';
                    icon = Icons.science;
                    color = Colors.purple;
                    break;
                  case 'PRE_CONSULTATION_CHECKLIST':
                    title = 'Pre-Consultation Checklist';
                    subtitle = 'Checklist completed';
                    icon = Icons.checklist;
                    color = Colors.orange;
                    break;
                  default:
                    title = type.replaceAll('_', ' ');
                    subtitle = 'Health record';
                    icon = Icons.description;
                    color = Colors.grey;
                }

                return _buildTimelineItem(title, subtitle, date, icon, color);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String subtitle,
    DateTime date,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM dd').format(date),
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesCard() {
    // Calculate milestones based on real data
    final hasVitals = _latestVitals != null;
    final hasMultipleRecords = _healthRecords.length >= 3;
    final hasConsultation = _healthRecords.any(
      (r) =>
          r['type'] == 'DOCTOR_CONSULTATION' || r['type'] == 'CHW_CONSULTATION',
    );
    final hasRecentActivity = _healthRecords.any((r) {
      final timestamp = r['timestamp'] as Timestamp?;
      if (timestamp == null) return false;
      final date = timestamp.toDate();
      return DateTime.now().difference(date).inDays <= 30;
    });

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Health Milestones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMilestoneItem(
              'Started Health Tracking',
              _healthRecords.isNotEmpty,
            ),
            _buildMilestoneItem('Recorded Vital Signs', hasVitals),
            _buildMilestoneItem('Had Medical Consultation', hasConsultation),
            _buildMilestoneItem(
              'Active Health Management (${_healthRecords.length} records)',
              hasMultipleRecords,
            ),
            _buildMilestoneItem('Recent Health Activity', hasRecentActivity),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem(String title, bool completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: completed ? Colors.black87 : Colors.grey[600],
                decoration: completed ? null : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWellnessTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wellness Tracking',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildWellnessMetricsCard(),
          const SizedBox(height: 16),
          _buildHealthDistributionChart(),
          const SizedBox(height: 16),
          _buildHealthHabitsCard(),
        ],
      ),
    );
  }

  Widget _buildWellnessMetricsCard() {
    // Extract real vitals data or use defaults
    final bmi = _latestVitals?['bmi']?.toString() ?? '--';
    final bmiInterpretation =
        _latestVitals?['bmiInterpretation']?.toString() ?? 'No data';
    final bloodPressure =
        _latestVitals?['bloodPressure']?.toString() ?? '--/--';
    final heartRate = _latestVitals?['heartRate']?.toString() ?? '--';
    final temperature = _latestVitals?['temperature']?.toString() ?? '--';

    // Determine BMI status color
    Color bmiColor = Colors.grey;
    if (bmiInterpretation.contains('Normal')) {
      bmiColor = Colors.green;
    } else if (bmiInterpretation.contains('Underweight') ||
        bmiInterpretation.contains('Overweight')) {
      bmiColor = Colors.orange;
    } else if (bmiInterpretation.contains('Obese')) {
      bmiColor = Colors.red;
    }

    // Determine BP status
    String bpStatus = 'No data';
    Color bpColor = Colors.grey;
    if (bloodPressure != '--/--') {
      final parts = bloodPressure.split('/');
      if (parts.length == 2) {
        final systolic = int.tryParse(parts[0]) ?? 0;
        final diastolic = int.tryParse(parts[1]) ?? 0;
        if (systolic >= 90 &&
            systolic <= 120 &&
            diastolic >= 60 &&
            diastolic <= 80) {
          bpStatus = 'Good';
          bpColor = Colors.green;
        } else if (systolic > 120 && systolic <= 140 ||
            diastolic > 80 && diastolic <= 90) {
          bpStatus = 'Elevated';
          bpColor = Colors.orange;
        } else {
          bpStatus = 'High';
          bpColor = Colors.red;
        }
      }
    }

    // Determine heart rate status
    String hrStatus = 'No data';
    Color hrColor = Colors.grey;
    if (heartRate != '--') {
      final hr = int.tryParse(heartRate) ?? 0;
      if (hr >= 60 && hr <= 100) {
        hrStatus = 'Normal';
        hrColor = Colors.green;
      } else if (hr > 100 && hr <= 120) {
        hrStatus = 'Elevated';
        hrColor = Colors.orange;
      } else if (hr > 0) {
        hrStatus = 'Abnormal';
        hrColor = Colors.red;
      }
    }

    // Temperature status
    String tempStatus = 'No data';
    Color tempColor = Colors.grey;
    if (temperature != '--') {
      final temp = double.tryParse(temperature) ?? 0;
      if (temp >= 36.0 && temp <= 37.5) {
        tempStatus = 'Normal';
        tempColor = Colors.green;
      } else if (temp > 37.5 && temp <= 38.0) {
        tempStatus = 'Elevated';
        tempColor = Colors.orange;
      } else if (temp > 0) {
        tempStatus = 'Abnormal';
        tempColor = Colors.red;
      }
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Wellness Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'BMI',
                    bmi,
                    bmiInterpretation,
                    bmiColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Blood Pressure',
                    bloodPressure,
                    bpStatus,
                    bpColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Heart Rate',
                    '$heartRate bpm',
                    hrStatus,
                    hrColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    'Temperature',
                    '$temperature °C',
                    tempStatus,
                    tempColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    String status,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthDistributionChart() {
    // Sample data for health activities distribution
    final healthData = calculateDonutData({
      'Exercise': 25,
      'Medication': 30,
      'Sleep': 20,
      'Nutrition': 15,
      'Checkups': 10,
    }, ChartColors.pastel);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Activities Distribution',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    size: const Size(120, 120),
                    painter: DonutChartPainter(
                      data: healthData,
                      centerText: '85',
                      centerSubtext: 'Score',
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: healthData
                        .map(
                          (item) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.label} ${item.percentage.toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthHabitsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'Health Habits Tracking',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHabitProgress('Daily Water Intake', 0.8, '8/10 glasses'),
            _buildHabitProgress('Exercise', 0.6, '3/5 days this week'),
            _buildHabitProgress('Medication Adherence', 0.95, '19/20 doses'),
            _buildHabitProgress('Sleep Schedule', 0.7, 'Mostly consistent'),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitProgress(String habit, double progress, String details) {
    final color = progress >= 0.8
        ? Colors.green
        : progress >= 0.6
        ? Colors.orange
        : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(habit, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                details,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Tracking',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildProgressChartCard(),
          const SizedBox(height: 16),
          _buildGoalsCard(),
        ],
      ),
    );
  }

  Widget _buildProgressChartCard() {
    // Generate chart data from real vitals trends
    List<ChartDataPoint> chartData = [];

    if (_vitalsTrends.isNotEmpty) {
      // Group by week and calculate average BMI or weight
      final now = DateTime.now();
      final weeksData = <int, List<double>>{};

      for (var record in _vitalsTrends) {
        final timestamp = record['timestamp'] as Timestamp?;
        if (timestamp == null) continue;

        final date = timestamp.toDate();
        final weeksDiff = now.difference(date).inDays ~/ 7;
        final weekIndex = 8 - weeksDiff; // Reverse so week 1 is oldest

        if (weekIndex >= 1 && weekIndex <= 8) {
          // Try to get BMI, fallback to weight
          final bmiStr = record['bmi']?.toString();
          final weightStr = record['weight']?.toString();

          double? value;
          if (bmiStr != null) {
            value = double.tryParse(bmiStr);
          } else if (weightStr != null) {
            value = double.tryParse(weightStr);
          }

          if (value != null && value > 0) {
            weeksData.putIfAbsent(weekIndex, () => []);
            weeksData[weekIndex]!.add(value);
          }
        }
      }

      // Calculate averages and create chart points
      weeksData.forEach((weekIndex, values) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        chartData.add(
          ChartDataPoint(
            x: weekIndex.toDouble(),
            y: avg,
            label: 'Week $weekIndex',
          ),
        );
      });

      // Sort by week
      chartData.sort((a, b) => a.x.compareTo(b.x));
    }

    // If no real data, show placeholder message
    if (chartData.isEmpty) {
      chartData = [
        ChartDataPoint(x: 1, y: 0, label: 'Week 1'),
        ChartDataPoint(x: 2, y: 0, label: 'Week 2'),
      ];
    }

    final hasRealData = _vitalsTrends.isNotEmpty;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: hasRealData ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasRealData
                        ? 'Health Metrics Trend'
                        : 'Health Metrics Trend (No Data)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasRealData)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Start tracking your vitals to see your progress over time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            AnalyticsLineChart(
              data: chartData,
              title: '',
              primaryColor: hasRealData ? Colors.teal : Colors.grey,
              height: 200,
              xAxisLabel: 'Weekly Progress',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsCard() {
    // Calculate goals based on real data
    final totalRecords = _healthRecords.length;
    final vitalsRecorded = _healthRecords
        .where(
          (r) =>
              r['type'] == 'vital_signs' || r['type'] == 'SELF_REPORTED_VITALS',
        )
        .length;
    final consultations = _healthRecords
        .where(
          (r) =>
              r['type'] == 'DOCTOR_CONSULTATION' ||
              r['type'] == 'CHW_CONSULTATION',
        )
        .length;

    // Weekly vitals goal (aim for 1 per week)
    final weeksWithVitals = _vitalsTrends.isNotEmpty
        ? (_vitalsTrends.length / 7).ceil().clamp(0, 4)
        : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Health Goals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGoalItem(
              'Start Health Tracking',
              totalRecords > 0 ? 1 : 0,
              1,
            ),
            _buildGoalItem('Record Vital Signs Regularly', vitalsRecorded, 5),
            _buildGoalItem('Have Medical Consultations', consultations, 3),
            _buildGoalItem('Maintain Weekly Health Check', weeksWithVitals, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalItem(String title, int current, int target) {
    final progress = current / target;
    final isCompleted = current >= target;
    final color = isCompleted ? Colors.green : Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Row(
                children: [
                  if (isCompleted)
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$current/$target',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  void _navigateToAppointments() {
    Navigator.pop(context);
    // Navigate to appointments - this would be handled by the parent navigation
  }

  void _navigateToEducation() {
    Navigator.pop(context);
    // Navigate to education - this would be handled by the parent navigation
  }
}
