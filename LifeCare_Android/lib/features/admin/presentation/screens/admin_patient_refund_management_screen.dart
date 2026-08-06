// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

/// Screen for Main Admin to manage patient wallet refund applications
class AdminPatientRefundManagementScreen extends StatefulWidget {
  const AdminPatientRefundManagementScreen({super.key});

  @override
  State<AdminPatientRefundManagementScreen> createState() =>
      _AdminPatientRefundManagementScreenState();
}

class _AdminPatientRefundManagementScreenState
    extends State<AdminPatientRefundManagementScreen>
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
        title: const Text('Patient Refund Management'),
        backgroundColor: Colors.indigo,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Approved', icon: Icon(Icons.check_circle)),
            Tab(text: 'Rejected', icon: Icon(Icons.cancel)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PendingApplicationsTab(),
          _ApprovedApplicationsTab(),
          _RejectedApplicationsTab(),
        ],
      ),
    );
  }
}

/// Pending applications tab
class _PendingApplicationsTab extends StatelessWidget {
  const _PendingApplicationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient_refund_applications')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data?.docs ?? [];

        if (applications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending refund applications',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final doc = applications[index];
            final data = doc.data() as Map<String, dynamic>;

            return _PendingApplicationCard(applicationId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _PendingApplicationCard extends StatefulWidget {
  final String applicationId;
  final Map<String, dynamic> data;

  const _PendingApplicationCard({
    required this.applicationId,
    required this.data,
  });

  @override
  State<_PendingApplicationCard> createState() =>
      _PendingApplicationCardState();
}

class _PendingApplicationCardState extends State<_PendingApplicationCard> {
  bool _processing = false;

  Future<void> _approveApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Refund'),
        content: Text(
          'Approve refund of ₦${NumberFormat('#,##0.00').format(widget.data['amount'])} '
          'to ${widget.data['patientName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processing = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'processPatientRefundApproval',
      );
      final result = await callable.call({
        'applicationId': widget.applicationId,
      });

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Refund approved and processed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(result.data['message'] ?? 'Approval failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _rejectApplication() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Refund Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Rejection reason',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.pop(context, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == null || confirmed.isEmpty) return;

    setState(() => _processing = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'rejectPatientRefundApplication',
      );
      final result = await callable.call({
        'applicationId': widget.applicationId,
        'reason': confirmed,
      });

      if (result.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        throw Exception(result.data['message'] ?? 'Rejection failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (widget.data['amount'] ?? 0.0).toDouble();
    final patientName = widget.data['patientName'] ?? 'Unknown';
    final reason = widget.data['reason'] ?? 'N/A';
    final createdAt = (widget.data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: const Icon(Icons.pending_actions, color: Colors.orange),
        ),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '₦${NumberFormat('#,##0.00').format(amount)} • ${_formatReason(reason)}',
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Info
                _buildSectionHeader('Patient Information'),
                _buildInfoRow('Name', patientName),
                _buildInfoRow('Email', widget.data['patientEmail'] ?? 'N/A'),
                _buildInfoRow('Phone', widget.data['patientPhone'] ?? 'N/A'),

                const SizedBox(height: 12),
                const Divider(),

                // Refund Details
                _buildSectionHeader('Refund Details'),
                _buildInfoRow(
                  'Amount',
                  '₦${NumberFormat('#,##0.00').format(amount)}',
                ),
                _buildInfoRow('Reason', _formatReason(reason)),
                if (createdAt != null)
                  _buildInfoRow(
                    'Applied On',
                    DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt),
                  ),

                const SizedBox(height: 12),
                const Divider(),

                // Bank Details
                _buildSectionHeader('Bank Account Details'),
                _buildInfoRow('Bank', widget.data['bankName'] ?? 'N/A'),
                _buildInfoRow(
                  'Account Number',
                  widget.data['accountNumber'] ?? 'N/A',
                ),
                _buildInfoRow(
                  'Account Name',
                  widget.data['accountName'] ?? 'N/A',
                ),

                // Next of Kin (if deceased)
                if (reason == 'deceased' &&
                    widget.data['nextOfKin'] != null) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  _buildSectionHeader('Next of Kin Information'),
                  _buildInfoRow(
                    'Name',
                    widget.data['nextOfKin']['name'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Relationship',
                    widget.data['nextOfKin']['relationship'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Phone',
                    widget.data['nextOfKin']['phone'] ?? 'N/A',
                  ),
                ],

                if (widget.data['remarks'] != null &&
                    widget.data['remarks'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  _buildSectionHeader('Remarks'),
                  Text(widget.data['remarks']),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : _rejectApplication,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _processing ? null : _approveApplication,
                        icon: _processing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(_processing ? 'Processing...' : 'Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.indigo,
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
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatReason(String reason) {
    switch (reason) {
      case 'withdrawal':
        return 'Withdraw Funds';
      case 'relocating':
        return 'Relocating';
      case 'deceased':
        return 'Deceased (Next of Kin)';
      default:
        return 'Other';
    }
  }
}

/// Approved applications tab
class _ApprovedApplicationsTab extends StatelessWidget {
  const _ApprovedApplicationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient_refund_applications')
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data?.docs ?? [];

        if (applications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No approved refunds yet',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final doc = applications[index];
            final data = doc.data() as Map<String, dynamic>;

            return _ApprovedApplicationCard(data: data);
          },
        );
      },
    );
  }
}

class _ApprovedApplicationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ApprovedApplicationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final amount = (data['amount'] ?? 0.0).toDouble();
    final patientName = data['patientName'] ?? 'Unknown';
    final approvedAt = (data['approvedAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(Icons.check_circle, color: Colors.green),
        ),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₦${NumberFormat('#,##0.00').format(amount)}',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (approvedAt != null)
              Text(
                'Approved: ${DateFormat('MMM dd, yyyy').format(approvedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showDetails(context),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Patient', data['patientName'] ?? 'N/A'),
              _buildDetailRow(
                'Amount',
                '₦${NumberFormat('#,##0.00').format(data['amount'] ?? 0)}',
              ),
              _buildDetailRow('Bank', data['bankName'] ?? 'N/A'),
              _buildDetailRow('Account', data['accountNumber'] ?? 'N/A'),
              if (data['approvedAt'] != null)
                _buildDetailRow(
                  'Approved On',
                  DateFormat(
                    'MMM dd, yyyy • hh:mm a',
                  ).format((data['approvedAt'] as Timestamp).toDate()),
                ),
            ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rejected applications tab
class _RejectedApplicationsTab extends StatelessWidget {
  const _RejectedApplicationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient_refund_applications')
          .where('status', isEqualTo: 'rejected')
          .orderBy('rejectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data?.docs ?? [];

        if (applications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No rejected applications',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final doc = applications[index];
            final data = doc.data() as Map<String, dynamic>;

            return _RejectedApplicationCard(data: data);
          },
        );
      },
    );
  }
}

class _RejectedApplicationCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RejectedApplicationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final amount = (data['amount'] ?? 0.0).toDouble();
    final patientName = data['patientName'] ?? 'Unknown';
    final rejectedAt = (data['rejectedAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFEBEE),
          child: Icon(Icons.cancel, color: Colors.red),
        ),
        title: Text(
          patientName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₦${NumberFormat('#,##0.00').format(amount)}',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (rejectedAt != null)
              Text(
                'Rejected: ${DateFormat('MMM dd, yyyy').format(rejectedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _showDetails(context),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejected Application'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Patient', data['patientName'] ?? 'N/A'),
              _buildDetailRow(
                'Amount',
                '₦${NumberFormat('#,##0.00').format(data['amount'] ?? 0)}',
              ),
              if (data['rejectedAt'] != null)
                _buildDetailRow(
                  'Rejected On',
                  DateFormat(
                    'MMM dd, yyyy • hh:mm a',
                  ).format((data['rejectedAt'] as Timestamp).toDate()),
                ),
              const Divider(),
              const Text(
                'Rejection Reason:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['rejectionReason'] ?? 'No reason provided',
                style: const TextStyle(color: Colors.red),
              ),
            ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
