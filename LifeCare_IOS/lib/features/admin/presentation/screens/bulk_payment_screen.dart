// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/data/services/message_service.dart';

class BulkPaymentScreen extends StatefulWidget {
  final double adminBalance;

  const BulkPaymentScreen({super.key, required this.adminBalance});

  @override
  State<BulkPaymentScreen> createState() => _BulkPaymentScreenState();
}

class _BulkPaymentScreenState extends State<BulkPaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController();
  final Set<String> _selectedCHWs = {};
  final Set<String> _selectedDoctors = {};
  bool _isProcessing = false;
  bool _selectAllCHWs = false;
  bool _selectAllDoctors = false;
  bool _expandedCHWList = false; // For "View More" functionality
  bool _expandedDoctorList = false; // For "View More" functionality

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _processPayment(String providerType) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedProviders = providerType == 'chw'
        ? _selectedCHWs
        : _selectedDoctors;

    if (selectedProviders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one ${providerType == 'chw' ? 'CHW' : 'Doctor'}',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final totalAmount = amount * selectedProviders.length;
    final remainingBalance = widget.adminBalance - totalAmount;

    if (totalAmount > widget.adminBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Total needed: ₦${totalAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirm payment with detailed breakdown
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Confirm Bulk Payment'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Payment Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      'Provider Type:',
                      providerType == 'chw'
                          ? 'Community Health Workers'
                          : 'Doctors',
                    ),
                    _buildSummaryRow(
                      'Number of Recipients:',
                      '${selectedProviders.length}',
                    ),
                    _buildSummaryRow(
                      'Amount Per Provider:',
                      '₦${amount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Balance Breakdown Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 Balance Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      'Current Admin Balance:',
                      '₦${widget.adminBalance.toStringAsFixed(2)}',
                    ),
                    _buildSummaryRow(
                      'Total Payment Amount:',
                      '₦${totalAmount.toStringAsFixed(2)}',
                      valueColor: Colors.orange.shade700,
                      valueBold: true,
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      'Remaining Balance:',
                      '₦${remainingBalance.toStringAsFixed(2)}',
                      valueColor: remainingBalance < 1000
                          ? Colors.red
                          : Colors.green.shade700,
                      valueBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Warning if balance is low
              if (remainingBalance < 1000) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Your remaining balance will be very low (₦${remainingBalance.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Notification info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.purple,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Each provider will receive:\n• Funds in their wallet\n• In-app notification\n• Conversation message',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Confirm & Send Payment'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    try {
      int successCount = 0;
      int failCount = 0;
      final List<String> failedNames = [];

      // Get all provider details first
      final List<Map<String, dynamic>> providersData = [];
      for (final providerId in selectedProviders) {
        final providerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();

        if (providerDoc.exists) {
          providersData.add({'id': providerId, 'data': providerDoc.data()});
        }
      }

      // Process payments
      for (final providerInfo in providersData) {
        final providerId = providerInfo['id'] as String;
        final providerData = providerInfo['data'] as Map<String, dynamic>;
        final providerName =
            providerData['fullName'] ?? providerData['name'] ?? 'Provider';

        try {
          // Deduct from admin wallet and credit provider wallet in Firestore transaction
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final adminWalletRef = FirebaseFirestore.instance
                .collection('wallets')
                .doc('admin_wallet');
            final providerWalletRef = FirebaseFirestore.instance
                .collection('wallets')
                .doc(providerId);

            // Get current balances
            final adminDoc = await transaction.get(adminWalletRef);
            final providerDoc = await transaction.get(providerWalletRef);

            // Check admin balance
            double adminBalance = 0.0;
            if (adminDoc.exists && adminDoc.data() != null) {
              adminBalance = (adminDoc.data()!['balance'] ?? 0.0).toDouble();
            }

            if (adminBalance < amount) {
              throw Exception('Insufficient admin wallet balance');
            }

            // Get provider balance
            double providerBalance = 0.0;
            if (providerDoc.exists && providerDoc.data() != null) {
              providerBalance = (providerDoc.data()!['balance'] ?? 0.0)
                  .toDouble();
            }

            // Create transactions with current timestamp
            final now = Timestamp.now();
            final adminTx = {
              'type': 'deduct',
              'amount': amount,
              'timestamp': now,
              'description': 'Bonus payment to $providerName',
            };

            final providerTx = {
              'type': 'fund',
              'amount': amount,
              'timestamp': now,
              'description': 'Bonus from Admin',
            };

            // Update admin wallet
            transaction.set(adminWalletRef, {
              'balance': adminBalance - amount,
              'currency': 'NGN',
              'updatedAt': FieldValue.serverTimestamp(),
              'transactions': FieldValue.arrayUnion([adminTx]),
            }, SetOptions(merge: true));

            // Update provider wallet (create if doesn't exist)
            transaction.set(providerWalletRef, {
              'balance': providerBalance + amount,
              'currency': 'NGN',
              'updatedAt': FieldValue.serverTimestamp(),
              'transactions': FieldValue.arrayUnion([providerTx]),
            }, SetOptions(merge: true));
          });

          successCount++;
        } catch (e) {
          print('Error paying $providerName: $e');
          failCount++;
          failedNames.add(providerName);
        }
      }

      // Send broadcast notification to all successful recipients
      if (successCount > 0) {
        await _sendBulkNotification(
          providersData
              .where((p) => !failedNames.contains(p['data']['name']))
              .toList(),
          amount,
          providerType,
        );
      }

      setState(() => _isProcessing = false);

      // Show result
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  successCount > 0 ? Icons.check_circle : Icons.error,
                  color: successCount > 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text('Payment Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Successful: $successCount'),
                if (failCount > 0) ...[
                  Text('❌ Failed: $failCount'),
                  const SizedBox(height: 8),
                  const Text(
                    'Failed payments:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...failedNames.map((name) => Text('• $name')),
                ],
                const SizedBox(height: 16),
                Text(
                  'Total paid: ₦${(successCount * amount).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true); // Return to wallet screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendBulkNotification(
    List<Map<String, dynamic>> providers,
    double amount,
    String providerType,
  ) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc('admin_wallet')
          .get();

      final adminName = adminDoc.exists
          ? (adminDoc.data()?['name'] ?? 'Admin')
          : 'Admin';

      // Create broadcast message
      final broadcastData = {
        'senderId': 'admin_wallet',
        'senderName': adminName,
        'senderRole': 'admin',
        'recipientType': providerType.toLowerCase(),
        'subject': 'Bonus Payment Received',
        'content':
            'You have received a bonus payment of ₦${amount.toStringAsFixed(2)} from the admin. The amount has been credited to your wallet.',
        'type': 'system_notification',
        'priority': 'high',
        'recipients': providers.map((p) => p['id'] as String).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Add to messages collection as broadcast
      await FirebaseFirestore.instance
          .collection('broadcasts')
          .add(broadcastData);

      // Create individual notification messages for each provider
      for (final providerInfo in providers) {
        final providerId = providerInfo['id'] as String;
        final providerData = providerInfo['data'] as Map<String, dynamic>;
        final providerName =
            providerData['fullName'] ?? providerData['name'] ?? 'Provider';

        // Create or get conversation with admin
        final conversationId = await MessageService.createOrGetConversation(
          user1Id: 'admin_wallet',
          user1Name: adminName,
          user1Role: 'admin',
          user2Id: providerId,
          user2Name: providerName,
          user2Role: providerType.toLowerCase(),
        );

        // Send message
        await MessageService.sendMessage(
          conversationId: conversationId,
          senderId: 'admin_wallet',
          senderName: adminName,
          senderRole: 'admin',
          receiverId: providerId,
          receiverName: providerName,
          receiverRole: providerType.toLowerCase(),
          content:
              '💰 You have received a bonus payment of ₦${amount.toStringAsFixed(2)}! The amount has been credited to your wallet.',
          type: 'system',
          priority: 'high',
        );
      }
    } catch (e) {
      print('Error sending bulk notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Bonus Payment'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'CHWs', icon: Icon(Icons.medical_services)),
            Tab(text: 'Doctors', icon: Icon(Icons.local_hospital)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Payment Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Admin Wallet Balance:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const Spacer(),
                    Text(
                      '₦${widget.adminBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Bonus Amount Per Provider (₦)',
                    prefixIcon: const Icon(Icons.money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                if (_amountController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final amount =
                          double.tryParse(_amountController.text) ?? 0;
                      final selectedCount = _tabController.index == 0
                          ? _selectedCHWs.length
                          : _selectedDoctors.length;
                      final total = amount * selectedCount;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Selected: $selectedCount',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Total: ₦${total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: total > widget.adminBalance
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if (total > widget.adminBalance)
                            const Text(
                              'Insufficient balance!',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),

          // Provider List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProviderList('chw'),
                _buildProviderList('doctor'),
              ],
            ),
          ),

          // Pay Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () => _processPayment(
                        _tabController.index == 0 ? 'chw' : 'doctor',
                      ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : 'Pay Selected ${_tabController.index == 0 ? 'CHWs' : 'Doctors'}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderList(String role) {
    // State variable to track if showing all or limited items
    final isExpanded = role == 'chw' ? _expandedCHWList : _expandedDoctorList;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('🔍 [BULK PAYMENT] No data or empty docs for role: $role');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${role == 'chw' ? 'CHWs' : 'Doctors'} found',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        // Filter for approved providers (isApproved == true or null/missing field defaults to true)
        final allProviders = snapshot.data!.docs;
        print(
          '🔍 [BULK PAYMENT] Found ${allProviders.length} total providers for role: $role',
        );

        final providers = allProviders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isApproved =
              data['isApproved'] ??
              true; // Default to true if field doesn't exist
          final isRejected = data['isRejected'] ?? false; // Check if rejected
          print(
            '🔍 [BULK PAYMENT] Provider ${doc.id}: isApproved=$isApproved, isRejected=$isRejected, name=${data['fullName'] ?? data['name']}',
          );
          return isApproved == true && isRejected == false;
        }).toList();

        print(
          '🔍 [BULK PAYMENT] After filtering: ${providers.length} approved providers for role: $role',
        );

        // Check if there are no approved providers after filtering
        if (providers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No approved ${role == 'chw' ? 'CHWs' : 'Doctors'} found',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (allProviders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${allProviders.length} ${role == 'chw' ? 'CHW' : 'Doctor'}${allProviders.length > 1 ? 's' : ''} pending approval',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        final selectedSet = role == 'chw' ? _selectedCHWs : _selectedDoctors;
        final selectAll = role == 'chw' ? _selectAllCHWs : _selectAllDoctors;

        // Determine how many items to show
        final displayLimit = 10;
        final showViewMore = providers.length > displayLimit;
        final displayedProviders =
            (isExpanded || providers.length <= displayLimit)
            ? providers
            : providers.sublist(0, displayLimit);

        print(
          '🔍 [BULK PAYMENT] role=$role, providers.length=${providers.length}, displayedProviders.length=${displayedProviders.length}, isExpanded=$isExpanded, showViewMore=$showViewMore',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Registered Count Display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total Registered ${role == 'chw' ? 'CHWs' : 'Doctors'}: ${providers.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            // Select All
            Container(
              color: Colors.grey.shade100,
              child: CheckboxListTile(
                title: Text(
                  'Select All (${providers.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                value: selectAll,
                onChanged: (value) {
                  setState(() {
                    if (role == 'chw') {
                      _selectAllCHWs = value ?? false;
                      if (value == true) {
                        _selectedCHWs.addAll(providers.map((doc) => doc.id));
                      } else {
                        _selectedCHWs.clear();
                      }
                    } else {
                      _selectAllDoctors = value ?? false;
                      if (value == true) {
                        _selectedDoctors.addAll(providers.map((doc) => doc.id));
                      } else {
                        _selectedDoctors.clear();
                      }
                    }
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: displayedProviders.length + (showViewMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // If this is the last item and we need to show "View More" button
                  if (showViewMore && index == displayedProviders.length) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            if (role == 'chw') {
                              _expandedCHWList = !_expandedCHWList;
                            } else {
                              _expandedDoctorList = !_expandedDoctorList;
                            }
                          });
                        },
                        icon: Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(
                          isExpanded
                              ? 'View Less'
                              : 'View More (${providers.length - displayLimit} more)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: role == 'chw'
                              ? Colors.teal
                              : Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    );
                  }

                  final doc = displayedProviders[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? data['name'] ?? 'Unknown')
                      .toString()
                      .trim();
                  final email = (data['email'] ?? '').toString().trim();
                  final phone = (data['phone'] ?? data['phoneNumber'] ?? '')
                      .toString()
                      .trim();
                  final isSelected = selectedSet.contains(doc.id);

                  // Debug logging to understand the data structure
                  if (role == 'chw' && index < 3) {
                    // Only log first 3 CHWs to avoid spam
                    print(
                      '🔍 [CHW DEBUG] CHW ${index + 1}: name="$name", email="$email", phone="$phone"',
                    );
                    print(
                      '🔍 [CHW DEBUG] Full data keys: ${data.keys.toList()}',
                    );
                    print(
                      '🔍 [CHW DEBUG] Raw fullName: "${data['fullName']}", Raw name: "${data['name']}"',
                    );
                  }

                  // Build subtitle with proper handling of empty values
                  final subtitleParts = <String>[];
                  if (email.isNotEmpty) subtitleParts.add(email);
                  if (phone.isNotEmpty) subtitleParts.add(phone);
                  final subtitleText = subtitleParts.join(' • ');

                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: subtitleText.isNotEmpty
                        ? Text(
                            subtitleText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          )
                        : null, // Don't show subtitle if empty
                    secondary: CircleAvatar(
                      backgroundColor: role == 'chw'
                          ? Colors.teal
                          : Colors.blue,
                      radius: 18,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedSet.add(doc.id);
                        } else {
                          selectedSet.remove(doc.id);
                          if (role == 'chw') {
                            _selectAllCHWs = false;
                          } else {
                            _selectAllDoctors = false;
                          }
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? Colors.black,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
