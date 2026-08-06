import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class FacilityAdminRefundManagementScreen extends StatefulWidget {
  final String facilityId;
  final String adminId;
  final String adminName;

  const FacilityAdminRefundManagementScreen({
    super.key,
    required this.facilityId,
    required this.adminId,
    required this.adminName,
  });

  @override
  State<FacilityAdminRefundManagementScreen> createState() =>
      _FacilityAdminRefundManagementScreenState();
}

class _FacilityAdminRefundManagementScreenState
    extends State<FacilityAdminRefundManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Management'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.check_circle), text: 'Approved'),
            Tab(icon: Icon(Icons.cancel), text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingRefundsTab(
            facilityId: widget.facilityId,
            adminId: widget.adminId,
            adminName: widget.adminName,
          ),
          _ApprovedRefundsTab(facilityId: widget.facilityId),
          _RejectedRefundsTab(facilityId: widget.facilityId),
        ],
      ),
    );
  }
}

// ==================== PENDING REFUNDS TAB ====================
class _PendingRefundsTab extends StatelessWidget {
  final String facilityId;
  final String adminId;
  final String adminName;

  const _PendingRefundsTab({
    required this.facilityId,
    required this.adminId,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_applications')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'pending_admin_approval')
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending refund applications',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final refund = doc.data() as Map<String, dynamic>;
            refund['id'] = doc.id;

            return _PendingRefundCard(
              refund: refund,
              adminId: adminId,
              adminName: adminName,
              facilityId: facilityId,
            );
          },
        );
      },
    );
  }
}

// ==================== APPROVED REFUNDS TAB ====================
class _ApprovedRefundsTab extends StatelessWidget {
  final String facilityId;

  const _ApprovedRefundsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_applications')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No approved refunds yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final refund = doc.data() as Map<String, dynamic>;
            return _CompletedRefundCard(refund: refund, isApproved: true);
          },
        );
      },
    );
  }
}

// ==================== REJECTED REFUNDS TAB ====================
class _RejectedRefundsTab extends StatelessWidget {
  final String facilityId;

  const _RejectedRefundsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('refund_applications')
          .where('facilityId', isEqualTo: facilityId)
          .where('status', isEqualTo: 'rejected')
          .orderBy('rejectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No rejected refunds'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final refund = doc.data() as Map<String, dynamic>;
            return _CompletedRefundCard(refund: refund, isApproved: false);
          },
        );
      },
    );
  }
}

// ==================== PENDING REFUND CARD ====================
class _PendingRefundCard extends StatelessWidget {
  final Map<String, dynamic> refund;
  final String adminId;
  final String adminName;
  final String facilityId;

