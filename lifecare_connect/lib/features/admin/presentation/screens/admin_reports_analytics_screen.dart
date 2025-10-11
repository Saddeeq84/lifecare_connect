// ignore_for_file: avoid_print, use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminReportsAnalyticsScreen extends StatefulWidget {
  const AdminReportsAnalyticsScreen({super.key});

  @override
  State<AdminReportsAnalyticsScreen> createState() =>
      _AdminReportsAnalyticsScreenState();
}

class _AdminReportsAnalyticsScreenState
    extends State<AdminReportsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;

  // Analytics Data
  Map<String, int> userStats = {};
  Map<String, int> appointmentStats = {};
  Map<String, int> referralStats = {};
  Map<String, int> messageStats = {};
  Map<String, int> facilityStats = {};
  Map<String, int> consultationStats = {};
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> systemPerformance = [];

  // Date Range Selection
  DateTime selectedStartDate = DateTime.now().subtract(
    const Duration(days: 30),
  );
  DateTime selectedEndDate = DateTime.now();

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
    setState(() => isLoading = true);

    try {
      await Future.wait([
        _loadUserStatistics(),
        _loadAppointmentStatistics(),
        _loadReferralStatistics(),
        _loadMessageStatistics(),
        _loadFacilityStatistics(),
        _loadConsultationStatistics(),
        _loadRecentActivities(),
        _loadSystemPerformance(),
      ]);
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadUserStatistics() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      Map<String, int> stats = {
        'total': usersSnapshot.docs.length,
        'doctors': 0,
        'chw': 0,
        'patients': 0,
        'admin': 0,
        'facility': 0,
        'active_today': 0,
        'new_this_month': 0,
      };

      final today = DateTime.now();
      final startOfMonth = DateTime(today.year, today.month, 1);
      final startOfDay = DateTime(today.year, today.month, today.day);

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final role = data['role']?.toString().toLowerCase() ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final lastActive = (data['lastActive'] as Timestamp?)?.toDate();

        // Count by role
        if (role == 'doctor')
          stats['doctors'] = stats['doctors']! + 1;
        else if (role == 'chw')
          stats['chw'] = stats['chw']! + 1;
        else if (role == 'patient')
          stats['patients'] = stats['patients']! + 1;
        else if (role == 'admin')
          stats['admin'] = stats['admin']! + 1;
        else if (role == 'facility')
          stats['facility'] = stats['facility']! + 1;

        // Count new users this month
        if (createdAt != null && createdAt.isAfter(startOfMonth)) {
          stats['new_this_month'] = stats['new_this_month']! + 1;
        }

        // Count active users today
        if (lastActive != null && lastActive.isAfter(startOfDay)) {
          stats['active_today'] = stats['active_today']! + 1;
        }
      }

      setState(() => userStats = stats);
    } catch (e) {
      print('Error loading user statistics: $e');
    }
  }

  Future<void> _loadAppointmentStatistics() async {
    try {
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(selectedStartDate),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(selectedEndDate))
          .get();

      Map<String, int> stats = {
        'total': appointmentsSnapshot.docs.length,
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
        'today': 0,
      };

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? '';
        final appointmentDate = (data['appointmentDate'] as Timestamp?)
            ?.toDate();

        // Count by status
        if (status == 'pending')
          stats['pending'] = stats['pending']! + 1;
        else if (status == 'confirmed')
          stats['confirmed'] = stats['confirmed']! + 1;
        else if (status == 'completed')
          stats['completed'] = stats['completed']! + 1;
        else if (status == 'cancelled')
          stats['cancelled'] = stats['cancelled']! + 1;

        // Count appointments today
        if (appointmentDate != null &&
            appointmentDate.isAfter(startOfDay) &&
            appointmentDate.isBefore(endOfDay)) {
          stats['today'] = stats['today']! + 1;
        }
      }

      setState(() => appointmentStats = stats);
    } catch (e) {
      print('Error loading appointment statistics: $e');
    }
  }

  Future<void> _loadReferralStatistics() async {
    try {
      final referralsSnapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(selectedStartDate),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(selectedEndDate))
          .get();

      Map<String, int> stats = {
        'total': referralsSnapshot.docs.length,
        'pending': 0,
        'accepted': 0,
        'completed': 0,
        'rejected': 0,
      };

      for (var doc in referralsSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? '';

        if (status == 'pending')
          stats['pending'] = stats['pending']! + 1;
        else if (status == 'accepted')
          stats['accepted'] = stats['accepted']! + 1;
        else if (status == 'completed')
          stats['completed'] = stats['completed']! + 1;
        else if (status == 'rejected')
          stats['rejected'] = stats['rejected']! + 1;
      }

      setState(() => referralStats = stats);
    } catch (e) {
      print('Error loading referral statistics: $e');
    }
  }

  Future<void> _loadMessageStatistics() async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('messages')
          .where(
            'timestamp',
            isGreaterThan: Timestamp.fromDate(selectedStartDate),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(selectedEndDate))
          .get();

      Map<String, int> stats = {
        'total': messagesSnapshot.docs.length,
        'broadcast': 0,
        'direct': 0,
        'group': 0,
        'today': 0,
      };

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString().toLowerCase() ?? '';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

        if (type == 'broadcast')
          stats['broadcast'] = stats['broadcast']! + 1;
        else if (type == 'direct')
          stats['direct'] = stats['direct']! + 1;
        else if (type == 'group')
          stats['group'] = stats['group']! + 1;

        if (timestamp != null && timestamp.isAfter(startOfDay)) {
          stats['today'] = stats['today']! + 1;
        }
      }

      setState(() => messageStats = stats);
    } catch (e) {
      print('Error loading message statistics: $e');
    }
  }

  Future<void> _loadFacilityStatistics() async {
    try {
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('healthFacilities')
          .get();

      Map<String, int> stats = {
        'total': facilitiesSnapshot.docs.length,
        'hospitals': 0,
        'clinics': 0,
        'laboratories': 0,
        'pharmacies': 0,
        'others': 0,
      };

      for (var doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString().toLowerCase() ?? '';

        if (type.contains('hospital'))
          stats['hospitals'] = stats['hospitals']! + 1;
        else if (type.contains('clinic'))
          stats['clinics'] = stats['clinics']! + 1;
        else if (type.contains('laboratory') || type.contains('lab'))
          stats['laboratories'] = stats['laboratories']! + 1;
        else if (type.contains('pharmacy'))
          stats['pharmacies'] = stats['pharmacies']! + 1;
        else
          stats['others'] = stats['others']! + 1;
      }

      setState(() => facilityStats = stats);
    } catch (e) {
      print('Error loading facility statistics: $e');
    }
  }

  Future<void> _loadConsultationStatistics() async {
    try {
      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(selectedStartDate),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(selectedEndDate))
          .get();

      Map<String, int> stats = {
        'total': consultationsSnapshot.docs.length,
        'video': 0,
        'chat': 0,
        'completed': 0,
        'ongoing': 0,
      };

      for (var doc in consultationsSnapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString().toLowerCase() ?? '';
        final status = data['status']?.toString().toLowerCase() ?? '';

        if (type == 'video')
          stats['video'] = stats['video']! + 1;
        else if (type == 'chat')
          stats['chat'] = stats['chat']! + 1;

        if (status == 'completed')
          stats['completed'] = stats['completed']! + 1;
        else if (status == 'ongoing')
          stats['ongoing'] = stats['ongoing']! + 1;
      }

      setState(() => consultationStats = stats);
    } catch (e) {
      print('Error loading consultation statistics: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Load recent appointments
      final recentAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      for (var doc in recentAppointments.docs) {
        final data = doc.data();
        activities.add({
          'type': 'appointment',
          'title': 'New Appointment',
          'description':
              'Appointment scheduled with ${data['doctorName'] ?? 'Doctor'}',
          'timestamp': data['createdAt'],
          'status': data['status'],
          'icon': Icons.calendar_today,
        });
      }

      // Load recent referrals
      final recentReferrals = await FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in recentReferrals.docs) {
        final data = doc.data();
        activities.add({
          'type': 'referral',
          'title': 'New Referral',
          'description': 'Referral to ${data['facilityName'] ?? 'Facility'}',
          'timestamp': data['createdAt'],
          'status': data['status'],
          'icon': Icons.send,
        });
      }

      // Load recent user registrations
      final recentUsers = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in recentUsers.docs) {
        final data = doc.data();
        activities.add({
          'type': 'user',
          'title': 'New User Registration',
          'description':
              '${data['role']?.toString().toUpperCase() ?? 'User'}: ${data['name'] ?? 'Unknown'}',
          'timestamp': data['createdAt'],
          'status': 'active',
          'icon': Icons.person_add,
        });
      }

      // Sort activities by timestamp
      activities.sort((a, b) {
        final aTime =
            (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime =
            (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      setState(() => recentActivities = activities.take(15).toList());
    } catch (e) {
      print('Error loading recent activities: $e');
    }
  }

  Future<void> _loadSystemPerformance() async {
    try {
      final performance = <Map<String, dynamic>>[];

      // Calculate daily statistics for the last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Count daily activities
        final appointmentsCount = await FirebaseFirestore.instance
            .collection('appointments')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
            .get()
            .then((snapshot) => snapshot.docs.length);

        final messagesCount = await FirebaseFirestore.instance
            .collection('messages')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
            .get()
            .then((snapshot) => snapshot.docs.length);

        final referralsCount = await FirebaseFirestore.instance
            .collection('referrals')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
            .get()
            .then((snapshot) => snapshot.docs.length);

        performance.add({
          'date': DateFormat('MMM dd').format(date),
          'appointments': appointmentsCount,
          'messages': messagesCount,
          'referrals': referralsCount,
          'total_activity': appointmentsCount + messagesCount + referralsCount,
        });
      }

      setState(() => systemPerformance = performance);
    } catch (e) {
      print('Error loading system performance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generate PDF Report',
            onPressed: _generatePDFReport,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadAnalytics,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.description), text: 'Reports'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAnalyticsTab(),
                _buildReportsTab(),
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
          // Date Range Selector
          _buildDateRangeSelector(),
          const SizedBox(height: 20),

          // Key Metrics Cards
          Text(
            'System Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),

          // User Statistics
          _buildUserStatsSection(),
          const SizedBox(height: 20),

          // Activity Overview
          _buildActivityOverview(),
          const SizedBox(height: 20),

          // Recent Activities
          _buildRecentActivitiesSection(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),

          // Performance Chart
          _buildPerformanceChart(),
          const SizedBox(height: 20),

          // Detailed Statistics
          _buildDetailedStatistics(),
          const SizedBox(height: 20),

          // Facility Distribution
          _buildFacilityDistribution(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Reports',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 16),

          // Report Generation Options
          _buildReportOptions(),
          const SizedBox(height: 20),

          // System Health
          _buildSystemHealth(),
          const SizedBox(height: 20),

          // Data Export Options
          _buildDataExportOptions(),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[700],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy',
                            ).format(selectedStartDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy').format(selectedEndDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _loadAnalytics,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'User Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4, // Reduced from 2.5 to make boxes smaller
              crossAxisSpacing: 8, // Reduced spacing
              mainAxisSpacing: 8, // Reduced spacing
              children: [
                _buildStatCard(
                  'Total Users',
                  userStats['total'] ?? 0,
                  Icons.people,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Doctors',
                  userStats['doctors'] ?? 0,
                  Icons.medical_services,
                  Colors.green,
                ),
                _buildStatCard(
                  'CHWs',
                  userStats['chw'] ?? 0,
                  Icons.health_and_safety,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Patients',
                  userStats['patients'] ?? 0,
                  Icons.personal_injury,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Facilities',
                  userStats['facility'] ?? 0,
                  Icons.local_hospital,
                  Colors.red,
                ),
                _buildStatCard(
                  'Active Today',
                  userStats['active_today'] ?? 0,
                  Icons.circle,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Activity Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4, // Reduced from 2.5 to make boxes smaller
              crossAxisSpacing: 8, // Reduced spacing
              mainAxisSpacing: 8, // Reduced spacing
              children: [
                _buildStatCard(
                  'Appointments',
                  appointmentStats['total'] ?? 0,
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Referrals',
                  referralStats['total'] ?? 0,
                  Icons.send,
                  Colors.green,
                ),
                _buildStatCard(
                  'Messages',
                  messageStats['total'] ?? 0,
                  Icons.message,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Consultations',
                  consultationStats['total'] ?? 0,
                  Icons.video_call,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitiesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Recent Activities',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(
              recentActivities.length > 3 ? 3 : recentActivities.length,
              (index) {
                final activity = recentActivities[index];
                final timestamp = activity['timestamp'] as Timestamp?;
                final timeString = timestamp != null
                    ? DateFormat('MMM dd, HH:mm').format(timestamp.toDate())
                    : 'Unknown time';
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.withOpacity(0.1),
                        child: Icon(
                          activity['icon'] as IconData,
                          color: Colors.indigo,
                          size: 20,
                        ),
                      ),
                      title: Text(activity['title'] ?? 'Unknown Activity'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(activity['description'] ?? 'No description'),
                          Text(
                            timeString,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            activity['status'],
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activity['status']?.toString().toUpperCase() ??
                              'UNKNOWN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(activity['status']),
                          ),
                        ),
                      ),
                    ),
                    if (index <
                        (recentActivities.length > 3
                            ? 2
                            : recentActivities.length - 1))
                      const Divider(),
                  ],
                );
              },
            ),
            if (recentActivities.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: recentActivities.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final activity = recentActivities[index];
                            final timestamp =
                                activity['timestamp'] as Timestamp?;
                            final timeString = timestamp != null
                                ? DateFormat(
                                    'MMM dd, HH:mm',
                                  ).format(timestamp.toDate())
                                : 'Unknown time';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.withOpacity(0.1),
                                child: Icon(
                                  activity['icon'] as IconData,
                                  color: Colors.indigo,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                activity['title'] ?? 'Unknown Activity',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity['description'] ?? 'No description',
                                  ),
                                  Text(
                                    timeString,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    activity['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  activity['status']
                                          ?.toString()
                                          .toUpperCase() ??
                                      'UNKNOWN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(activity['status']),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  child: const Text('View More'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  '7-Day Activity Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: systemPerformance.isEmpty
                  ? const Center(child: Text('No performance data available'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: systemPerformance.length,
                      itemBuilder: (context, index) {
                        final data = systemPerformance[index];
                        final maxActivity = systemPerformance
                            .map((e) => e['total_activity'] as int)
                            .reduce((a, b) => a > b ? a : b);
                        final height = maxActivity > 0
                            ? (data['total_activity'] as int) /
                                  maxActivity *
                                  150
                            : 0.0;

                        return Container(
                          width: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${data['total_activity']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: Colors.indigo,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                data['date'],
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatistics() {
    return Column(
      children: [
        // Appointment Statistics
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.indigo[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Appointment Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[700],
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
                        appointmentStats['pending'] ?? 0,
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Confirmed',
                        appointmentStats['confirmed'] ?? 0,
                        Icons.check_circle,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Completed',
                        appointmentStats['completed'] ?? 0,
                        Icons.done,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Cancelled',
                        appointmentStats['cancelled'] ?? 0,
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Referral Statistics
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.send, color: Colors.indigo[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Referral Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[700],
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
                        referralStats['pending'] ?? 0,
                        Icons.pending,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Accepted',
                        referralStats['accepted'] ?? 0,
                        Icons.check_circle,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Completed',
                        referralStats['completed'] ?? 0,
                        Icons.done,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Rejected',
                        referralStats['rejected'] ?? 0,
                        Icons.cancel,
                        Colors.red,
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

  Widget _buildFacilityDistribution() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_hospital, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Facility Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.4, // Reduced from 2.5 to make boxes smaller
              crossAxisSpacing: 8, // Reduced spacing
              mainAxisSpacing: 8, // Reduced spacing
              children: [
                _buildStatCard(
                  'Hospitals',
                  facilityStats['hospitals'] ?? 0,
                  Icons.local_hospital,
                  Colors.red,
                ),
                _buildStatCard(
                  'Clinics',
                  facilityStats['clinics'] ?? 0,
                  Icons.medical_services,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Laboratories',
                  facilityStats['laboratories'] ?? 0,
                  Icons.biotech,
                  Colors.green,
                ),
                _buildStatCard(
                  'Pharmacies',
                  facilityStats['pharmacies'] ?? 0,
                  Icons.medication,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Generate Reports',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildReportButton(
                  'User Report',
                  Icons.people,
                  () => _generateSpecificReport('users'),
                ),
                _buildReportButton(
                  'Appointment Report',
                  Icons.calendar_today,
                  () => _generateSpecificReport('appointments'),
                ),
                _buildReportButton(
                  'Referral Report',
                  Icons.send,
                  () => _generateSpecificReport('referrals'),
                ),
                _buildReportButton(
                  'Facility Report',
                  Icons.local_hospital,
                  () => _generateSpecificReport('facilities'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealth() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'System Health',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHealthIndicator('Database Status', 'Healthy', Colors.green),
            _buildHealthIndicator(
              'User Authentication',
              'Active',
              Colors.green,
            ),
            _buildHealthIndicator(
              'Message System',
              'Operational',
              Colors.green,
            ),
            _buildHealthIndicator('File Storage', 'Available', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildDataExportOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Data Export',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export Complete Report as PDF'),
              subtitle: const Text('Comprehensive system report'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _generatePDFReport,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export Data as CSV'),
              subtitle: const Text('Raw data for analysis'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _exportCSVData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.indigo.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.indigo, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator(String title, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'active':
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? selectedStartDate : selectedEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          selectedStartDate = picked;
        } else {
          selectedEndDate = picked;
        }
      });
    }
  }

  Future<void> _generatePDFReport() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'LifeCare Connect - System Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Report Date
              pw.Text(
                'Generated on: ${DateFormat('MMMM dd, yyyy - HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Period: ${DateFormat('MMM dd, yyyy').format(selectedStartDate)} - ${DateFormat('MMM dd, yyyy').format(selectedEndDate)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // User Statistics
              pw.Header(level: 1, text: 'User Statistics'),
              pw.Table.fromTextArray(
                headers: ['Category', 'Count'],
                data: [
                  ['Total Users', '${userStats['total'] ?? 0}'],
                  ['Doctors', '${userStats['doctors'] ?? 0}'],
                  ['CHWs', '${userStats['chw'] ?? 0}'],
                  ['Patients', '${userStats['patients'] ?? 0}'],
                  ['Facilities', '${userStats['facility'] ?? 0}'],
                  ['Active Today', '${userStats['active_today'] ?? 0}'],
                  ['New This Month', '${userStats['new_this_month'] ?? 0}'],
                ],
              ),
              pw.SizedBox(height: 20),

              // Activity Statistics
              pw.Header(level: 1, text: 'Activity Statistics'),
              pw.Table.fromTextArray(
                headers: ['Category', 'Total', 'Pending', 'Completed'],
                data: [
                  [
                    'Appointments',
                    '${appointmentStats['total'] ?? 0}',
                    '${appointmentStats['pending'] ?? 0}',
                    '${appointmentStats['completed'] ?? 0}',
                  ],
                  [
                    'Referrals',
                    '${referralStats['total'] ?? 0}',
                    '${referralStats['pending'] ?? 0}',
                    '${referralStats['completed'] ?? 0}',
                  ],
                  [
                    'Messages',
                    '${messageStats['total'] ?? 0}',
                    '${messageStats['broadcast'] ?? 0}',
                    '${messageStats['direct'] ?? 0}',
                  ],
                  [
                    'Consultations',
                    '${consultationStats['total'] ?? 0}',
                    '${consultationStats['ongoing'] ?? 0}',
                    '${consultationStats['completed'] ?? 0}',
                  ],
                ],
              ),
              pw.SizedBox(height: 20),

              // Facility Distribution
              pw.Header(level: 1, text: 'Facility Distribution'),
              pw.Table.fromTextArray(
                headers: ['Facility Type', 'Count'],
                data: [
                  ['Hospitals', '${facilityStats['hospitals'] ?? 0}'],
                  ['Clinics', '${facilityStats['clinics'] ?? 0}'],
                  ['Laboratories', '${facilityStats['laboratories'] ?? 0}'],
                  ['Pharmacies', '${facilityStats['pharmacies'] ?? 0}'],
                  ['Others', '${facilityStats['others'] ?? 0}'],
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Header(level: 1, text: 'Summary'),
              pw.Text(
                'This report provides a comprehensive overview of the LifeCare Connect system for the selected period. '
                'The data shows system usage patterns, user engagement, and operational metrics.',
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<void> _generateSpecificReport(String reportType) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Generating $reportType report...')));

    // Implement specific report generation
    // This would generate targeted reports for specific data types
  }

  Future<void> _exportCSVData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV export functionality coming soon...')),
    );

    // Implement CSV export functionality
  }
}
