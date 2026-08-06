// Admin Subscription Management Screen
// Allows main admin to view all facilities, subscription status, and manage subscription plans

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminSubscriptionManagementScreen extends StatefulWidget {
  const AdminSubscriptionManagementScreen({super.key});

  @override
  State<AdminSubscriptionManagementScreen> createState() =>
      _AdminSubscriptionManagementScreenState();
}

class _AdminSubscriptionManagementScreenState
    extends State<AdminSubscriptionManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _facilities = [];
  Map<String, Map<String, dynamic>> _subscriptions = {};
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  double _totalMonthlyRevenue = 0.0;
  int _activeFacilities = 0;
  int _inactiveFacilities = 0;
  int _overdueSubscriptions = 0;

  // For Plans tab
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFacilitiesData();
    _loadPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilitiesData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load all facilities from users collection where role is 'facility'
      final facilitiesQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .get();

      _facilities = facilitiesQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Calculate facility statistics based on approval status
      _activeFacilities = _facilities
          .where((f) => f['isApproved'] == true)
          .length;
      _inactiveFacilities = _facilities
          .where((f) => f['isApproved'] != true)
          .length;

      // Load subscription data for each facility
      final subscriptionsQuery = await FirebaseFirestore.instance
          .collection('subscriptions')
          .get();

      _subscriptions = {};
      _totalMonthlyRevenue = 0.0;
      _overdueSubscriptions = 0;

      for (final doc in subscriptionsQuery.docs) {
        final data = doc.data();
        _subscriptions[doc.id] = data;

        // Check if subscription is overdue
        final nextPaymentDate = data['nextPaymentDate'] as Timestamp?;
        if (nextPaymentDate != null) {
          final daysUntilPayment = nextPaymentDate
              .toDate()
              .difference(DateTime.now())
              .inDays;
          if (daysUntilPayment < 0) {
            _overdueSubscriptions++;
          }
        }

        // Calculate monthly revenue (5% of facility earnings)
        await _calculateFacilityRevenue(doc.id);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading facilities data: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load facilities data');
    }
  }

  Future<void> _calculateFacilityRevenue(String facilityId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final earningsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('facilityId', isEqualTo: facilityId)
          .where('type', isEqualTo: 'earning')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      double facilityEarnings = 0.0;
      for (final doc in earningsQuery.docs) {
        final data = doc.data();
        facilityEarnings += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // 5% of facility earnings
      _totalMonthlyRevenue += facilityEarnings * 0.05;
    } catch (e) {
      print('Error calculating facility revenue for $facilityId: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredFacilities {
    List<Map<String, dynamic>> filtered = _facilities;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((facility) {
        final name = (facility['name'] as String? ?? '').toLowerCase();
        final email = (facility['email'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((facility) {
        final subscription = _subscriptions[facility['id']];

        switch (_selectedFilter) {
          case 'active':
            // Active = approved facilities
            return facility['isApproved'] == true;
          case 'inactive':
            // Inactive = not approved (pending or rejected)
            return facility['isApproved'] != true;
          case 'overdue':
            if (subscription == null) return false;
            final nextPaymentDate =
                subscription['nextPaymentDate'] as Timestamp?;
            if (nextPaymentDate == null) return false;
            return nextPaymentDate.toDate().isBefore(DateTime.now());
          case 'warning':
            if (subscription == null) return false;
            final nextPaymentDate =
                subscription['nextPaymentDate'] as Timestamp?;
            if (nextPaymentDate == null) return false;
            final daysUntilPayment = nextPaymentDate
                .toDate()
                .difference(DateTime.now())
                .inDays;
            return daysUntilPayment <= 7 && daysUntilPayment >= 0;
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business,
                          color: Colors.green.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_activeFacilities',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const Text(
                          'Approved Facilities',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          color: Colors.red.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_inactiveFacilities',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const Text(
                          'Pending/Inactive',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.orange.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_overdueSubscriptions',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const Text(
                          'Overdue Payments',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.attach_money,
                          color: Colors.blue.shade700,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₦${NumberFormat('#,##0').format(_totalMonthlyRevenue)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Text(
                          'Monthly Revenue',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Activities
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Subscription Activities',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('subscription_payments')
                        .orderBy('paymentDate', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final payments = snapshot.data!.docs;
                      if (payments.isEmpty) {
                        return const Center(
                          child: Text(
                            'No recent activities',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final payment =
                              payments[index].data() as Map<String, dynamic>;
                          final facilityId = payment['facilityId'] as String;
                          final facility = _facilities.firstWhere(
                            (f) => f['id'] == facilityId,
                            orElse: () => {'name': 'Unknown Facility'},
                          );
                          final amount = payment['amount'] as num;
                          final status = payment['status'] as String;
                          final paymentDate =
                              (payment['paymentDate'] as Timestamp).toDate();

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: status == 'completed'
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              child: Icon(
                                status == 'completed'
                                    ? Icons.check
                                    : Icons.error,
                                color: status == 'completed'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            title: Text(facility['name'] ?? 'Unknown'),
                            subtitle: Text(
                              '₦${NumberFormat('#,##0.00').format(amount)} - ${DateFormat('MMM dd, yyyy').format(paymentDate)}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'completed'
                                    ? Colors.green.shade100
                                    : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'completed'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesTab() {
    return Column(
      children: [
        // Search and Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search facilities...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Facilities', 'all'),
                    _buildFilterChip('Approved', 'active'),
                    _buildFilterChip('Pending/Rejected', 'inactive'),
                    _buildFilterChip('Payment Overdue', 'overdue'),
                    _buildFilterChip('Payment Due Soon', 'warning'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Facilities List
        Expanded(
          child: _filteredFacilities.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.business_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No facilities found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredFacilities.length,
                  itemBuilder: (context, index) {
                    final facility = _filteredFacilities[index];
                    final subscription = _subscriptions[facility['id']];
                    return _buildFacilityCard(facility, subscription);
                  },
                ),
        ),
      ],
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
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
        },
        selectedColor: Colors.teal.shade100,
        checkmarkColor: Colors.teal.shade700,
      ),
    );
  }

  Widget _buildFacilityCard(
    Map<String, dynamic> facility,
    Map<String, dynamic>? subscription,
  ) {
    final facilityName = facility['name'] as String? ?? 'Unknown';
    final facilityType = facility['type'] as String? ?? 'Unknown';
    final email = facility['email'] as String? ?? '';
    final isSubscriptionActive = subscription?['isActive'] == true;
    final isFacilityApproved = facility['isApproved'] == true;

    DateTime? nextPaymentDate;
    int daysUntilPayment = 0;
    if (subscription?['nextPaymentDate'] != null) {
      nextPaymentDate = (subscription!['nextPaymentDate'] as Timestamp)
          .toDate();
      daysUntilPayment = nextPaymentDate.difference(DateTime.now()).inDays;
    }

    // Status is based on facility approval, not subscription payment
    Color statusColor = Colors.grey;
    String statusText = 'Pending Approval';

    if (isFacilityApproved) {
      statusColor = Colors.green;
      statusText = 'Active';
    } else if (facility['isRejected'] == true) {
      statusColor = Colors.red;
      statusText = 'Rejected';
    } else {
      statusColor = Colors.orange;
      statusText = 'Pending';
    }

    // Separate subscription payment status
    Color subscriptionColor = Colors.grey;
    String subscriptionText = 'No Subscription';
    if (subscription != null) {
      if (daysUntilPayment < 0) {
        subscriptionColor = Colors.red;
        subscriptionText = 'Payment Overdue';
      } else if (daysUntilPayment <= 7) {
        subscriptionColor = Colors.orange;
        subscriptionText = 'Payment Due Soon';
      } else if (isSubscriptionActive) {
        subscriptionColor = Colors.green;
        subscriptionText = 'Subscription Active';
      } else {
        subscriptionColor = Colors.red;
        subscriptionText = 'Subscription Inactive';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(Icons.business, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facilityName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$facilityType • $email',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: subscriptionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: subscriptionColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              subscriptionText,
                              style: TextStyle(
                                color: subscriptionColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (nextPaymentDate != null)
                        Text(
                          'Next payment: ${DateFormat('MMM dd, yyyy').format(nextPaymentDate)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Switch(
                      value: isFacilityApproved,
                      onChanged: (value) {
                        _toggleFacilityStatus(facility['id'], value);
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
            if (daysUntilPayment <= 7 && daysUntilPayment >= 0) ...[
              const SizedBox(height: 12),
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
                    Icon(
                      Icons.warning,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment due in $daysUntilPayment day${daysUntilPayment == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (daysUntilPayment < 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment overdue by ${-daysUntilPayment} day${-daysUntilPayment == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFacilityStatus(String facilityId, bool isApproved) async {
    try {
      // Update facility approval status in users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(facilityId)
          .update({
            'isApproved': isApproved,
            'isRejected': false, // Clear rejection if re-approving
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update local state
      setState(() {
        final facilityIndex = _facilities.indexWhere(
          (f) => f['id'] == facilityId,
        );
        if (facilityIndex != -1) {
          _facilities[facilityIndex]['isApproved'] = isApproved;
          _facilities[facilityIndex]['isRejected'] = false;
        }
      });

      _showSuccessSnackBar(
        isApproved
            ? 'Facility approved and activated successfully'
            : 'Facility deactivated successfully',
      );
    } catch (e) {
      print('Error toggling facility status: $e');
      _showErrorSnackBar('Failed to update facility status');
    }
  }

  // ===== SUBSCRIPTION PLANS MANAGEMENT METHODS =====

  Future<void> _loadPlans() async {
    try {
      final plansQuery = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .orderBy('monthlyFee')
          .get();

      setState(() {
        _plans = plansQuery.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      });
    } catch (e) {
      print('Error loading plans: $e');
      _showErrorSnackBar('Failed to load subscription plans');
    }
  }

  Future<void> _showPlanDialog({Map<String, dynamic>? plan}) async {
    final isEdit = plan != null;
    final nameController = TextEditingController(text: plan?['name'] ?? '');
    final descriptionController = TextEditingController(
      text: plan?['description'] ?? '',
    );
    final monthlyFeeController = TextEditingController(
      text: plan?['monthlyFee']?.toString() ?? '',
    );
    final transactionFeeController = TextEditingController(
      text: plan?['transactionFeePercent']?.toString() ?? '2.5',
    );
    final maxTransactionsController = TextEditingController(
      text: plan?['maxTransactionsPerMonth']?.toString() ?? '',
    );
    final maxStaffController = TextEditingController(
      text: plan?['maxStaff']?.toString() ?? '',
    );

    // Features toggles
    bool hasInventory = plan?['features']?.contains('inventory') ?? true;
    bool hasAnalytics = plan?['features']?.contains('analytics') ?? true;
    bool hasReports = plan?['features']?.contains('reports') ?? true;
    bool hasStaffManagement =
        plan?['features']?.contains('staff_management') ?? true;
    bool hasPatientRecords =
        plan?['features']?.contains('patient_records') ?? true;
    bool hasMessaging = plan?['features']?.contains('messaging') ?? true;
    bool hasAppointments = plan?['features']?.contains('appointments') ?? true;
    bool hasBilling = plan?['features']?.contains('billing') ?? true;
    bool hasApiAccess = plan?['features']?.contains('api_access') ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Subscription Plan' : 'Create New Plan'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Plan Name *',
                      hintText: 'e.g., Starter, Professional, Enterprise',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of the plan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: monthlyFeeController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Fee (₦) *',
                      hintText: '10000',
                      border: OutlineInputBorder(),
                      prefixText: '₦ ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: transactionFeeController,
                    decoration: const InputDecoration(
                      labelText: 'Transaction Fee (%) *',
                      hintText: '2.5',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: maxTransactionsController,
                    decoration: const InputDecoration(
                      labelText: 'Max Transactions/Month',
                      hintText: '5000 (leave empty for unlimited)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: maxStaffController,
                    decoration: const InputDecoration(
                      labelText: 'Max Staff Accounts',
                      hintText: '5 (leave empty for unlimited)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Features Included',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Inventory Management'),
                    value: hasInventory,
                    onChanged: (val) =>
                        setDialogState(() => hasInventory = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Analytics Dashboard'),
                    value: hasAnalytics,
                    onChanged: (val) =>
                        setDialogState(() => hasAnalytics = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Reports & Export'),
                    value: hasReports,
                    onChanged: (val) =>
                        setDialogState(() => hasReports = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Staff Management'),
                    value: hasStaffManagement,
                    onChanged: (val) =>
                        setDialogState(() => hasStaffManagement = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Patient Records'),
                    value: hasPatientRecords,
                    onChanged: (val) =>
                        setDialogState(() => hasPatientRecords = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Messaging System'),
                    value: hasMessaging,
                    onChanged: (val) =>
                        setDialogState(() => hasMessaging = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Appointments'),
                    value: hasAppointments,
                    onChanged: (val) =>
                        setDialogState(() => hasAppointments = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Billing & Payments'),
                    value: hasBilling,
                    onChanged: (val) =>
                        setDialogState(() => hasBilling = val ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('API Access'),
                    value: hasApiAccess,
                    onChanged: (val) =>
                        setDialogState(() => hasApiAccess = val ?? false),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    monthlyFeeController.text.trim().isEmpty ||
                    transactionFeeController.text.trim().isEmpty) {
                  _showErrorSnackBar('Please fill all required fields');
                  return;
                }

                final features = <String>[];
                if (hasInventory) features.add('inventory');
                if (hasAnalytics) features.add('analytics');
                if (hasReports) features.add('reports');
                if (hasStaffManagement) features.add('staff_management');
                if (hasPatientRecords) features.add('patient_records');
                if (hasMessaging) features.add('messaging');
                if (hasAppointments) features.add('appointments');
                if (hasBilling) features.add('billing');
                if (hasApiAccess) features.add('api_access');

                final planData = {
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'monthlyFee': int.parse(monthlyFeeController.text.trim()),
                  'transactionFeePercent': double.parse(
                    transactionFeeController.text.trim(),
                  ),
                  'maxTransactionsPerMonth':
                      maxTransactionsController.text.trim().isEmpty
                      ? null
                      : int.parse(maxTransactionsController.text.trim()),
                  'maxStaff': maxStaffController.text.trim().isEmpty
                      ? null
                      : int.parse(maxStaffController.text.trim()),
                  'features': features,
                  'isActive': true,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                if (!isEdit) {
                  planData['createdAt'] = FieldValue.serverTimestamp();
                }

                try {
                  if (isEdit) {
                    await FirebaseFirestore.instance
                        .collection('subscription_plans')
                        .doc(plan['id'])
                        .update(planData);
                    _showSuccessSnackBar('Plan updated successfully');
                  } else {
                    await FirebaseFirestore.instance
                        .collection('subscription_plans')
                        .add(planData);
                    _showSuccessSnackBar('Plan created successfully');
                  }
                  Navigator.pop(context);
                  _loadPlans();
                } catch (e) {
                  _showErrorSnackBar('Failed to save plan');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Update Plan' : 'Create Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePlan(String planId, String planName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
          'Are you sure you want to delete "$planName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('subscription_plans')
            .doc(planId)
            .delete();
        _showSuccessSnackBar('Plan deleted successfully');
        _loadPlans();
      } catch (e) {
        _showErrorSnackBar('Failed to delete plan');
      }
    }
  }

  Future<void> _togglePlanStatus(String planId, bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('subscription_plans')
          .doc(planId)
          .update({
            'isActive': isActive,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _showSuccessSnackBar(isActive ? 'Plan activated' : 'Plan deactivated');
      _loadPlans();
    } catch (e) {
      _showErrorSnackBar('Failed to update plan status');
    }
  }

  Widget _buildPlansTab() {
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No subscription plans yet',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first plan to get started',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showPlanDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Plan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plans.length + 1, // +1 for create button
      itemBuilder: (context, index) {
        if (index == _plans.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showPlanDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create New Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          );
        }
        return _buildPlanCard(_plans[index]);
      },
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name'] as String;
    final description = plan['description'] as String? ?? '';
    final monthlyFee = plan['monthlyFee'] as int;
    final transactionFee = (plan['transactionFeePercent'] as num).toDouble();
    final maxTransactions = plan['maxTransactionsPerMonth'] as int?;
    final maxStaff = plan['maxStaff'] as int?;
    final features = List<String>.from(plan['features'] ?? []);
    final isActive = plan['isActive'] as bool? ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
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
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showPlanDialog(plan: plan);
                        break;
                      case 'toggle':
                        _togglePlanStatus(plan['id'], !isActive);
                        break;
                      case 'delete':
                        _deletePlan(plan['id'], name);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Plan'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.pause : Icons.play_arrow,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
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
            Row(
              children: [
                if (maxTransactions != null)
                  Expanded(
                    child: _buildPlanInfoChip(
                      'Max Transactions',
                      '${NumberFormat('#,##0').format(maxTransactions)}/month',
                      Icons.receipt_long,
                    ),
                  ),
                if (maxTransactions != null && maxStaff != null)
                  const SizedBox(width: 8),
                if (maxStaff != null)
                  Expanded(
                    child: _buildPlanInfoChip(
                      'Max Staff',
                      '$maxStaff accounts',
                      Icons.people,
                    ),
                  ),
                if (maxTransactions == null && maxStaff == null)
                  _buildPlanInfoChip(
                    'Unlimited',
                    'No restrictions',
                    Icons.all_inclusive,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Features Included:',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFeatureName(String feature) {
    return feature
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
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
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.business), text: 'Facilities'),
            Tab(icon: Icon(Icons.card_membership), text: 'Plans'),
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
                _buildOverviewTab(),
                _buildFacilitiesTab(),
                _buildPlansTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _loadFacilitiesData(); // Refresh data
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        backgroundColor: Colors.teal.shade700,
      ),
    );
  }
}
