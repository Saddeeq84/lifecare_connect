// Facility Subscription Management Screen
// Manages facility subscription status, automatic payments, and payment history

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FacilitySubscriptionScreen extends StatefulWidget {
  const FacilitySubscriptionScreen({super.key});

  @override
  State<FacilitySubscriptionScreen> createState() =>
      _FacilitySubscriptionScreenState();
}

class _FacilitySubscriptionScreenState extends State<FacilitySubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _subscriptionData;
  List<Map<String, dynamic>> _paymentHistory = [];
  List<Map<String, dynamic>> _availablePlans = [];
  Map<String, dynamic>? _currentPlan;
  double _monthlyEarnings = 0.0;
  DateTime? _nextPaymentDate;
  bool _subscriptionActive = false;
  int _daysUntilRenewal = 0;
  int _currentTransactionCount = 0;
  int _currentStaffCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSubscriptionData();
    _loadAvailablePlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // User not authenticated - shouldn't happen for subscription screen
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please log in as facility owner to access subscriptions',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Load subscription data
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(user.uid)
          .get();

      if (subscriptionDoc.exists) {
        _subscriptionData = subscriptionDoc.data();
        _subscriptionActive = _subscriptionData?['status'] == 'active';

        // Load current plan details
        final planId = _subscriptionData?['planId'] as String?;
        if (planId != null) {
          final planDoc = await FirebaseFirestore.instance
              .collection('subscription_plans')
              .doc(planId)
              .get();
          if (planDoc.exists) {
            _currentPlan = {'id': planDoc.id, ...planDoc.data()!};
          }
        }

        if (_subscriptionData?['nextPaymentDate'] != null) {
          _nextPaymentDate =
              (_subscriptionData?['nextPaymentDate'] as Timestamp).toDate();
          _daysUntilRenewal = _nextPaymentDate!
              .difference(DateTime.now())
              .inDays;
        }
      } else {
        // Create initial subscription document (legacy support)
        await _createInitialSubscription();
      }

      // Load payment history
      final paymentHistoryQuery = await FirebaseFirestore.instance
          .collection('subscription_payments')
          .where('facilityId', isEqualTo: user.uid)
          .orderBy('paymentDate', descending: true)
          .limit(50)
          .get();

      _paymentHistory = paymentHistoryQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Calculate monthly earnings (last 30 days)
      await _calculateMonthlyEarnings();

      // Load usage stats
      await _loadUsageStats();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load subscription data');
    }
  }

  Future<void> _loadAvailablePlans() async {
    try {
      final plansQuery = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .where('isActive', isEqualTo: true)
          .orderBy('monthlyFee')
          .get();

      _availablePlans = plansQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error loading plans: $e');
    }
  }

  Future<void> _loadUsageStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Count transactions this month (wrapped in its own try-catch)
    try {
      final firstDayOfMonth = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('facilityId', isEqualTo: user.uid)
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(firstDayOfMonth),
          )
          .get();

      _currentTransactionCount = transactionsQuery.docs.length;
    } catch (e) {
      print('Error loading transaction count: $e');
      _currentTransactionCount = 0; // Default to 0 on error
    }

    // Count staff accounts (separate try-catch so it runs even if transactions fail)
    try {
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users') // Changed from 'facilities' to 'users'
          .doc(user.uid)
          .get();

      print('📊 DEBUG: facilityDoc exists: ${facilityDoc.exists}');

      if (facilityDoc.exists) {
        final data = facilityDoc.data();
        print('📊 DEBUG: Facility data: $data');

        // Try multiple possible field names for facility name
        final facilityName =
            (data?['name'] ??
                    data?['facilityName'] ??
                    data?['facility_name'] ??
                    '')
                as String;

        print('📊 DEBUG: Extracted facility name: "$facilityName"');

        if (facilityName.isNotEmpty) {
          final staffCollection =
              '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';
          print('📊 DEBUG: Querying collection: $staffCollection');

          final staffQuery = await FirebaseFirestore.instance
              .collection(staffCollection)
              .get();

          print('📊 DEBUG: Staff count found: ${staffQuery.docs.length}');
          _currentStaffCount = staffQuery.docs.length;
        } else {
          print('❌ DEBUG: Facility name is empty!');
        }
      } else {
        print('❌ DEBUG: Facility document does not exist for uid: ${user.uid}');
      }
    } catch (e) {
      print('❌ Error loading staff count: $e');
    }
  }

  Future<void> _createInitialSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final nextPayment = DateTime(now.year, now.month + 1, now.day);

    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(user.uid)
        .set({
          'facilityId': user.uid,
          'status': 'active',
          'subscriptionRate': 2.5, // 2.5% rate
          'createdAt': FieldValue.serverTimestamp(),
          'nextPaymentDate': Timestamp.fromDate(nextPayment),
          'lastPaymentDate': null,
          'warningsIssued': 0,
          'totalPaid': 0.0,
        });

    _subscriptionData = {
      'facilityId': user.uid,
      'status': 'active',
      'subscriptionRate': 2.5,
      'nextPaymentDate': Timestamp.fromDate(nextPayment),
      'lastPaymentDate': null,
      'warningsIssued': 0,
      'totalPaid': 0.0,
    };

    _subscriptionActive = true;
    _nextPaymentDate = nextPayment;
    _daysUntilRenewal = nextPayment.difference(DateTime.now()).inDays;
  }

  Future<void> _calculateMonthlyEarnings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Calculate earnings from consultations, treatments, etc.
    final earningsQuery = await FirebaseFirestore.instance
        .collection('transactions')
        .where('facilityId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'earning')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    double totalEarnings = 0.0;
    for (final doc in earningsQuery.docs) {
      final data = doc.data();
      totalEarnings += (data['amount'] as num?)?.toDouble() ?? 0.0;
    }

    _monthlyEarnings = totalEarnings;
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildSubscriptionStatus() {
    final planName = _currentPlan?['name'] as String? ?? 'Legacy Plan';
    final monthlyFee = (_currentPlan?['monthlyFee'] as num?)?.toInt() ?? 0;
    final transactionFee =
        (_currentPlan?['transactionFeePercent'] as num?)?.toDouble() ?? 2.5;
    final maxTransactions = (_currentPlan?['maxTransactionsPerMonth'] as num?)
        ?.toInt();
    final maxStaff = (_currentPlan?['maxStaff'] as num?)?.toInt();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Current Plan Card
          Card(
            elevation: 4,
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.teal.shade700, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Plan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              planName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_currentPlan != null)
                        ElevatedButton.icon(
                          onPressed: () => _tabController.animateTo(3),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          label: const Text('Upgrade'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (monthlyFee > 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Fee',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '₦${NumberFormat('#,##0').format(monthlyFee)}',
                                style: const TextStyle(
                                  fontSize: 20,
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
                                'Transaction Fee',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '$transactionFee%',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Usage Stats
                  if (maxTransactions != null || maxStaff != null) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Usage This Month',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (maxTransactions != null)
                      _buildUsageIndicator(
                        'Transactions',
                        _currentTransactionCount,
                        maxTransactions,
                        Icons.receipt_long,
                      ),
                    if (maxStaff != null) ...[
                      const SizedBox(height: 8),
                      _buildUsageIndicator(
                        'Staff Accounts',
                        _currentStaffCount,
                        maxStaff,
                        Icons.people,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subscription Status Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _subscriptionActive
                            ? Icons.check_circle
                            : Icons.warning,
                        color: _subscriptionActive
                            ? Colors.green
                            : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subscription Status',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              _subscriptionActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: _subscriptionActive
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (_nextPaymentDate != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Next Payment Date',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(_nextPaymentDate!),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _daysUntilRenewal <= 7
                                ? Colors.red.shade100
                                : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_daysUntilRenewal days left',
                            style: TextStyle(
                              color: _daysUntilRenewal <= 7
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Warning if subscription is due soon
                  if (_daysUntilRenewal <= 7 && _daysUntilRenewal > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Subscription renewal approaching! Ensure sufficient wallet balance.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Monthly Earnings and Subscription Fee
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          color: Colors.green,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Monthly Earnings',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${NumberFormat('#,##0.00').format(_monthlyEarnings)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.payment, color: Colors.blue, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Subscription Fee ($transactionFee%)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₦${NumberFormat('#,##0.00').format(_monthlyEarnings * (transactionFee / 100))}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageIndicator(
    String label,
    int current,
    int max,
    IconData icon,
  ) {
    final percentage = (current / max * 100).clamp(0, 100);
    final isNearLimit = percentage >= 80;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            Text(
              '$label: $current / $max',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isNearLimit ? Colors.red : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: current / max,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            isNearLimit ? Colors.red : Colors.teal,
          ),
        ),
        if (isNearLimit) ...[
          const SizedBox(height: 4),
          Text(
            'Approaching limit! Consider upgrading your plan.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.red.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvailablePlans() {
    if (_availablePlans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No subscription plans available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availablePlans.length,
      itemBuilder: (context, index) {
        final plan = _availablePlans[index];
        final isCurrentPlan = _currentPlan?['id'] == plan['id'];
        return _buildPlanCard(plan, isCurrentPlan);
      },
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, bool isCurrentPlan) {
    final name = plan['name'] as String;
    final description = plan['description'] as String? ?? '';
    final monthlyFee = (plan['monthlyFee'] as num).toInt();
    final transactionFee = (plan['transactionFeePercent'] as num).toDouble();
    final maxTransactions = (plan['maxTransactionsPerMonth'] as num?)?.toInt();
    final maxStaff = (plan['maxStaff'] as num?)?.toInt();
    final features = List<String>.from(plan['features'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCurrentPlan ? 8 : 3,
      color: isCurrentPlan ? Colors.teal.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentPlan
            ? BorderSide(color: Colors.teal.shade700, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentPlan) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Fee',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦${NumberFormat('#,##0').format(monthlyFee)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
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
                        'Transaction Fee',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$transactionFee%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (maxTransactions != null || maxStaff != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (maxTransactions != null)
                    Chip(
                      avatar: const Icon(Icons.receipt_long, size: 16),
                      label: Text(
                        '${NumberFormat('#,##0').format(maxTransactions)} transactions/month',
                      ),
                      backgroundColor: Colors.blue.shade50,
                    ),
                  if (maxStaff != null)
                    Chip(
                      avatar: const Icon(Icons.people, size: 16),
                      label: Text('$maxStaff staff accounts'),
                      backgroundColor: Colors.green.shade50,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (maxTransactions == null && maxStaff == null) ...[
              Chip(
                avatar: const Icon(Icons.all_inclusive, size: 16),
                label: const Text('Unlimited transactions & staff'),
                backgroundColor: Colors.purple.shade50,
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features
                  .map(
                    (feature) => Chip(
                      label: Text(
                        _formatFeatureName(feature),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.teal.shade50,
                    ),
                  )
                  .toList(),
            ),
            if (!isCurrentPlan) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showUpgradeDialog(plan),
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Select This Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFeatureName(String feature) {
    return feature
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Future<void> _showUpgradeDialog(Map<String, dynamic> newPlan) async {
    final planName = newPlan['name'] as String;
    final monthlyFee = (newPlan['monthlyFee'] as num).toInt();
    final currentPlanName = _currentPlan?['name'] as String? ?? 'current plan';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Subscription Plan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Switch from "$currentPlanName" to "$planName"?'),
            const SizedBox(height: 16),
            Text(
              'New monthly fee: ₦${NumberFormat('#,##0').format(monthlyFee)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your subscription will be updated immediately. '
              'The new plan fees will apply from your next billing cycle.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _changePlan(newPlan['id']);
    }
  }

  Future<void> _changePlan(String newPlanId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final oldPlanName = _currentPlan?['name'] as String? ?? 'Unknown';
      final newPlan = _availablePlans.firstWhere((p) => p['id'] == newPlanId);
      final newPlanName = newPlan['name'] as String;

      // Update subscription with new plan
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(user.uid)
          .update({
            'planId': newPlanId,
            'updatedAt': FieldValue.serverTimestamp(),
            'planChangedAt': FieldValue.serverTimestamp(),
          });

      // Log plan change in payment history for audit trail
      await FirebaseFirestore.instance.collection('subscription_payments').add({
        'userId': user.uid,
        'type': 'plan_change',
        'description': 'Plan changed from "$oldPlanName" to "$newPlanName"',
        'amount': 0,
        'oldPlanId': _currentPlan?['id'],
        'newPlanId': newPlanId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackBar('Subscription plan updated successfully');
      await _loadSubscriptionData();
      await _loadAvailablePlans();
      setState(() {});
    } catch (e) {
      _showErrorSnackBar('Failed to update subscription plan');
    }
  }

  Widget _buildPaymentHistory() {
    return _paymentHistory.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No payment history yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _paymentHistory.length,
            itemBuilder: (context, index) {
              final payment = _paymentHistory[index];
              final paymentDate = (payment['paymentDate'] as Timestamp)
                  .toDate();
              final amount = payment['amount'] as num;
              final status = payment['status'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: status == 'completed'
                        ? Colors.green.shade100
                        : status == 'failed'
                        ? Colors.red.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                      status == 'completed'
                          ? Icons.check
                          : status == 'failed'
                          ? Icons.error
                          : Icons.schedule,
                      color: status == 'completed'
                          ? Colors.green
                          : status == 'failed'
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                  title: Text(
                    '₦${NumberFormat('#,##0.00').format(amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(paymentDate),
                      ),
                      Text(
                        'Status: ${status.toUpperCase()}',
                        style: TextStyle(
                          color: status == 'completed'
                              ? Colors.green
                              : status == 'failed'
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: status == 'completed'
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : status == 'failed'
                      ? const Icon(Icons.error, color: Colors.red)
                      : const Icon(Icons.schedule, color: Colors.orange),
                ),
              );
            },
          );
  }

  Widget _buildSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Automatic Payment Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatic Payment Settings',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Enable Auto-Payment'),
                    subtitle: const Text(
                      'Automatically deduct subscription fees from wallet',
                    ),
                    value: _subscriptionActive,
                    onChanged: (value) {
                      _updateSubscriptionStatus(value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: const Text('How it works'),
                    subtitle: const Text(
                      'Every 30 days, 2.5% of your monthly earnings will be automatically deducted from your wallet and transferred to the main admin.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Subscription Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subscription Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ListTile(
                    leading: Icon(Icons.percent, color: Colors.green),
                    title: Text('Subscription Rate'),
                    subtitle: Text('2.5% of monthly earnings'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.schedule, color: Colors.blue),
                    title: Text('Payment Frequency'),
                    subtitle: Text('Every 30 calendar days'),
                  ),
                  const ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.orange,
                    ),
                    title: Text('Payment Method'),
                    subtitle: Text('Automatic deduction from facility wallet'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.warning, color: Colors.red),
                    title: Text('Low Balance Warning'),
                    subtitle: Text(
                      'You will be notified 7 days before payment if wallet balance is insufficient',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSubscriptionStatus(bool isActive) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(user.uid)
          .update({
            'status': isActive ? 'active' : 'inactive',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _subscriptionActive = isActive;
        if (_subscriptionData != null) {
          _subscriptionData!['status'] = isActive ? 'active' : 'inactive';
        }
      });

      _showSuccessSnackBar(
        isActive
            ? 'Auto-payment enabled successfully'
            : 'Auto-payment disabled successfully',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to update subscription settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Status'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
            Tab(icon: Icon(Icons.credit_card), text: 'Plans'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSubscriptionStatus(),
                _buildPaymentHistory(),
                _buildSettings(),
                _buildAvailablePlans(),
              ],
            ),
    );
  }
}