  const _PendingRefundCard({
    required this.refund,
    required this.adminId,
    required this.adminName,
    required this.facilityId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pending_actions,
                  color: Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refund['patientName'] ?? 'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Refund Amount: ₦${(refund['refundAmount'] ?? 0).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Details
                const Text(
                  'Patient Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _DetailRow('Patient ID:', refund['patientId'] ?? 'N/A'),
                _DetailRow(
                  'Wallet Balance:',
                  '₦${(refund['walletBalanceAtApplication'] ?? 0).toStringAsFixed(2)}',
                ),

                const Divider(height: 24),

                // Refund Details
                const Text(
                  'Refund Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _DetailRow('Reason:', refund['refundReason'] ?? 'N/A'),
                _DetailRow('Details:', refund['reasonDetails'] ?? 'N/A'),
                _DetailRow(
                  'Applied By:',
                  '${refund['applicantName']} (${refund['applicantDepartment']})',
                ),
                _DetailRow('Applied At:', _formatDate(refund['appliedAt'])),

                const Divider(height: 24),

                // Beneficiary Details
                const Text(
                  'Beneficiary Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _DetailRow('Name:', refund['beneficiaryName'] ?? 'N/A'),
                _DetailRow('Phone:', refund['beneficiaryPhone'] ?? 'N/A'),

                const Divider(height: 24),

                // Bank Details
                const Text(
                  'Bank Account Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _DetailRow('Bank:', refund['bankName'] ?? 'N/A'),
                _DetailRow('Account Number:', refund['accountNumber'] ?? 'N/A'),
                _DetailRow('Account Name:', refund['accountName'] ?? 'N/A'),

                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (refund['bankAccountVerified'] == true)
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (refund['bankAccountVerified'] == true)
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (refund['bankAccountVerified'] == true)
                            ? Icons.verified
                            : Icons.warning,
                        color: (refund['bankAccountVerified'] == true)
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (refund['bankAccountVerified'] == true)
                              ? 'Bank account verified ✓'
                              : 'Bank account NOT verified',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: (refund['bankAccountVerified'] == true)
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showRejectDialog(context),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (refund['bankAccountVerified'] == true)
                            ? () => _showApproveDialog(context)
                            : null,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                // View Audit Trail
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showAuditTrail(context),
                  icon: const Icon(Icons.history),
                  label: const Text('View Audit Trail'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Approve Refund'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are about to approve this refund application:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _DetailRow('Patient:', refund['patientName']),
              _DetailRow(
                'Amount:',
                '₦${(refund['refundAmount'] ?? 0).toStringAsFixed(2)}',
              ),
              _DetailRow('Beneficiary:', refund['beneficiaryName']),
              _DetailRow('Bank:', refund['bankName']),
              _DetailRow('Account:', refund['accountNumber']),
              _DetailRow('Account Name:', refund['accountName']),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Important:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ₦${(refund['refundAmount'] ?? 0).toStringAsFixed(2)} will be deducted from patient wallet',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Text(
                      '• Funds will be transferred to the bank account',
                      style: TextStyle(fontSize: 12),
                    ),
                    const Text(
                      '• This action cannot be undone',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processApproval(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve & Transfer'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Reject Refund'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${refund['patientName']}'),
              Text(
                'Amount: ₦${(refund['refundAmount'] ?? 0).toStringAsFixed(2)}',
              ),
              const SizedBox(height: 16),
              const Text(
                'Rejection Reason *',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Provide detailed reason for rejection...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Rejection reason is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide detailed reason (min 10 characters)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _processRejection(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Application'),
          ),
        ],
      ),
    );
  }

  Future<void> _processApproval(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'processRefundApproval',
      );
      final result = await callable.call({
        'refundApplicationId': refund['id'],
        'facilityId': facilityId,
        'adminId': adminId,
        'adminName': adminName,
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.data['message'] ?? 'Refund approved successfully',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Approval Failed'),
              ],
            ),
            content: Text(e.toString()),
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

  Future<void> _processRejection(BuildContext context, String reason) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'rejectRefundApplication',
      );
      await callable.call({
        'refundApplicationId': refund['id'],
        'facilityId': facilityId,
        'adminId': adminId,
        'adminName': adminName,
        'rejectionReason': reason,
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refund application rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAuditTrail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit Trail'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('refund_applications')
                .doc(refund['id'])
                .collection('verification_logs')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No audit logs available');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final log =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(
                      log['type'] == 'bank_account_verification'
                          ? Icons.verified_user
                          : Icons.info,
                    ),
                    title: Text(log['type'] ?? 'Unknown'),
                    subtitle: Text(_formatDate(log['timestamp'])),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _DetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }
}

// ==================== COMPLETED REFUND CARD ====================
class _CompletedRefundCard extends StatelessWidget {
  final Map<String, dynamic> refund;
  final bool isApproved;

  const _CompletedRefundCard({required this.refund, required this.isApproved});

  @override
  Widget build(BuildContext context) {
    final color = isApproved ? Colors.green : Colors.red;
    final icon = isApproved ? Icons.check_circle : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          refund['patientName'] ?? 'Unknown Patient',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '₦${(refund['refundAmount'] ?? 0).toStringAsFixed(2)} - ${isApproved ? 'Approved' : 'Rejected'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('Patient ID:', refund['patientId']),
                _DetailRow('Refund Reason:', refund['refundReason']),
                _DetailRow('Beneficiary:', refund['beneficiaryName']),
                const Divider(),
                _DetailRow('Bank:', refund['bankName']),
                _DetailRow('Account:', refund['accountNumber']),
                _DetailRow('Account Name:', refund['accountName']),
                const Divider(),
                _DetailRow('Applied By:', refund['applicantName']),
                _DetailRow('Applied At:', _formatDate(refund['appliedAt'])),
                const Divider(),
                if (isApproved) ...[
                  _DetailRow('Approved By:', refund['approvedByName']),
                  _DetailRow('Approved At:', _formatDate(refund['approvedAt'])),
                  if (refund['transferReference'] != null)
                    _DetailRow('Transfer Ref:', refund['transferReference']),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Transfer completed successfully',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  _DetailRow('Rejected By:', refund['rejectedByName']),
                  _DetailRow('Rejected At:', _formatDate(refund['rejectedAt'])),
                  _DetailRow('Rejection Reason:', refund['rejectionReason']),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            refund['rejectionReason'] ?? 'Application rejected',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
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
        ],
      ),
    );
  }

  Widget _DetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
  }
}
