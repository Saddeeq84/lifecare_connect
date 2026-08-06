// Admin Subscription Plans Management Screen
// Allows main admin to create, edit, and manage subscription tiers/plans
// This enables dynamic pricing without code changes

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminSubscriptionPlansScreen extends StatefulWidget {
  const AdminSubscriptionPlansScreen({super.key});

  @override
  State<AdminSubscriptionPlansScreen> createState() =>
      _AdminSubscriptionPlansScreenState();
}

class _AdminSubscriptionPlansScreenState
    extends State<AdminSubscriptionPlansScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      setState(() => _isLoading = true);

      final plansQuery = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .orderBy('monthlyFee')
          .get();

      _plans = plansQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading plans: $e');
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load subscription plans');
    }
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

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name'] as String;
    final description = plan['description'] as String? ?? '';
    final monthlyFee = plan['monthlyFee'] as int;
    final transactionFee = plan['transactionFeePercent'] as double;
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
                    child: _buildInfoChip(
                      'Max Transactions',
                      '${NumberFormat('#,##0').format(maxTransactions)}/month',
                      Icons.receipt_long,
                    ),
                  ),
                if (maxTransactions != null && maxStaff != null)
                  const SizedBox(width: 8),
                if (maxStaff != null)
                  Expanded(
                    child: _buildInfoChip(
                      'Max Staff',
                      '$maxStaff accounts',
                      Icons.people,
                    ),
                  ),
                if (maxTransactions == null && maxStaff == null)
                  _buildInfoChip(
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

  Widget _buildInfoChip(String label, String value, IconData icon) {
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
        title: const Text('Subscription Plans'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
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
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, index) => _buildPlanCard(_plans[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlanDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Create Plan'),
        backgroundColor: Colors.teal.shade700,
      ),
    );
  }
}
