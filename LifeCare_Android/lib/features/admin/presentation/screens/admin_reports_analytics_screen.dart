// ignore_for_file: avoid_print, use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'admin_training_engagement_screen.dart';
import '../../../../core/services/loading_service.dart';
import '../../../shared/data/services/user_analytics_service.dart';

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

  // Financial Data
  Map<String, double> revenueStats = {};
  Map<String, double> expenseStats = {};
  Map<String, int> paymentStats = {};
  List<Map<String, dynamic>> financialTrends = [];

  // Date Range Selection
  DateTime selectedStartDate = DateTime.now().subtract(
    const Duration(days: 30),
  );
  DateTime selectedEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
    ); // Increased to 5 for user management tab
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
      _loadAnalyticsSection(_loadAppointmentStatistics, errors),
      _loadAnalyticsSection(_loadReferralStatistics, errors),
      _loadAnalyticsSection(_loadMessageStatistics, errors),
      _loadAnalyticsSection(_loadFacilityStatistics, errors),
      _loadAnalyticsSection(_loadConsultationStatistics, errors),
      _loadAnalyticsSection(_loadRecentActivities, errors),
      _loadAnalyticsSection(_loadSystemPerformance, errors),
      _loadAnalyticsSection(_loadFinancialData, errors),
    ]);

    if (mounted) {
      setState(() => isLoading = false);
      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Some analytics could not load. Showing available data.',
            ),
            backgroundColor: Colors.orange.shade700,
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
      debugPrint('Analytics section failed: $error');
    }
  }

  Future<void> _loadUserStatistics() async {
    try {
      // Use the enhanced user analytics service with date range filtering
      final stats = await UserAnalyticsService.getUserStatisticsSummary(
        startDate: selectedStartDate,
        endDate: selectedEndDate,
      );

      setState(
        () =>
            userStats = stats.map((key, value) => MapEntry(key, value as int)),
      );
    } catch (e) {
      // Error handled by _loadAnalytics()
      rethrow;
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
        final appointmentDate = _parseTimestamp(data['appointmentDate']);

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
      // Error handled by _loadAnalytics()
      rethrow;
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
      // Error handled by _loadAnalytics()
      rethrow;
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
        final timestamp = _parseTimestamp(data['timestamp']);

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
      // Error handled by _loadAnalytics()
      rethrow;
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
      // Error handled by _loadAnalytics()
      rethrow;
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
      // Error handled by _loadAnalytics()
      rethrow;
    }
  }

  // Helper function to safely parse timestamp (handles both Timestamp and String)
  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is String) {
      try {
        return DateTime.parse(timestamp);
      } catch (e) {
        return null;
      }
    }
    return null;
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
        final timestamp = _parseTimestamp(data['createdAt']);
        if (timestamp != null) {
          activities.add({
            'type': 'appointment',
            'title': 'New Appointment',
            'description':
                'Appointment scheduled with ${data['doctorName'] ?? 'Doctor'}',
            'timestamp': timestamp,
            'status': data['status'],
            'icon': Icons.calendar_today,
          });
        }
      }

      // Load recent referrals
      final recentReferrals = await FirebaseFirestore.instance
          .collection('referrals')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in recentReferrals.docs) {
        final data = doc.data();
        final timestamp = _parseTimestamp(data['createdAt']);
        if (timestamp != null) {
          activities.add({
            'type': 'referral',
            'title': 'New Referral',
            'description': 'Referral to ${data['facilityName'] ?? 'Facility'}',
            'timestamp': timestamp,
            'status': data['status'],
            'icon': Icons.send,
          });
        }
      }

      // Load recent user registrations
      final recentUsers = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in recentUsers.docs) {
        final data = doc.data();
        final timestamp = _parseTimestamp(data['createdAt']);
        if (timestamp != null) {
          activities.add({
            'type': 'user',
            'title': 'New User Registration',
            'description':
                '${data['role']?.toString().toUpperCase() ?? 'User'}: ${data['name'] ?? 'Unknown'}',
            'timestamp': timestamp,
            'status': 'active',
            'icon': Icons.person_add,
          });
        }
      }

      // Sort activities by timestamp
      activities.sort((a, b) {
        final aTime = a['timestamp'] as DateTime? ?? DateTime.now();
        final bTime = b['timestamp'] as DateTime? ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      setState(() => recentActivities = activities.take(15).toList());
    } catch (e) {
      // Error handled by _loadAnalytics()
      rethrow;
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
      // Error handled by _loadAnalytics()
      rethrow;
    }
  }

  Future<void> _loadFinancialData() async {
    try {
      // Load wallet transactions for revenue analysis
      final walletsSnapshot = await FirebaseFirestore.instance
          .collection('wallets')
          .get();

      double totalRevenue = 0;
      double totalWithdrawals = 0;
      double totalDeposits = 0;
      int totalTransactions = 0;
      int successfulPayments = 0;
      int pendingPayments = 0;
      int failedPayments = 0;

      for (var walletDoc in walletsSnapshot.docs) {
        final walletData = walletDoc.data();
        final balance = walletData['balance']?.toDouble() ?? 0.0;
        totalRevenue += balance;

        // Get transactions for this wallet
        final transactionsSnapshot = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(walletDoc.id)
            .collection('transactions')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(selectedStartDate),
            )
            .where(
              'timestamp',
              isLessThan: Timestamp.fromDate(
                selectedEndDate.add(const Duration(days: 1)),
              ),
            )
            .get();

        for (var transDoc in transactionsSnapshot.docs) {
          final transData = transDoc.data();
          final amount = transData['amount']?.toDouble() ?? 0.0;
          final type = transData['type']?.toString() ?? '';
          final status = transData['status']?.toString() ?? '';

          totalTransactions++;

          if (type == 'deposit' || type == 'payment_received') {
            totalDeposits += amount;
          } else if (type == 'withdrawal' || type == 'payment_sent') {
            totalWithdrawals += amount;
          }

          switch (status) {
            case 'completed':
            case 'success':
              successfulPayments++;
              break;
            case 'pending':
              pendingPayments++;
              break;
            case 'failed':
            case 'cancelled':
              failedPayments++;
              break;
          }
        }
      }

      // Calculate expenses from withdrawal transactions categorized by description/category
      double operationalCosts = 0;
      double staffSalaries = 0;
      double infrastructure = 0;
      double marketing = 0;
      double other = 0;

      for (var walletDoc in walletsSnapshot.docs) {
        final expenseTransactionsSnapshot = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(walletDoc.id)
            .collection('transactions')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(selectedStartDate),
            )
            .where(
              'timestamp',
              isLessThan: Timestamp.fromDate(
                selectedEndDate.add(const Duration(days: 1)),
              ),
            )
            .get();

        for (var transDoc in expenseTransactionsSnapshot.docs) {
          final transData = transDoc.data();
          final type = transData['type']?.toString() ?? '';

          // Only process withdrawal/payment_sent transactions
          if (type == 'withdrawal' || type == 'payment_sent') {
            final amount = transData['amount']?.toDouble() ?? 0.0;
            final category =
                transData['category']?.toString().toLowerCase() ?? '';
            final description =
                transData['description']?.toString().toLowerCase() ?? '';
            final status = transData['status']?.toString() ?? '';

            // Only count completed expenses
            if (status == 'completed' || status == 'success') {
              // Categorize based on category or description keywords
              if (category.contains('salary') ||
                  description.contains('salary') ||
                  category.contains('staff') ||
                  description.contains('staff')) {
                staffSalaries += amount;
              } else if (category.contains('infrastructure') ||
                  description.contains('infrastructure') ||
                  category.contains('equipment') ||
                  description.contains('equipment')) {
                infrastructure += amount;
              } else if (category.contains('marketing') ||
                  description.contains('marketing') ||
                  category.contains('advertising') ||
                  description.contains('advertising')) {
                marketing += amount;
              } else if (category.contains('operational') ||
                  description.contains('operational') ||
                  category.contains('utilities') ||
                  description.contains('utilities') ||
                  category.contains('rent') ||
                  description.contains('rent')) {
                operationalCosts += amount;
              } else {
                other += amount;
              }
            }
          }
        }
      }

      // Calculate revenue trends for the last 6 months from actual transaction data
      final trends = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = 5; i >= 0; i--) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(now.year, now.month - i + 1, 1);

        double monthlyRevenue = 0;
        double monthlyExpenses = 0;

        // Get all transactions for this month across all wallets
        for (var walletDoc in walletsSnapshot.docs) {
          final monthTransactionsSnapshot = await FirebaseFirestore.instance
              .collection('wallets')
              .doc(walletDoc.id)
              .collection('transactions')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
              )
              .where('timestamp', isLessThan: Timestamp.fromDate(monthEnd))
              .get();

          for (var transDoc in monthTransactionsSnapshot.docs) {
            final transData = transDoc.data();
            final amount = transData['amount']?.toDouble() ?? 0.0;
            final type = transData['type']?.toString() ?? '';
            final status = transData['status']?.toString() ?? '';

            // Only count completed/successful transactions
            if (status == 'completed' || status == 'success') {
              if (type == 'deposit' || type == 'payment_received') {
                monthlyRevenue += amount;
              } else if (type == 'withdrawal' || type == 'payment_sent') {
                monthlyExpenses += amount;
              }
            }
          }
        }

        trends.add({
          'month': DateFormat('MMM').format(monthStart),
          'revenue': monthlyRevenue,
          'expenses': monthlyExpenses,
          'profit': monthlyRevenue - monthlyExpenses,
        });
      }

      setState(() {
        revenueStats = {
          'total_revenue': totalRevenue,
          'total_deposits': totalDeposits,
          'total_withdrawals': totalWithdrawals,
          'net_revenue': totalDeposits - totalWithdrawals,
          'average_transaction': totalTransactions > 0
              ? totalDeposits / totalTransactions
              : 0,
        };

        paymentStats = {
          'total_transactions': totalTransactions,
          'successful_payments': successfulPayments,
          'pending_payments': pendingPayments,
          'failed_payments': failedPayments,
          'success_rate': totalTransactions > 0
              ? ((successfulPayments / totalTransactions) * 100).round()
              : 0,
        };

        expenseStats = {
          'operational_costs': operationalCosts,
          'staff_salaries': staffSalaries,
          'infrastructure': infrastructure,
          'marketing': marketing,
          'other': other,
        };

        financialTrends = trends;
      });
    } catch (e) {
      // Error handled by _loadAnalytics()
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Action buttons row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Text(
                  'System Reports & Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
                const Spacer(),
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
            ),
          ),
          // Purpose Info Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              border: Border(bottom: BorderSide(color: Colors.indigo[100]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.indigo[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Generate system-wide reports, track financial metrics, and monitor platform health',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.indigo[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // TabBar
          Container(
            color: Colors.indigo,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                Tab(icon: Icon(Icons.people), text: 'Users'),
                Tab(icon: Icon(Icons.attach_money), text: 'Financial'),
                Tab(icon: Icon(Icons.description), text: 'Reports'),
              ],
            ),
          ),
          // TabBarView
          Expanded(
            child: isLoading
                ? LoadingService.buildShimmerList(itemCount: 6, itemHeight: 120)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildAnalyticsTab(),
                      _buildUsersTab(),
                      _buildFinancialTab(),
                      _buildReportsTab(),
                    ],
                  ),
          ),
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

          // Training Engagement Quick Actions
          _buildTrainingEngagementActions(),
          const SizedBox(height: 20),

          // Cross-Role Analytics & Care Coordination
          _buildCareCoordinationMetrics(),
          const SizedBox(height: 20),

          // System-wide Quality Indicators
          _buildQualityIndicators(),
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

  Widget _buildUsersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System-Wide User Statistics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aggregate user metrics and registration trends across the platform',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          // Info banner directing to User Analytics screen for individual user analysis
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.teal[700],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For individual user analytics and management, visit the User Management & Analytics screen',
                    style: TextStyle(fontSize: 12, color: Colors.teal[800]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info Card about date range filtering
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'User statistics are filtered by the selected date range above. Use the date range selector to analyze users registered within specific periods.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Enhanced User Statistics
          _buildEnhancedUserStatsSection(),
          const SizedBox(height: 20),

          // Activity Status Distribution
          _buildActivityStatusDistribution(),
          const SizedBox(height: 20),

          // Role Distribution Chart
          _buildRoleDistributionChart(),
          const SizedBox(height: 20),

          // Training Material Engagement
          _buildTrainingEngagementSection(),
        ],
      ),
    );
  }

  Widget _buildEnhancedUserStatsSection() {
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
                  'User Statistics (Date Filtered)',
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
              crossAxisCount: 3,
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  'Total Users',
                  userStats['total'] ?? 0,
                  Icons.group,
                  Colors.blue,
                ),
                _buildStatCard(
                  'New This Period',
                  userStats['new_this_month'] ?? 0,
                  Icons.person_add,
                  Colors.green,
                ),
                _buildStatCard(
                  'Active Today',
                  userStats['active_today'] ?? 0,
                  Icons.circle,
                  Colors.teal,
                ),
                _buildStatCard(
                  'Active This Week',
                  userStats['active_this_week'] ?? 0,
                  Icons.trending_up,
                  Colors.lightGreen,
                ),
                _buildStatCard(
                  'Active This Month',
                  userStats['active_this_month'] ?? 0,
                  Icons.calendar_month,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Never Active',
                  userStats['never_active'] ?? 0,
                  Icons.circle_outlined,
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStatusDistribution() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Activity Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[700],
              ),
            ),
            const SizedBox(height: 16),

            // Create activity status breakdown
            Column(
              children: [
                _buildActivityStatusBar(
                  'Active Today',
                  userStats['active_today'] ?? 0,
                  Colors.green,
                ),
                const SizedBox(height: 8),
                _buildActivityStatusBar(
                  'Active This Week',
                  userStats['active_this_week'] ?? 0,
                  Colors.lightGreen,
                ),
                const SizedBox(height: 8),
                _buildActivityStatusBar(
                  'Active This Month',
                  userStats['active_this_month'] ?? 0,
                  Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildActivityStatusBar(
                  'Recently Inactive',
                  userStats['inactive_recent'] ?? 0,
                  Colors.deepOrange,
                ),
                const SizedBox(height: 8),
                _buildActivityStatusBar(
                  'Long Inactive',
                  userStats['inactive_long'] ?? 0,
                  Colors.red,
                ),
                const SizedBox(height: 8),
                _buildActivityStatusBar(
                  'Never Active',
                  userStats['never_active'] ?? 0,
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStatusBar(String label, int count, Color color) {
    final totalUsers = userStats['total'] ?? 1; // Avoid division by zero
    final percentage = totalUsers > 0 ? (count / totalUsers) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '$count (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildRoleDistributionChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Role Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[700],
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildRoleCard(
                  'Doctors',
                  userStats['doctors'] ?? 0,
                  Icons.medical_services,
                  Colors.red,
                ),
                _buildRoleCard(
                  'CHWs',
                  userStats['chw'] ?? 0,
                  Icons.health_and_safety,
                  Colors.blue,
                ),
                _buildRoleCard(
                  'Patients',
                  userStats['patients'] ?? 0,
                  Icons.personal_injury,
                  Colors.purple,
                ),
                _buildRoleCard(
                  'Facilities',
                  userStats['facility'] ?? 0,
                  Icons.local_hospital,
                  Colors.teal,
                ),
                _buildRoleCard(
                  'Admins',
                  userStats['admin'] ?? 0,
                  Icons.admin_panel_settings,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, int count, IconData icon, Color color) {
    final totalUsers = userStats['total'] ?? 1;
    final percentage = totalUsers > 0 ? (count / totalUsers) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            '(${percentage.toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingEngagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Training Material Engagement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AdminTrainingEngagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View Details'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.school, color: Colors.green, size: 24),
                        SizedBox(height: 8),
                        Text(
                          'Training materials and user engagement analytics are available in the dedicated Training Engagement screen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
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
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _loadAnalytics,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Apply'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _setQuickDateRange('week'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Week',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _setQuickDateRange('month'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Month',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _setQuickDateRange('year'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Year',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Date range filtering: User registration dates are filtered by the selected range. Activity status shows current user engagement regardless of registration date.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
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

  Widget _buildCareCoordinationMetrics() {
    // Calculate referral success rates and care coordination metrics
    final totalReferrals = referralStats['total'] ?? 0;
    final completedReferrals = referralStats['completed'] ?? 0;
    final referralSuccessRate = totalReferrals > 0
        ? ((completedReferrals / totalReferrals) * 100).round()
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
                Icon(Icons.hub, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Text(
                  'Care Coordination Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Cross-Role',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCoordinationCard(
                    'Referral Success Rate',
                    '$referralSuccessRate%',
                    Icons.check_circle,
                    referralSuccessRate >= 80
                        ? Colors.green
                        : referralSuccessRate >= 60
                        ? Colors.orange
                        : Colors.red,
                    'Patient handoffs',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoordinationCard(
                    'Training Effectiveness',
                    '87%',
                    Icons.school,
                    Colors.blue,
                    'Across all roles',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCoordinationCard(
                    'Communication Score',
                    '92%',
                    Icons.chat,
                    Colors.purple,
                    'Inter-role messaging',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoordinationCard(
                    'Response Time',
                    '2.3h',
                    Icons.timer,
                    Colors.indigo,
                    'Average response',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Care Pathway Analysis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPathwayStep(
                        'CHW',
                        'Patient Registration',
                        Colors.green,
                        true,
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      _buildPathwayStep(
                        'Doctor',
                        'Consultation',
                        Colors.blue,
                        true,
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      _buildPathwayStep(
                        'Facility',
                        'Treatment',
                        Colors.orange,
                        false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityIndicators() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'System-wide Quality Indicators',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Quality',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQualityCard(
                    'Patient Satisfaction',
                    '4.2/5.0',
                    Icons.sentiment_very_satisfied,
                    Colors.green,
                    '+0.3 from last month',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQualityCard(
                    'Treatment Adherence',
                    '78%',
                    Icons.medication,
                    Colors.blue,
                    '+5% improvement',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQualityCard(
                    'Clinical Outcomes',
                    '85%',
                    Icons.health_and_safety,
                    Colors.purple,
                    'Positive outcomes',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQualityCard(
                    'System Uptime',
                    '99.2%',
                    Icons.cloud_done,
                    Colors.indigo,
                    'High availability',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quality trends visualization
            Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.green.withOpacity(0.2),
                      ),
                      child: const Center(
                        child: Text(
                          'Excellent\nQuality Score: 91%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LinearProgressIndicator(
                            value: 0.91,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.green,
                            ),
                            minHeight: 6,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Overall system quality trending upward',
                            style: TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
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

  Widget _buildCoordinationCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: color, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPathwayStep(
    String role,
    String step,
    Color color,
    bool completed,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: completed ? color : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : Icons.schedule,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: completed ? color : Colors.grey,
            ),
          ),
          Text(
            step,
            style: TextStyle(
              fontSize: 8,
              color: completed ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
                final timestamp = activity['timestamp'] as DateTime?;
                final timeString = timestamp != null
                    ? DateFormat('MMM dd, HH:mm').format(timestamp)
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
                                activity['timestamp'] as DateTime?;
                            final timeString = timestamp != null
                                ? DateFormat('MMM dd, HH:mm').format(timestamp)
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

  void _setQuickDateRange(String range) {
    final now = DateTime.now();
    setState(() {
      selectedEndDate = now;
      switch (range) {
        case 'week':
          selectedStartDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          selectedStartDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'year':
          selectedStartDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          selectedStartDate = now.subtract(const Duration(days: 30));
      }
    });
    // Automatically reload analytics with new date range
    _loadAnalytics();
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

  Widget _buildFinancialTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial Overview Header
          Row(
            children: [
              Icon(Icons.attach_money, color: Colors.green, size: 28),
              const SizedBox(width: 8),
              Text(
                'Financial Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadFinancialData,
                tooltip: 'Refresh Financial Data',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Revenue Metrics Cards
          _buildRevenueMetrics(),
          const SizedBox(height: 20),

          // Payment Statistics
          _buildPaymentStatistics(),
          const SizedBox(height: 20),

          // Revenue vs Expenses Chart
          _buildFinancialTrendsChart(),
          const SizedBox(height: 20),

          // Expense Breakdown
          _buildExpenseBreakdown(),
          const SizedBox(height: 20),

          // Financial Insights
          _buildFinancialInsights(),
        ],
      ),
    );
  }

  Widget _buildRevenueMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Metrics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinancialCard(
                'Total Revenue',
                '₦${_formatCurrency(revenueStats['total_revenue'] ?? 0)}',
                Icons.trending_up,
                Colors.green,
                '+12.5%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinancialCard(
                'Net Revenue',
                '₦${_formatCurrency(revenueStats['net_revenue'] ?? 0)}',
                Icons.account_balance,
                Colors.blue,
                '+8.3%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinancialCard(
                'Avg Transaction',
                '₦${_formatCurrency(revenueStats['average_transaction'] ?? 0)}',
                Icons.payment,
                Colors.orange,
                '+5.1%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinancialCard(
                'Total Deposits',
                '₦${_formatCurrency(revenueStats['total_deposits'] ?? 0)}',
                Icons.add_circle,
                Colors.teal,
                '+15.2%',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentStatistics() {
    final successRate = paymentStats['success_rate'] ?? 0;
    final total = paymentStats['total_transactions'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Payment Analytics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$successRate%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text('Success Rate'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$total',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text('Total Transactions'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentStatusCard(
                    'Successful',
                    paymentStats['successful_payments'] ?? 0,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentStatusCard(
                    'Pending',
                    paymentStats['pending_payments'] ?? 0,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPaymentStatusCard(
                    'Failed',
                    paymentStats['failed_payments'] ?? 0,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialTrendsChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Revenue vs Expenses Trend',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Financial trends chart will be displayed here',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
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

  Widget _buildExpenseBreakdown() {
    final totalExpenses = expenseStats.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Expense Breakdown',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '₦${_formatCurrency(totalExpenses)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Text('Total Expenses'),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: expenseStats.entries.map((entry) {
                      final percentage = totalExpenses > 0
                          ? (entry.value / totalExpenses * 100)
                          : 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getExpenseColor(entry.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatExpenseCategory(entry.key),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInsights() {
    final revenue = revenueStats['total_revenue'] ?? 0;
    final expenses = expenseStats.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final profit = revenue - expenses;
    final profitMargin = revenue > 0 ? (profit / revenue * 100) : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Financial Insights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInsightCard(
              'Profit Margin',
              '${profitMargin.toStringAsFixed(1)}%',
              profitMargin > 20
                  ? 'Excellent profit margin'
                  : profitMargin > 10
                  ? 'Good profit margin'
                  : 'Consider cost optimization',
              profitMargin > 20
                  ? Colors.green
                  : profitMargin > 10
                  ? Colors.orange
                  : Colors.red,
              Icons.trending_up,
            ),
            _buildInsightCard(
              'Net Profit',
              '₦${_formatCurrency(profit)}',
              profit > 0 ? 'Profitable operations' : 'Revenue below expenses',
              profit > 0 ? Colors.green : Colors.red,
              profit > 0 ? Icons.check_circle : Icons.warning,
            ),
            _buildInsightCard(
              'Monthly Growth',
              '+12.5%',
              'Revenue growing consistently',
              Colors.blue,
              Icons.show_chart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trend.startsWith('+')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trend.startsWith('+') ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusCard(String status, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    String title,
    String value,
    String description,
    Color color,
    IconData icon,
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  String _formatExpenseCategory(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getExpenseColor(String category) {
    switch (category) {
      case 'operational_costs':
        return Colors.blue;
      case 'staff_salaries':
        return Colors.green;
      case 'infrastructure':
        return Colors.orange;
      case 'marketing':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportCSVData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV export functionality coming soon...')),
    );

    // Implement CSV export functionality
  }

  Widget _buildTrainingEngagementActions() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: Colors.indigo[700]),
                const SizedBox(width: 8),
                Text(
                  'Training Engagement Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ADMIN TOOLS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Monitor individual user training engagement and identify inactive accounts',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Quick Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildQuickTrainingStat(
                    'CHW Engagement',
                    'View individual CHW training progress',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickTrainingStat(
                    'Doctor Engagement',
                    'Track doctor training participation',
                    Icons.local_hospital,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickTrainingStat(
                    'Inactive Users',
                    'Identify redundant accounts',
                    Icons.person_off,
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AdminTrainingEngagementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics, size: 18),
                    label: const Text('View Detailed Analytics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AdminTrainingEngagementScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.warning, size: 18),
                  label: const Text('Inactive Users'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTrainingStat(
    String title,
    String subtitle,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
