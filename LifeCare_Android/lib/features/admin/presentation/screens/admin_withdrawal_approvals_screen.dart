import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifecare_connect/features/shared/data/services/withdrawal_service.dart';

class AdminWithdrawalApprovalsScreen extends StatefulWidget {
  const AdminWithdrawalApprovalsScreen({super.key});

  @override
  State<AdminWithdrawalApprovalsScreen> createState() =>
      _AdminWithdrawalApprovalsScreenState();
}

class _AdminWithdrawalApprovalsScreenState
    extends State<AdminWithdrawalApprovalsScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    try {
      print('🔍 Loading pending withdrawal requests...');

      // Try with orderBy first
      QuerySnapshot query;
      try {
        query = await _firestore
            .collection('withdrawals')
            .where('status', isEqualTo: 'pending')
            .orderBy('requestedAt', descending: true)
            .get();
        print('✅ Loaded ${query.docs.length} pending withdrawals with orderBy');
      } catch (e) {
        print('⚠️ orderBy failed (index may be missing): $e');
        print('🔄 Retrying without orderBy...');

        // Fallback: query without orderBy
        query = await _firestore
            .collection('withdrawals')
            .where('status', isEqualTo: 'pending')
            .get();
        print(
          '✅ Loaded ${query.docs.length} pending withdrawals without orderBy',
        );
      }

      final withdrawals = query.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {...data, 'id': d.id};
      }).toList();

      // Sort manually by requestedAt if we couldn't use orderBy
      withdrawals.sort((a, b) {
        final aTime = a['requestedAt'] as Timestamp?;
        final bTime = b['requestedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // descending
      });

      print('📋 Withdrawal requests:');
      for (var wd in withdrawals) {
        print(
          '  - ${wd['userId']} (${wd['role']}): ₦${wd['amount']} to ${wd['bankName']}',
        );
      }

      setState(() {
        _pending = withdrawals;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading pending withdrawals: $e');
      setState(() {
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading withdrawals: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _approve(String id) async {
    final wd = _pending.firstWhere((w) => w['id'] == id);
    final amount = wd['amount'] is int
        ? (wd['amount'] as int).toDouble()
        : (wd['amount'] as double);

    // Note: Pre-check for withdrawal feasibility disabled since checkWithdrawalStatus function
    // is not deployed. The paystackTransfer function will handle balance checks internally.
    // If needed in future, deploy checkWithdrawalStatus callable function from withdrawal_reserve_manager.js

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Withdrawal Approval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to approve this withdrawal and initiate the payout?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildConfirmRow('Amount:', '₦${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildConfirmRow('Bank:', wd['bankName'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildConfirmRow('Account:', wd['accountNumber'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildConfirmRow('Name:', wd['accountName'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildConfirmRow(
              'Provider:',
              wd['role']?.toString().toUpperCase() ?? 'N/A',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will transfer funds to the provider\'s bank account.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve & Pay'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show processing dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing withdrawal...'),
            SizedBox(height: 8),
            Text(
              'Please wait while we process the payment',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      print('💰 Approving withdrawal: $id');
      print(
        '📋 Details: ₦$amount to ${wd['bankName']} (${wd['accountNumber']})',
      );

      // Mark as approved in Firestore first
      await _firestore.collection('withdrawals').doc(id).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'admin',
      });
      print('✅ Marked as approved in Firestore');

      // Trigger payout via Cloud Function
      final payoutResult = await WithdrawalService.payoutWithdrawal(
        withdrawalId: id,
        userId: wd['userId'] ?? '',
        amount: amount,
        accountNumber: wd['accountNumber'] ?? '',
        bankCode: wd['bankCode'] ?? '',
        accountName: wd['accountName'] ?? '',
        isAdminApproval: true, // This is an admin approval
      );

      if (mounted) Navigator.of(context).pop(); // Close processing dialog

      print('📦 Payout result: $payoutResult');

      if (payoutResult['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Withdrawal approved and payout initiated successfully!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
        print('✅ Payout successful');
      } else {
        final error = payoutResult['error'] ?? 'Unknown error';
        print('❌ Payout failed: $error');

        // Check if it's an insufficient balance error
        if (error.toLowerCase().contains('insufficient balance')) {
          await _handleInsufficientBalanceError(wd, error);
        } else {
          // Other errors - show snackbar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Payout failed: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Details',
                  textColor: Colors.white,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Payout Error Details'),
                        content: SingleChildScrollView(child: Text(error)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ [ADMIN APPROVAL] Withdrawal approval failed: $e');
      print('   Stack trace: $stackTrace');

      if (mounted) {
        Navigator.of(context).pop(); // Close processing dialog if open

        // Check if it's an insufficient balance error
        final errorMessage = e.toString().toLowerCase();
        if (errorMessage.contains('insufficient balance') ||
            errorMessage.contains('failed-precondition')) {
          await _handleInsufficientBalanceError(wd, e.toString());
        } else {
          // Categorize the error for better user experience
          String userFriendlyMessage = 'Withdrawal approval failed';
          String troubleshootingSteps = '';

          if (errorMessage.contains('paystack') &&
              errorMessage.contains('balance')) {
            userFriendlyMessage = 'Insufficient Paystack balance';
            troubleshootingSteps =
                'Please fund your Paystack account before approving withdrawals.';
          } else if (errorMessage.contains('account') ||
              errorMessage.contains('bank')) {
            userFriendlyMessage = 'Invalid bank account details';
            troubleshootingSteps =
                'The provider\'s bank account information may be incorrect. Please verify the account details.';
          } else if (errorMessage.contains('network') ||
              errorMessage.contains('connection')) {
            userFriendlyMessage = 'Network error';
            troubleshootingSteps =
                'Please check your internet connection and try again.';
          } else if (errorMessage.contains('firebase') ||
              errorMessage.contains('functions')) {
            userFriendlyMessage = 'Service error';
            troubleshootingSteps =
                'The withdrawal service is temporarily unavailable. Please try again later.';
          } else {
            userFriendlyMessage = 'Approval failed: ${e.toString()}';
          }

          // Show clear error dialog instead of SnackBar
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  const Text('Approval Failed'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userFriendlyMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (troubleshootingSteps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              troubleshootingSteps,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'What to do:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Check Paystack balance (if applicable)\n'
                    '2. Verify provider\'s bank account details\n'
                    '3. Ensure stable internet connection\n'
                    '4. Try again in a few minutes',
                    style: TextStyle(fontSize: 13),
                  ),
                  if (e.toString().length < 200) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Technical details:\n${e.toString()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }

    await _loadPending();
  }

  Future<void> _handleInsufficientBalanceError(
    Map<String, dynamic> wd,
    String error,
  ) async {
    final amount = wd['amount'] is int
        ? (wd['amount'] as int).toDouble()
        : (wd['amount'] as double);
    final providerRole = wd['role']?.toString().toUpperCase() ?? 'PROVIDER';
    final userId = wd['userId'] ?? '';
    final providerName = wd['accountName'] ?? 'Provider';

    // Show clear dialog to admin
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Insufficient Balance')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cannot process withdrawal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The $providerRole does not have sufficient balance in their wallet to process this withdrawal request.',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Withdrawal Details:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildConfirmRow('Amount:', '₦${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildConfirmRow('Provider:', providerRole),
            const SizedBox(height: 4),
            _buildConfirmRow('Account:', wd['accountName'] ?? 'N/A'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'The provider will be notified about this issue via email and in-app message.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _sendInsufficientBalanceNotifications(
                userId,
                providerName,
                amount,
                providerRole,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Notify Provider'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInsufficientBalanceNotifications(
    String userId,
    String providerName,
    double amount,
    String role,
  ) async {
    try {
      // Send in-app message
      await FirebaseFirestore.instance.collection('messages').add({
        'conversationId': userId,
        'senderId': 'admin',
        'senderName': 'Admin',
        'senderRole': 'admin',
        'receiverId': userId,
        'receiverName': providerName,
        'receiverRole': role.toLowerCase(),
        'content':
            '❌ WITHDRAWAL REQUEST FAILED\n\n'
            'Your withdrawal request for ₦${amount.toStringAsFixed(2)} could not be processed due to insufficient balance in your wallet.\n\n'
            '💡 NEXT STEPS:\n'
            '• Check your wallet balance in the app\n'
            '• Wait for pending appointments to be completed\n'
            '• Only request withdrawals for amounts available in your wallet\n\n'
            'If you believe this is an error, please contact support.',
        'type': 'withdrawal_failed',
        'priority': 'high',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // TODO: Send email notification here
      // You can integrate with your email service (SendGrid, etc.)

      print('✅ Sent insufficient balance notifications to $userId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Provider has been notified about the insufficient balance',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error sending notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Could not send notifications: ${e.toString()}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _reject(String id) async {
    final wd = _pending.firstWhere((w) => w['id'] == id);
    final amount = wd['amount'] is int
        ? (wd['amount'] as int).toDouble()
        : (wd['amount'] as double);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rejection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to reject this withdrawal request?',
            ),
            const SizedBox(height: 16),
            _buildConfirmRow('Amount:', '₦${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            _buildConfirmRow(
              'Provider:',
              wd['role']?.toString().toUpperCase() ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildConfirmRow('Bank:', wd['bankName'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await WithdrawalService.rejectWithdrawal(id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Withdrawal rejected and refunded if applicable'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    await _loadPending();
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = (timestamp as Timestamp).toDate();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal Approvals'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadPending();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading withdrawal requests...'),
                ],
              ),
            )
          : _pending.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending withdrawal requests',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All withdrawal requests have been processed',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pending.length,
              itemBuilder: (context, i) {
                final wd = _pending[i];
                final amount = wd['amount'] is int
                    ? (wd['amount'] as int).toDouble()
                    : (wd['amount'] as double);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.account_balance,
                                color: Colors.indigo.shade700,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₦${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                  Text(
                                    wd['bankName'] ?? 'Unknown Bank',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
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
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (wd['role'] ?? 'N/A').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.numbers,
                          'Account Number',
                          wd['accountNumber'] ?? 'N/A',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.person,
                          'Account Name',
                          wd['accountName'] ?? 'N/A',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.code,
                          'Bank Code',
                          wd['bankCode'] ?? 'N/A',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.badge,
                          'User ID',
                          wd['userId'] ?? 'N/A',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.access_time,
                          'Requested At',
                          _formatTimestamp(wd['requestedAt']),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('Approve & Pay'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => _approve(wd['id']),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: () => _reject(wd['id']),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
