// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/presentation/widgets/pending_appointment_tab.dart';
import '../../../shared/presentation/widgets/appointment_history_tab.dart';
import '../../../shared/presentation/widgets/shared_referral_widget.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  String? currentUserId;

  // Analytics Data
  Map<String, int> userStats = {};
  Map<String, int> activityStats = {};
  Map<String, dynamic> healthcareStats = {};
  List<Map<String, dynamic>> recentActivities = [];
  List<Map<String, dynamic>> recentAppointments = [];
  List<Map<String, dynamic>> recentReferrals = [];

  // Date Range Selection
  DateTime selectedStartDate = DateTime.now().subtract(
    const Duration(days: 30),
  );
  DateTime selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
        _loadActivityStatistics(),
        _loadHealthcareStatistics(),
        _loadRecentActivities(),
        _loadRecentAppointments(),
        _loadRecentReferrals(),
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
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);

      // Total users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // New users this month
      final newUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thisMonth),
          )
          .get();

      // Users by role
      final adminCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'admin')
          .length;
      final doctorCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'doctor')
          .length;
      final chwCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'chw')
          .length;
      final patientCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'patient')
          .length;
      final facilityCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'facility')
          .length;

      setState(() {
        userStats = {
          'total': usersSnapshot.docs.length,
          'newThisMonth': newUsersSnapshot.docs.length,
          'admins': adminCount,
          'doctors': doctorCount,
          'chws': chwCount,
          'patients': patientCount,
          'facilities': facilityCount,
        };
      });
    } catch (e) {
      print('Error loading user statistics: $e');
    }
  }

  Future<void> _loadActivityStatistics() async {
    try {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);

      // Appointments
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .get();

      final monthlyAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thisMonth),
          )
          .get();

      // Consultations
      final consultationsSnapshot = await FirebaseFirestore.instance
          .collection('consultations')
          .get();

      final monthlyConsultations = await FirebaseFirestore.instance
          .collection('consultations')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thisMonth),
          )
          .get();

      // Referrals
      final referralsSnapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .get();

      final monthlyReferrals = await FirebaseFirestore.instance
          .collection('referrals')
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thisMonth),
          )
          .get();

      setState(() {
        activityStats = {
          'totalAppointments': appointmentsSnapshot.docs.length,
          'monthlyAppointments': monthlyAppointments.docs.length,
          'totalConsultations': consultationsSnapshot.docs.length,
          'monthlyConsultations': monthlyConsultations.docs.length,
          'totalReferrals': referralsSnapshot.docs.length,
          'monthlyReferrals': monthlyReferrals.docs.length,
        };
      });
    } catch (e) {
      print('Error loading activity statistics: $e');
    }
  }

  Future<void> _loadHealthcareStatistics() async {
    try {
      // Health Facilities from healthFacilities collection
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('healthFacilities')
          .get();

      // Facility users from users collection with role 'facility'
      final facilityUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .get();

      // Training Sessions
      final trainingsSnapshot = await FirebaseFirestore.instance
          .collection('trainings')
          .get();

      // Categorize facilities by type
      Map<String, int> facilityCategoriesFromHealthFacilities = {
        'hospitals': 0,
        'laboratories': 0,
        'pharmacies': 0,
        'scan_centers': 0,
        'others': 0,
      };

      Map<String, int> facilityCategoriesFromUsers = {
        'hospitals': 0,
        'laboratories': 0,
        'pharmacies': 0,
        'scan_centers': 0,
        'others': 0,
      };

      // Process healthFacilities collection
      for (var doc in facilitiesSnapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString().toLowerCase() ?? '';

        if (type.contains('hospital')) {
          facilityCategoriesFromHealthFacilities['hospitals'] =
              facilityCategoriesFromHealthFacilities['hospitals']! + 1;
        } else if (type.contains('laboratory') || type.contains('lab')) {
          facilityCategoriesFromHealthFacilities['laboratories'] =
              facilityCategoriesFromHealthFacilities['laboratories']! + 1;
        } else if (type.contains('pharmacy') || type.contains('drug')) {
          facilityCategoriesFromHealthFacilities['pharmacies'] =
              facilityCategoriesFromHealthFacilities['pharmacies']! + 1;
        } else if (type.contains('scan') ||
            type.contains('imaging') ||
            type.contains('radiology')) {
          facilityCategoriesFromHealthFacilities['scan_centers'] =
              facilityCategoriesFromHealthFacilities['scan_centers']! + 1;
        } else {
          facilityCategoriesFromHealthFacilities['others'] =
              facilityCategoriesFromHealthFacilities['others']! + 1;
        }
      }

      // Process users with role 'facility'
      for (var doc in facilityUsersSnapshot.docs) {
        final data = doc.data();
        final facilityType =
            data['facilityType']?.toString().toLowerCase() ??
            data['type']?.toString().toLowerCase() ??
            '';

        if (facilityType.contains('hospital')) {
          facilityCategoriesFromUsers['hospitals'] =
              facilityCategoriesFromUsers['hospitals']! + 1;
        } else if (facilityType.contains('laboratory') ||
            facilityType.contains('lab')) {
          facilityCategoriesFromUsers['laboratories'] =
              facilityCategoriesFromUsers['laboratories']! + 1;
        } else if (facilityType.contains('pharmacy') ||
            facilityType.contains('drug')) {
          facilityCategoriesFromUsers['pharmacies'] =
              facilityCategoriesFromUsers['pharmacies']! + 1;
        } else if (facilityType.contains('scan') ||
            facilityType.contains('imaging') ||
            facilityType.contains('radiology')) {
          facilityCategoriesFromUsers['scan_centers'] =
              facilityCategoriesFromUsers['scan_centers']! + 1;
        } else if (facilityType.isNotEmpty) {
          facilityCategoriesFromUsers['others'] =
              facilityCategoriesFromUsers['others']! + 1;
        }
      }

      // Combine counts from both sources
      Map<String, int> combinedFacilityCategories = {
        'hospitals':
            facilityCategoriesFromHealthFacilities['hospitals']! +
            facilityCategoriesFromUsers['hospitals']!,
        'laboratories':
            facilityCategoriesFromHealthFacilities['laboratories']! +
            facilityCategoriesFromUsers['laboratories']!,
        'pharmacies':
            facilityCategoriesFromHealthFacilities['pharmacies']! +
            facilityCategoriesFromUsers['pharmacies']!,
        'scan_centers':
            facilityCategoriesFromHealthFacilities['scan_centers']! +
            facilityCategoriesFromUsers['scan_centers']!,
        'others':
            facilityCategoriesFromHealthFacilities['others']! +
            facilityCategoriesFromUsers['others']!,
      };

      setState(() {
        healthcareStats = {
          'totalFacilities':
              facilitiesSnapshot.docs.length +
              facilityUsersSnapshot.docs.length,
          'totalTrainings': trainingsSnapshot.docs.length,
          'facilityCategories': combinedFacilityCategories,
        };
      });
    } catch (e) {
      print('Error loading healthcare statistics: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Recent appointments
      final recentAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();

      for (var doc in recentAppointments.docs) {
        activities.add({
          'type': 'Appointment',
          'description': 'New appointment scheduled',
          'timestamp': doc.data()['created_at'],
          'icon': Icons.calendar_today,
        });
      }

      // Recent consultations
      final recentConsultations = await FirebaseFirestore.instance
          .collection('consultations')
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();

      for (var doc in recentConsultations.docs) {
        activities.add({
          'type': 'Consultation',
          'description': 'New consultation completed',
          'timestamp': doc.data()['created_at'],
          'icon': Icons.medical_services,
        });
      }

      // Sort by timestamp
      activities.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      setState(() {
        recentActivities = activities.take(10).toList();
      });
    } catch (e) {
      print('Error loading recent activities: $e');
    }
  }

  Future<void> _loadRecentAppointments() async {
    try {
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> appointments = [];
      for (var doc in appointmentsSnapshot.docs) {
        final data = doc.data();
        appointments.add({
          'id': doc.id,
          'patientName': data['patient_name'] ?? 'Unknown Patient',
          'doctorName': data['doctor_name'] ?? 'Unknown Doctor',
          'appointmentDate': data['appointment_date'],
          'status': data['status'] ?? 'pending',
          'type': data['type'] ?? 'General',
          'createdAt': data['created_at'],
        });
      }

      setState(() {
        recentAppointments = appointments;
      });
    } catch (e) {
      print('Error loading recent appointments: $e');
    }
  }

  Future<void> _loadRecentReferrals() async {
    try {
      final referralsSnapshot = await FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();

      List<Map<String, dynamic>> referrals = [];
      for (var doc in referralsSnapshot.docs) {
        final data = doc.data();
        referrals.add({
          'id': doc.id,
          'patientName': data['patient_name'] ?? 'Unknown Patient',
          'fromProvider': data['from_provider'] ?? 'Unknown Provider',
          'toFacility': data['to_facility'] ?? 'Unknown Facility',
          'status': data['status'] ?? 'pending',
          'urgency': data['urgency'] ?? 'Normal',
          'reason': data['reason'] ?? 'No reason provided',
          'createdAt': data['created_at'],
        });
      }

      setState(() {
        recentReferrals = referrals;
      });
    } catch (e) {
      print('Error loading recent referrals: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserStatistics(),
                    const SizedBox(height: 24),
                    _buildActivityStatistics(),
                    const SizedBox(height: 24),
                    _buildHealthcareStatistics(),
                    const SizedBox(height: 24),
                    _buildAppointmentsSection(),
                    const SizedBox(height: 24),
                    _buildReferralsSection(),
                    const SizedBox(height: 24),
                    _buildRecentActivities(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserStatistics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Text(
                  'User Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildStatCard(
                  'Total Users',
                  userStats['total'] ?? 0,
                  Icons.group,
                  Colors.blue,
                ),
                _buildStatCard(
                  'New This Month',
                  userStats['newThisMonth'] ?? 0,
                  Icons.person_add,
                  Colors.green,
                ),
                _buildStatCard(
                  'Doctors',
                  userStats['doctors'] ?? 0,
                  Icons.medical_services,
                  Colors.red,
                ),
                _buildStatCard(
                  'CHWs',
                  userStats['chws'] ?? 0,
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
                  userStats['facilities'] ?? 0,
                  Icons.local_hospital,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStatistics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Activity Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildStatCard(
                  'Total Appointments',
                  activityStats['totalAppointments'] ?? 0,
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Monthly Appointments',
                  activityStats['monthlyAppointments'] ?? 0,
                  Icons.today,
                  Colors.green,
                ),
                _buildStatCard(
                  'Total Consultations',
                  activityStats['totalConsultations'] ?? 0,
                  Icons.medical_services,
                  Colors.red,
                ),
                _buildStatCard(
                  'Monthly Consultations',
                  activityStats['monthlyConsultations'] ?? 0,
                  Icons.healing,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Total Referrals',
                  activityStats['totalReferrals'] ?? 0,
                  Icons.compare_arrows,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Monthly Referrals',
                  activityStats['monthlyReferrals'] ?? 0,
                  Icons.arrow_forward,
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthcareStatistics() {
    final facilityCategories =
        healthcareStats['facilityCategories'] as Map<String, int>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Healthcare Facilities',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Total facilities and trainings
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Facilities',
                    healthcareStats['totalFacilities'] ?? 0,
                    Icons.local_hospital,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Training Programs',
                    healthcareStats['totalTrainings'] ?? 0,
                    Icons.school,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Facility categories
            Text(
              'Facility Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal[600],
              ),
            ),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: [
                _buildStatCard(
                  'Hospitals',
                  facilityCategories['hospitals'] ?? 0,
                  Icons.local_hospital,
                  Colors.red,
                ),
                _buildStatCard(
                  'Laboratories',
                  facilityCategories['laboratories'] ?? 0,
                  Icons.biotech,
                  Colors.purple,
                ),
                _buildStatCard(
                  'Pharmacies',
                  facilityCategories['pharmacies'] ?? 0,
                  Icons.local_pharmacy,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Scan Centers',
                  facilityCategories['scan_centers'] ?? 0,
                  Icons.medical_services,
                  Colors.blue,
                ),
              ],
            ),

            // Others category if there are any
            if ((facilityCategories['others'] ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _buildStatCard(
                'Other Facilities',
                facilityCategories['others'] ?? 0,
                Icons.business,
                Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Recent Activities',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            recentActivities.isEmpty
                ? const Center(
                    child: Text(
                      'No recent activities',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentActivities.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final activity = recentActivities[index];
                      final timestamp = activity['timestamp'] as Timestamp?;
                      final timeString = timestamp != null
                          ? DateFormat(
                              'MMM dd, yyyy - HH:mm',
                            ).format(timestamp.toDate())
                          : 'Unknown time';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.withOpacity(0.1),
                          child: Icon(
                            activity['icon'] as IconData,
                            color: Colors.teal,
                          ),
                        ),
                        title: Text(activity['type'] ?? 'Unknown'),
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
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.teal,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appointments Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showFullAppointments(context),
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    activityStats['totalAppointments'] ?? 0,
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'This Month',
                    activityStats['monthlyAppointments'] ?? 0,
                    Icons.today,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recent appointments list
            Text(
              'Recent Appointments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal[600],
              ),
            ),
            const SizedBox(height: 12),

            recentAppointments.isEmpty
                ? const Center(
                    child: Text(
                      'No recent appointments',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentAppointments.take(5).length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final appointment = recentAppointments[index];
                      final appointmentDate =
                          appointment['appointmentDate'] as Timestamp?;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: _getStatusColor(
                            appointment['status'],
                          ).withOpacity(0.1),
                          child: Icon(
                            Icons.calendar_today,
                            color: _getStatusColor(appointment['status']),
                            size: 16,
                          ),
                        ),
                        title: Text(
                          appointment['patientName'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor: ${appointment['doctorName']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Type: ${appointment['type']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (appointmentDate != null)
                              Text(
                                'Date: ${DateFormat('MMM dd, yyyy').format(appointmentDate.toDate())}',
                                style: const TextStyle(fontSize: 12),
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
                              appointment['status'],
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusColor(
                                appointment['status'],
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            appointment['status'].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(appointment['status']),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.compare_arrows,
                      color: Colors.teal,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Referrals Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showFullReferrals(context),
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total',
                    activityStats['totalReferrals'] ?? 0,
                    Icons.compare_arrows,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'This Month',
                    activityStats['monthlyReferrals'] ?? 0,
                    Icons.arrow_forward,
                    Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Recent referrals list
            Text(
              'Recent Referrals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal[600],
              ),
            ),
            const SizedBox(height: 12),

            recentReferrals.isEmpty
                ? const Center(
                    child: Text(
                      'No recent referrals',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentReferrals.take(5).length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final referral = recentReferrals[index];
                      final createdAt = referral['createdAt'] as Timestamp?;

                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: _getUrgencyColor(
                            referral['urgency'],
                          ).withOpacity(0.1),
                          child: Icon(
                            Icons.compare_arrows,
                            color: _getUrgencyColor(referral['urgency']),
                            size: 16,
                          ),
                        ),
                        title: Text(
                          referral['patientName'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From: ${referral['fromProvider']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'To: ${referral['toFacility']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Reason: ${referral['reason']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (createdAt != null)
                              Text(
                                'Date: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  referral['status'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(
                                    referral['status'],
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                referral['status'].toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(referral['status']),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getUrgencyColor(
                                  referral['urgency'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getUrgencyColor(
                                    referral['urgency'],
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                referral['urgency'].toString().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: _getUrgencyColor(referral['urgency']),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showFullAppointments(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text("All Appointments"),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                bottom: const TabBar(
                  tabs: [
                    Tab(text: "Pending"),
                    Tab(text: "History"),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  PendingAppointmentTab(role: 'admin', userId: currentUserId),
                  AppointmentHistoryTab(role: 'admin', userId: currentUserId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullReferrals(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('All Referrals'),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            body: const SharedReferralWidget(role: 'admin'),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getUrgencyColor(String? urgency) {
    switch (urgency?.toLowerCase()) {
      case 'high':
      case 'urgent':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      case 'normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
