// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/presentation/widgets/pending_appointment_tab.dart';
import '../../../shared/presentation/widgets/appointment_history_tab.dart';
import '../../../shared/presentation/widgets/shared_referral_widget.dart';
import '../../../shared/data/services/user_analytics_service.dart';
import '../../../../core/services/loading_service.dart';

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

  // Enhanced User Analytics Data
  List<Map<String, dynamic>> allUsersWithAnalytics = [];
  Map<String, dynamic> userAnalyticsResult = {};

  // User Filtering Options
  String selectedRoleFilter = '';
  String selectedActivityStatusFilter = '';
  String searchQuery = '';

  // User Pagination
  int currentUserPage = 0;
  final int usersPerPage = 20;
  bool hasMoreUsers = false;

  // Date Range Selection
  DateTime selectedStartDate = DateTime.now().subtract(
    const Duration(days: 30),
  );
  DateTime selectedEndDate = DateTime.now();

  // User Date Filters
  DateTime? userRegistrationStartDate;
  DateTime? userRegistrationEndDate;
  DateTime? userActivityStartDate;
  DateTime? userActivityEndDate;

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

    final errors = <Object>[];
    await Future.wait([
      _loadAnalyticsSection(_loadUserStatistics, errors),
      _loadAnalyticsSection(_loadActivityStatistics, errors),
      _loadAnalyticsSection(_loadHealthcareStatistics, errors),
      _loadAnalyticsSection(_loadRecentActivities, errors),
      _loadAnalyticsSection(_loadRecentAppointments, errors),
      _loadAnalyticsSection(_loadRecentReferrals, errors),
      _loadAnalyticsSection(_loadAllUsersWithAnalytics, errors),
    ]);

    if (mounted) {
      setState(() => isLoading = false);
      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Some user analytics could not load. Showing available data.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadAnalytics,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAnalyticsSection(
    Future<void> Function() loader,
    List<Object> errors,
  ) async {
    try {
      await loader();
    } catch (error) {
      errors.add(error);
      debugPrint('User analytics section failed: $error');
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
      final doctorCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'doctor')
          .length;
      final chwCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'chw')
          .length;
      final patientCount = usersSnapshot.docs
          .where((doc) => doc.data()['role'] == 'patient')
          .length;

      setState(() {
        userStats = {
          'total': usersSnapshot.docs.length,
          'newThisMonth': newUsersSnapshot.docs.length,
          'doctors': doctorCount,
          'chws': chwCount,
          'patients': patientCount,
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

  Future<void> _loadAllUsersWithAnalytics() async {
    try {
      final result = await UserAnalyticsService.getAllUsersWithAnalytics(
        roleFilter: selectedRoleFilter.isNotEmpty ? selectedRoleFilter : null,
        activityStatusFilter: selectedActivityStatusFilter.isNotEmpty
            ? selectedActivityStatusFilter
            : null,
        registrationStartDate: userRegistrationStartDate,
        registrationEndDate: userRegistrationEndDate,
        activityStartDate: userActivityStartDate,
        activityEndDate: userActivityEndDate,
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
        limit: usersPerPage,
        offset: currentUserPage * usersPerPage,
      );

      setState(() {
        userAnalyticsResult = result;
        allUsersWithAnalytics = result['users'] as List<Map<String, dynamic>>;
        hasMoreUsers = result['pagination']?['has_more'] ?? false;
      });
    } catch (e) {
      print('Error loading users with analytics: $e');
      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load user analytics data: ${e.toString()}',
            ),
            backgroundColor: Colors.red.shade600,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadAllUsersWithAnalytics,
            ),
          ),
        );
      }
    }
  }

  Future<void> _applyUserFilters() async {
    setState(() {
      currentUserPage = 0; // Reset to first page when applying filters
    });
    await _loadAllUsersWithAnalytics();
  }

  Future<void> _loadMoreUsers() async {
    if (!hasMoreUsers) return;

    setState(() {
      currentUserPage++;
    });

    try {
      final result = await UserAnalyticsService.getAllUsersWithAnalytics(
        roleFilter: selectedRoleFilter.isNotEmpty ? selectedRoleFilter : null,
        activityStatusFilter: selectedActivityStatusFilter.isNotEmpty
            ? selectedActivityStatusFilter
            : null,
        registrationStartDate: userRegistrationStartDate,
        registrationEndDate: userRegistrationEndDate,
        activityStartDate: userActivityStartDate,
        activityEndDate: userActivityEndDate,
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
        limit: usersPerPage,
        offset: currentUserPage * usersPerPage,
      );

      setState(() {
        final newUsers = result['users'] as List<Map<String, dynamic>>;
        allUsersWithAnalytics.addAll(newUsers);
        hasMoreUsers = result['pagination']?['has_more'] ?? false;
      });
    } catch (e) {
      print('Error loading more users: $e');
      setState(() {
        currentUserPage--; // Revert page number on error
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more users: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management & Analytics'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? LoadingService.buildLoadingWidget(
              message: 'Loading analytics data...',
              size: 50.0,
            )
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Purpose Info Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.teal[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Analyze individual user behavior, track engagement patterns, and manage user activity',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.teal[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    _buildUserManagementSection(),
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

  Widget _buildUserManagementSection() {
    final totalUsers =
        userAnalyticsResult['total_count'] ?? allUsersWithAnalytics.length;
    final activityStatusCounts =
        userAnalyticsResult['activity_status_counts'] as Map<String, int>? ??
        {};

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
                    const Icon(Icons.people_alt, color: Colors.teal, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Individual User Analytics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showAllUsersDialog(),
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Advanced Filters'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Filters
            _buildQuickFilters(),
            const SizedBox(height: 16),

            // User summary stats
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 8,
              children: [
                _buildStatCard(
                  'Total Users',
                  totalUsers,
                  Icons.group,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Active Users',
                  (activityStatusCounts['active_today'] ?? 0) +
                      (activityStatusCounts['active_this_week'] ?? 0) +
                      (activityStatusCounts['active_this_month'] ?? 0),
                  Icons.people,
                  Colors.green,
                ),
                _buildStatCard(
                  'Inactive Users',
                  (activityStatusCounts['inactive_recent'] ?? 0) +
                      (activityStatusCounts['inactive_long'] ?? 0) +
                      (activityStatusCounts['never_active'] ?? 0),
                  Icons.person_off,
                  Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Activity Status Breakdown
            if (activityStatusCounts.isNotEmpty) ...[
              Text(
                'Activity Status Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[600],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: activityStatusCounts.entries.map((entry) {
                  final statusInfo = UserAnalyticsService.getActivityStatusInfo(
                    entry.key,
                  );
                  return Chip(
                    avatar: Icon(
                      statusInfo['icon'] as IconData,
                      size: 16,
                      color: statusInfo['color'] as Color,
                    ),
                    label: Text(
                      '${statusInfo['label']}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: (statusInfo['color'] as Color).withOpacity(
                      0.1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Recent users list preview
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Users (${allUsersWithAnalytics.length} of $totalUsers)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal[600],
                  ),
                ),
                if (hasMoreUsers)
                  TextButton.icon(
                    onPressed: _loadMoreUsers,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Load More'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            allUsersWithAnalytics.isEmpty
                ? (isLoading
                      ? LoadingService.buildShimmerList(
                          itemCount: 3,
                          itemHeight: 60,
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getNoUsersMessage(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              if (selectedRoleFilter.isNotEmpty ||
                                  selectedActivityStatusFilter.isNotEmpty ||
                                  searchQuery.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _clearAllFilters,
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: const Text('Clear Filters'),
                                ),
                            ],
                          ),
                        ))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: allUsersWithAnalytics.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = allUsersWithAnalytics[index];
                      return _buildUserListItem(user);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                onSubmitted: (_) => _applyUserFilters(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _applyUserFilters,
              icon: const Icon(Icons.filter_list, size: 16),
              label: const Text('Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Role Filter
              _buildFilterDropdown(
                'Role',
                selectedRoleFilter,
                UserAnalyticsService.getFilterOptions()['roles']!,
                (value) {
                  setState(() {
                    selectedRoleFilter = value;
                  });
                  _applyUserFilters();
                },
              ),
              const SizedBox(width: 12),

              // Activity Status Filter
              _buildFilterDropdown(
                'Activity',
                selectedActivityStatusFilter,
                UserAnalyticsService.getFilterOptions()['activity_status']!,
                (value) {
                  setState(() {
                    selectedActivityStatusFilter = value;
                  });
                  _applyUserFilters();
                },
              ),

              const SizedBox(width: 12),

              // Clear Filters
              if (selectedRoleFilter.isNotEmpty ||
                  selectedActivityStatusFilter.isNotEmpty ||
                  searchQuery.isNotEmpty)
                ActionChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear, size: 14),
                      SizedBox(width: 4),
                      Text('Clear Filters'),
                    ],
                  ),
                  onPressed: _clearAllFilters,
                  backgroundColor: Colors.grey[100],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String currentValue,
    List<Map<String, String>> options,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
        color: currentValue.isNotEmpty ? Colors.teal.withOpacity(0.1) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue.isNotEmpty ? currentValue : null,
          hint: Text(label, style: const TextStyle(fontSize: 12)),
          isDense: true,
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(
                    option['label']!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => onChanged(value ?? ''),
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      selectedRoleFilter = '';
      selectedActivityStatusFilter = '';
      searchQuery = '';
      userRegistrationStartDate = null;
      userRegistrationEndDate = null;
      userActivityStartDate = null;
      userActivityEndDate = null;
      currentUserPage = 0;
    });
    _applyUserFilters();
  }

  String _getNoUsersMessage() {
    if (selectedRoleFilter.isNotEmpty ||
        selectedActivityStatusFilter.isNotEmpty ||
        searchQuery.isNotEmpty) {
      return 'No users found matching the current filters.\nTry adjusting your search criteria.';
    }
    return 'No user data available.\nUsers will appear here once they register.';
  }

  Widget _buildUserListItem(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';
    final email = userData['email'] ?? '';
    final activityStatus = analytics['activity_status'] ?? 'never_active';
    final trainingCompleted = analytics['training_completed'] ?? 0;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _getRoleColor(role).withOpacity(0.2),
        child: Text(
          _getInitials(name),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getRoleColor(role),
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${role.toUpperCase()} • $email',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                _getActivityStatusIcon(activityStatus),
                size: 12,
                color: _getActivityStatusColor(activityStatus),
              ),
              const SizedBox(width: 4),
              Text(
                _getActivityStatusLabel(activityStatus),
                style: TextStyle(
                  fontSize: 10,
                  color: _getActivityStatusColor(activityStatus),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.school, size: 12, color: Colors.blue),
              const SizedBox(width: 2),
              Text(
                '$trainingCompleted trainings',
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.analytics, size: 16),
        onPressed: () => _showUserAnalyticsDialog(user),
        tooltip: 'View Analytics',
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'doctor':
        return Colors.green;
      case 'chw':
        return Colors.blue;
      case 'patient':
        return Colors.purple;
      case 'facility':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    return words
        .map((word) => word.isNotEmpty ? word[0] : '')
        .join('')
        .substring(0, 2)
        .toUpperCase();
  }

  IconData _getActivityStatusIcon(String status) {
    switch (status) {
      case 'active_today':
      case 'active_this_week':
      case 'active_this_month':
        return Icons.circle;
      case 'inactive_recent':
      case 'inactive_long':
        return Icons.circle;
      case 'never_active':
        return Icons.circle_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActivityStatusColor(String status) {
    switch (status) {
      case 'active_today':
        return Colors.green;
      case 'active_this_week':
        return Colors.lightGreen;
      case 'active_this_month':
        return Colors.orange;
      case 'inactive_recent':
        return Colors.deepOrange;
      case 'inactive_long':
        return Colors.red;
      case 'never_active':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getActivityStatusLabel(String status) {
    switch (status) {
      case 'active_today':
        return 'Active Today';
      case 'active_this_week':
        return 'Active This Week';
      case 'active_this_month':
        return 'Active This Month';
      case 'inactive_recent':
        return 'Recently Inactive';
      case 'inactive_long':
        return 'Long Inactive';
      case 'never_active':
        return 'Never Active';
      default:
        return 'Unknown';
    }
  }

  void _showAllUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: _UserManagementDialog(
            initialUsers: allUsersWithAnalytics,
            userAnalyticsResult: userAnalyticsResult,
            onUserAnalyticsUpdated: (result) {
              setState(() {
                userAnalyticsResult = result;
                allUsersWithAnalytics =
                    result['users'] as List<Map<String, dynamic>>;
                hasMoreUsers = result['pagination']?['has_more'] ?? false;
              });
            },
          ),
        ),
      ),
    );
  }

  void _showUserAnalyticsDialog(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'Analytics: ${userData['fullName'] ?? 'Unknown User'}',
              ),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Information',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Name',
                            userData['fullName'] ?? 'Unknown',
                          ),
                          _buildInfoRow('Role', userData['role'] ?? 'Unknown'),
                          _buildInfoRow(
                            'Email',
                            userData['email'] ?? 'No email',
                          ),
                          _buildInfoRow(
                            'Phone',
                            userData['phoneNumber'] ?? 'No phone',
                          ),
                          _buildInfoRow(
                            'Created',
                            _formatDate(userData['createdAt']),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Activity Analytics Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activity Analytics',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Activity Status',
                            _getActivityStatusLabel(
                              analytics['activity_status'] ?? 'never_active',
                            ),
                          ),
                          _buildInfoRow(
                            'Last Activity',
                            analytics['last_activity'] != null
                                ? _formatRelativeTime(
                                    (analytics['last_activity'] as Timestamp)
                                        .toDate(),
                                  )
                                : 'Never',
                          ),
                          _buildInfoRow(
                            'Recent Activities (30 days)',
                            '${analytics['recent_activity_count'] ?? 0}',
                          ),
                          _buildInfoRow(
                            'Training Materials Accessed',
                            '${analytics['training_materials_accessed'] ?? 0}',
                          ),
                          _buildInfoRow(
                            'Training Completed',
                            '${analytics['training_completed'] ?? 0}',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Role-specific Analytics
                  if (analytics['total_appointments'] != null ||
                      analytics['total_consultations'] != null ||
                      analytics['total_services'] != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Role-specific Analytics',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (analytics['total_appointments'] != null)
                              _buildInfoRow(
                                'Total Appointments',
                                '${analytics['total_appointments']}',
                              ),
                            if (analytics['total_consultations'] != null)
                              _buildInfoRow(
                                'Total Consultations',
                                '${analytics['total_consultations']}',
                              ),
                            if (analytics['total_services'] != null)
                              _buildInfoRow(
                                'Total Services',
                                '${analytics['total_services']}',
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays >= 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays >= 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
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

// User Management Dialog Widget
class _UserManagementDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialUsers;
  final Map<String, dynamic> userAnalyticsResult;
  final Function(Map<String, dynamic>) onUserAnalyticsUpdated;

  const _UserManagementDialog({
    required this.initialUsers,
    required this.userAnalyticsResult,
    required this.onUserAnalyticsUpdated,
  });

  @override
  State<_UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<_UserManagementDialog> {
  late List<Map<String, dynamic>> users;
  late Map<String, dynamic> analyticsResult;
  bool isLoading = false;

  // Filter states
  String selectedRoleFilter = '';
  String selectedActivityStatusFilter = '';
  String searchQuery = '';
  DateTime? userRegistrationStartDate;
  DateTime? userRegistrationEndDate;
  DateTime? userActivityStartDate;
  DateTime? userActivityEndDate;

  // Pagination
  int currentPage = 0;
  final int usersPerPage = 50;
  bool hasMoreUsers = false;

  @override
  void initState() {
    super.initState();
    users = List.from(widget.initialUsers);
    analyticsResult = Map.from(widget.userAnalyticsResult);
    hasMoreUsers = analyticsResult['pagination']?['has_more'] ?? false;
  }

  Future<void> _applyFilters() async {
    setState(() {
      isLoading = true;
      currentPage = 0;
    });

    try {
      final result = await UserAnalyticsService.getAllUsersWithAnalytics(
        roleFilter: selectedRoleFilter.isNotEmpty ? selectedRoleFilter : null,
        activityStatusFilter: selectedActivityStatusFilter.isNotEmpty
            ? selectedActivityStatusFilter
            : null,
        registrationStartDate: userRegistrationStartDate,
        registrationEndDate: userRegistrationEndDate,
        activityStartDate: userActivityStartDate,
        activityEndDate: userActivityEndDate,
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
        limit: usersPerPage,
        offset: 0,
      );

      setState(() {
        analyticsResult = result;
        users = result['users'] as List<Map<String, dynamic>>;
        hasMoreUsers = result['pagination']?['has_more'] ?? false;
        isLoading = false;
      });

      // Update parent state
      widget.onUserAnalyticsUpdated(result);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error applying filters: $e')));
      }
    }
  }

  Future<void> _loadMore() async {
    if (!hasMoreUsers || isLoading) return;

    setState(() {
      currentPage++;
      isLoading = true;
    });

    try {
      final result = await UserAnalyticsService.getAllUsersWithAnalytics(
        roleFilter: selectedRoleFilter.isNotEmpty ? selectedRoleFilter : null,
        activityStatusFilter: selectedActivityStatusFilter.isNotEmpty
            ? selectedActivityStatusFilter
            : null,
        registrationStartDate: userRegistrationStartDate,
        registrationEndDate: userRegistrationEndDate,
        activityStartDate: userActivityStartDate,
        activityEndDate: userActivityEndDate,
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
        limit: usersPerPage,
        offset: currentPage * usersPerPage,
      );

      setState(() {
        final newUsers = result['users'] as List<Map<String, dynamic>>;
        users.addAll(newUsers);
        hasMoreUsers = result['pagination']?['has_more'] ?? false;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        currentPage--;
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading more users: $e')));
      }
    }
  }

  Future<void> _selectDate(bool isStart, bool isRegistration) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isRegistration) {
          if (isStart) {
            userRegistrationStartDate = picked;
          } else {
            userRegistrationEndDate = picked;
          }
        } else {
          if (isStart) {
            userActivityStartDate = picked;
          } else {
            userActivityEndDate = picked;
          }
        }
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      selectedRoleFilter = '';
      selectedActivityStatusFilter = '';
      searchQuery = '';
      userRegistrationStartDate = null;
      userRegistrationEndDate = null;
      userActivityStartDate = null;
      userActivityEndDate = null;
      currentPage = 0;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final totalUsers = analyticsResult['total_count'] ?? users.length;
    final activityStatusCounts =
        analyticsResult['activity_status_counts'] as Map<String, int>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text('User Management (${users.length} of $totalUsers)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _applyFilters,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Advanced Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search and basic filters row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) => searchQuery = value,
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Apply'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Filter dropdowns and date pickers
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Role Filter
                      _buildCompactDropdown(
                        'Role',
                        selectedRoleFilter,
                        UserAnalyticsService.getFilterOptions()['roles']!,
                        (value) => setState(() => selectedRoleFilter = value),
                      ),
                      const SizedBox(width: 8),

                      // Activity Status Filter
                      _buildCompactDropdown(
                        'Activity Status',
                        selectedActivityStatusFilter,
                        UserAnalyticsService.getFilterOptions()['activity_status']!,
                        (value) => setState(
                          () => selectedActivityStatusFilter = value,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Registration Date Filters
                      _buildDateRangeChip(
                        'Registration Date',
                        userRegistrationStartDate,
                        userRegistrationEndDate,
                        (isStart) => _selectDate(isStart, true),
                      ),
                      const SizedBox(width: 8),

                      // Activity Date Filters
                      _buildDateRangeChip(
                        'Activity Date',
                        userActivityStartDate,
                        userActivityEndDate,
                        (isStart) => _selectDate(isStart, false),
                      ),
                      const SizedBox(width: 8),

                      // Clear Filters
                      if (_hasActiveFilters())
                        ActionChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.clear, size: 14),
                              SizedBox(width: 4),
                              Text('Clear All'),
                            ],
                          ),
                          onPressed: _clearAllFilters,
                          backgroundColor: Colors.red[50],
                        ),
                    ],
                  ),
                ),

                // Activity status summary chips
                if (activityStatusCounts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: activityStatusCounts.entries.map((entry) {
                      final statusInfo =
                          UserAnalyticsService.getActivityStatusInfo(entry.key);
                      return Chip(
                        avatar: Icon(
                          statusInfo['icon'] as IconData,
                          size: 12,
                          color: statusInfo['color'] as Color,
                        ),
                        label: Text(
                          '${statusInfo['label']}: ${entry.value}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: (statusInfo['color'] as Color)
                            .withOpacity(0.1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Users List
          Expanded(
            child: isLoading && users.isEmpty
                ? LoadingService.buildLoadingWidget(message: 'Loading users...')
                : users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _hasActiveFilters()
                              ? 'No users match the current filters'
                              : 'No users found',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        if (_hasActiveFilters()) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _clearAllFilters,
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length + (hasMoreUsers ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == users.length) {
                        // Load more button
                        return Container(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator()
                                : ElevatedButton.icon(
                                    onPressed: _loadMore,
                                    icon: const Icon(Icons.expand_more),
                                    label: const Text('Load More Users'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                          ),
                        );
                      }

                      final user = users[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: _buildAdvancedUserListItem(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown(
    String label,
    String currentValue,
    List<Map<String, String>> options,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
        color: currentValue.isNotEmpty
            ? Colors.teal.withOpacity(0.1)
            : Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue.isNotEmpty ? currentValue : null,
          hint: Text(label, style: const TextStyle(fontSize: 11)),
          isDense: true,
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(
                    option['label']!,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => onChanged(value ?? ''),
        ),
      ),
    );
  }

  Widget _buildDateRangeChip(
    String label,
    DateTime? startDate,
    DateTime? endDate,
    Function(bool isStart) onTap,
  ) {
    final hasDateRange = startDate != null || endDate != null;

    return ActionChip(
      label: Text(
        hasDateRange
            ? '$label (${_formatDateRange(startDate, endDate)})'
            : label,
        style: const TextStyle(fontSize: 11),
      ),
      onPressed: () => _showDateRangePicker(label, startDate, endDate, onTap),
      backgroundColor: hasDateRange
          ? Colors.blue.withOpacity(0.1)
          : Colors.grey[100],
      avatar: Icon(
        Icons.date_range,
        size: 16,
        color: hasDateRange ? Colors.blue : Colors.grey,
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start != null && end != null) {
      return '${DateFormat('MM/dd').format(start)}-${DateFormat('MM/dd').format(end)}';
    } else if (start != null) {
      return 'From ${DateFormat('MM/dd').format(start)}';
    } else if (end != null) {
      return 'Until ${DateFormat('MM/dd').format(end)}';
    }
    return '';
  }

  void _showDateRangePicker(
    String label,
    DateTime? startDate,
    DateTime? endDate,
    Function(bool isStart) onTap,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(
                startDate != null
                    ? DateFormat('MMM dd, yyyy').format(startDate)
                    : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () {
                Navigator.pop(context);
                onTap(true);
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(
                endDate != null
                    ? DateFormat('MMM dd, yyyy').format(endDate)
                    : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () {
                Navigator.pop(context);
                onTap(false);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return selectedRoleFilter.isNotEmpty ||
        selectedActivityStatusFilter.isNotEmpty ||
        searchQuery.isNotEmpty ||
        userRegistrationStartDate != null ||
        userRegistrationEndDate != null ||
        userActivityStartDate != null ||
        userActivityEndDate != null;
  }

  Widget _buildAdvancedUserListItem(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    final name = userData['fullName'] ?? userData['name'] ?? 'Unknown User';
    final role = userData['role'] ?? 'unknown';
    final email = userData['email'] ?? '';
    final phone = userData['phoneNumber'] ?? '';
    final activityStatus = analytics['activity_status'] ?? 'never_active';
    final statusInfo = UserAnalyticsService.getActivityStatusInfo(
      activityStatus,
    );
    final createdAt = userData['createdAt'] as Timestamp?;
    final lastActivity = analytics['last_activity'] as Timestamp?;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (statusInfo['color'] as Color).withOpacity(0.2),
        child: Text(
          _getInitials(name),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: statusInfo['color'] as Color,
          ),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${role.toUpperCase()} • $email'),
          if (phone.isNotEmpty) Text('📱 $phone'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                statusInfo['icon'] as IconData,
                size: 12,
                color: statusInfo['color'] as Color,
              ),
              const SizedBox(width: 4),
              Text(
                statusInfo['label'] as String,
                style: TextStyle(
                  fontSize: 10,
                  color: statusInfo['color'] as Color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (createdAt != null)
            Text(
              'Joined: ${DateFormat('MMM dd, yyyy').format(createdAt.toDate())}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          if (lastActivity != null)
            Text(
              'Last active: ${_formatRelativeTime(lastActivity.toDate())}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.analytics, size: 16),
        onPressed: () => _showUserAnalyticsDetail(user),
        tooltip: 'View Analytics',
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.split(' ');
    return words
        .map((word) => word.isNotEmpty ? word[0] : '')
        .join('')
        .substring(0, 2)
        .toUpperCase();
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${difference.inDays >= 730 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${difference.inDays >= 60 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  void _showUserAnalyticsDetail(Map<String, dynamic> user) {
    final userData = user['user_data'] as Map<String, dynamic>;
    final analytics = user['analytics'] as Map<String, dynamic>? ?? {};

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Analytics: ${userData['fullName'] ?? 'Unknown'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildAnalyticsInfoRow('Role', userData['role'] ?? 'Unknown'),
              _buildAnalyticsInfoRow('Email', userData['email'] ?? 'No email'),
              _buildAnalyticsInfoRow(
                'Phone',
                userData['phoneNumber'] ?? 'No phone',
              ),

              const SizedBox(height: 12),
              const Text(
                'Activity Analytics',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _buildAnalyticsInfoRow(
                'Status',
                _getActivityStatusLabel(
                  analytics['activity_status'] ?? 'never_active',
                ),
              ),
              if (analytics['last_activity'] != null)
                _buildAnalyticsInfoRow(
                  'Last Activity',
                  _formatRelativeTime(
                    (analytics['last_activity'] as Timestamp).toDate(),
                  ),
                ),
              _buildAnalyticsInfoRow(
                'Recent Activities (30 days)',
                '${analytics['recent_activity_count'] ?? 0}',
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getActivityStatusLabel(String status) {
    final statusInfo = UserAnalyticsService.getActivityStatusInfo(status);
    return statusInfo['label'] as String;
  }
}
