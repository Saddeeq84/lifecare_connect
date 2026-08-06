import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../shared/data/services/account_deletion_service.dart';

class AccountDeletionRequestsScreen extends StatefulWidget {
  const AccountDeletionRequestsScreen({super.key});

  @override
  State<AccountDeletionRequestsScreen> createState() =>
      _AccountDeletionRequestsScreenState();
}

class _AccountDeletionRequestsScreenState
    extends State<AccountDeletionRequestsScreen> {
  bool _showProcessed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showProcessed ? 'Processed Requests' : 'Pending Deletion Requests',
        ),
        backgroundColor: Colors.purple.shade700,
        actions: [
          IconButton(
            icon: Icon(_showProcessed ? Icons.pending_actions : Icons.history),
            onPressed: () {
              setState(() {
                _showProcessed = !_showProcessed;
              });
            },
            tooltip: _showProcessed ? 'Show Pending' : 'Show History',
          ),
        ],
      ),
      body: _showProcessed
          ? _buildProcessedRequests()
          : _buildPendingRequests(),
    );
  }

  Widget _buildPendingRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: AccountDeletionService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending deletion requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRequestCard(doc.id, data, isPending: true);
          },
        );
      },
    );
  }

  Widget _buildProcessedRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: AccountDeletionService.getProcessedRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No processed requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRequestCard(doc.id, data, isPending: false);
          },
        );
      },
    );
  }

  Widget _buildRequestCard(
    String requestId,
    Map<String, dynamic> data, {
    required bool isPending,
  }) {
    final userName = data['userName'] ?? 'Unknown';
    final userEmail = data['userEmail'] ?? '';
    final userRole = data['userRole'] ?? '';
    final reason = data['reason'] ?? '';
    final status = data['status'] ?? 'pending';
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
    final processedAt = (data['processedAt'] as Timestamp?)?.toDate();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'PENDING';
        statusIcon = Icons.pending_actions;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusText = 'APPROVED';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'REJECTED';
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'CANCELLED';
        statusIcon = Icons.close;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status.toUpperCase();
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Chip(
                  label: Text(
                    userRole.toUpperCase(),
                    style: TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              userName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(userEmail, style: TextStyle(color: Colors.grey[600])),
            if (reason.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(reason, style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Requested: ${requestedAt != null ? "${requestedAt.day}/${requestedAt.month}/${requestedAt.year}" : "Unknown"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (processedAt != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.done_all, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    'Processed: ${processedAt.day}/${processedAt.month}/${processedAt.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (status == 'rejected' && data['rejectionReason'] != null) ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'Rejection reason: ${data['rejectionReason']}',
                  style: TextStyle(fontSize: 12, color: Colors.red[800]),
                ),
              ),
            ],
            if (isPending) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.check),
                      label: Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _approveRequest(requestId, data),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.close),
                      label: Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _rejectRequest(requestId, data),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Deletion Request'),
        content: Text(
          'Are you sure you want to approve this account deletion request for ${requestData['userName']}?\n\n'
          'This will permanently delete their account and all associated data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Approve & Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) throw Exception('Admin not authenticated');

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUser.uid)
          .get();
      final adminName =
          adminDoc.data()?['fullName'] ?? adminDoc.data()?['name'] ?? 'Admin';

      // Approve the request
      await AccountDeletionService.approveDeletionRequest(
        requestId: requestId,
        adminId: adminUser.uid,
        adminName: adminName,
      );

      // Execute account deletion using cloud function
      final userId = requestData['userId'];
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteAccount',
      );
      await callable.call({'targetUid': userId});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Account deletion approved and executed successfully',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to approve request: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Deletion Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject deletion request for ${requestData['userName']}?'),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Provide a reason for rejection',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reject'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final adminUser = FirebaseAuth.instance.currentUser;
      if (adminUser == null) throw Exception('Admin not authenticated');

      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminUser.uid)
          .get();
      final adminName =
          adminDoc.data()?['fullName'] ?? adminDoc.data()?['name'] ?? 'Admin';

      await AccountDeletionService.rejectDeletionRequest(
        requestId: requestId,
        adminId: adminUser.uid,
        adminName: adminName,
        rejectionReason: result,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
