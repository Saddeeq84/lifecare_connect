// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'facility_staff_create_account.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifecare_connect/core/utils/send_staff_setup_password_email.dart';

class FacilityStaffListScreen extends StatelessWidget {
  final String facilityName;
  final String? facilityId;
  const FacilityStaffListScreen({
    super.key,
    required this.facilityName,
    this.facilityId,
  });

  Future<void> _showStaffDetails(
    BuildContext context,
    DocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final collection =
        '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

    await showDialog(
      context: context,
      builder: (context) => StaffDetailsDialog(
        staffDoc: doc,
        staffData: data,
        collection: collection,
        facilityName: facilityName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collection =
        '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Staff'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Register Staff'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FacilityStaffCreateAccountScreen(
                            facilityName: facilityName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collection)
                  .orderBy('createdAt', descending: true)
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

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No staff members yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "Register Staff" to add your first staff member',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRestricted = data['isRestricted'] ?? false;
                    final status = data['status'] ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isRestricted
                              ? Colors.red.shade100
                              : Colors.teal.shade100,
                          child: Icon(
                            isRestricted ? Icons.block : Icons.person,
                            color: isRestricted ? Colors.red : Colors.teal,
                          ),
                        ),
                        title: Text(
                          data['fullName'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isRestricted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Staff ID: ${data['staffId'] ?? 'N/A'}'),
                            Text(
                              '${data['profession'] ?? 'N/A'} • ${data['department'] ?? 'N/A'}',
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
                                    color: _getStatusColor(
                                      status,
                                      isRestricted,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(status, isRestricted),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showStaffDetails(context, doc),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status, bool isRestricted) {
    if (isRestricted) return Colors.red;
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, bool isRestricted) {
    if (isRestricted) return 'RESTRICTED';
    switch (status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'pending':
        return 'PENDING SETUP';
      default:
        return status.toUpperCase();
    }
  }
}

class StaffDetailsDialog extends StatefulWidget {
  final DocumentSnapshot staffDoc;
  final Map<String, dynamic> staffData;
  final String collection;
  final String facilityName;

  const StaffDetailsDialog({
    super.key,
    required this.staffDoc,
    required this.staffData,
    required this.collection,
    required this.facilityName,
  });

  @override
  State<StaffDetailsDialog> createState() => _StaffDetailsDialogState();
}

class _StaffDetailsDialogState extends State<StaffDetailsDialog> {
  bool _isLoading = false;
  bool _isResendingEmail = false;

  Future<void> _resendSetupEmail() async {
    final staffData = widget.staffData;
    final email = staffData['email'];
    final name = staffData['fullName'];
    final staffId = staffData['staffId'];
    final password = staffData['password'];
    final status = staffData['status'];
    final emailVerified = staffData['emailVerified'];

    // Only allow resending for pending/unverified accounts
    if (status == 'active' && emailVerified == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This staff member has already verified their email.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    if (email == null || name == null || staffId == null || password == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Missing required staff information. Cannot resend email.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.email, color: Colors.blue),
            SizedBox(width: 8),
            Text('Resend Setup Email?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send new login credentials to:'),
            const SizedBox(height: 8),
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
                  Text(
                    '📧 $email',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Staff: $name ($staffId)'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will send a new verification link and login credentials.',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResendingEmail = true);

    try {
      // Generate new verification link
      final collection = widget.collection;
      final verificationLink =
          'https://lifecare-connect.web.app/verify-email?'
          'collection=${Uri.encodeComponent(collection)}&docId=${Uri.encodeComponent(widget.staffDoc.id)}';

      print(
        '[ResendEmail] Sending setup email to: $email for staff ID: $staffId',
      );

      // Send email with credentials and verification link
      await sendStaffSetupPasswordEmail(
        email: email,
        name: name,
        staffId: staffId,
        setupLink: '$password|||$verificationLink',
      );

      // Update last email sent timestamp
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.staffDoc.id)
          .update({
            'lastEmailSentAt': FieldValue.serverTimestamp(),
            'emailResendCount': FieldValue.increment(1),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Setup email sent successfully! Ask staff to check inbox and spam folder.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('[ResendEmail] ❌ Failed to send email: $e');

      if (mounted) {
        // Extract user-friendly error message
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        final isNetworkError =
            errorMessage.toLowerCase().contains('network') ||
            errorMessage.toLowerCase().contains('dns') ||
            errorMessage.toLowerCase().contains('connection') ||
            errorMessage.toLowerCase().contains('timeout');

        // Show detailed error information
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isNetworkError ? Icons.wifi_off : Icons.error,
                  color: Colors.red,
                ),
                SizedBox(width: 8),
                Text(isNetworkError ? 'Network Error' : 'Email Send Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNetworkError) ...[
                  Text(
                    'Unable to connect to email service',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Failed to send setup email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text('Possible causes:', style: TextStyle(fontSize: 13)),
                  SizedBox(height: 8),
                  Text(
                    '• Email service is temporarily unavailable',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Invalid email address',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Network connectivity issues',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• SendGrid service limits reached',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                SizedBox(height: 16),
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
                      Text(
                        '💡 What to do:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      if (isNetworkError) ...[
                        Text(
                          '• Check your internet connection',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Disable VPN if active',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Check firewall settings',
                          style: TextStyle(fontSize: 12),
                        ),
                      ] else ...[
                        Text(
                          '• Wait a few minutes and try again',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          '• Verify the email address is correct',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                      Text(
                        '• Or share credentials manually with staff',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Technical details: ${e.toString()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resendSetupEmail(); // Retry
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isResendingEmail = false);
    }
  }

  Future<void> _toggleRestriction() async {
    final currentStatus = widget.staffData['isRestricted'] ?? false;
    final newStatus = !currentStatus;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus ? 'Restrict Staff?' : 'Remove Restriction?'),
        content: Text(
          newStatus
              ? 'This will prevent ${widget.staffData['fullName']} from logging in. They will not be able to access the system.'
              : 'This will allow ${widget.staffData['fullName']} to log in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.red : Colors.green,
            ),
            child: Text(newStatus ? 'Restrict' : 'Allow'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.staffDoc.id)
          .update({
            'isRestricted': newStatus,
            'restrictedAt': newStatus ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Staff restricted successfully'
                  : 'Restriction removed successfully',
            ),
            backgroundColor: newStatus ? Colors.red : Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStaff() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Staff?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete ${widget.staffData['fullName']}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('This action will:'),
            const SizedBox(height: 8),
            const Text('• Remove all staff data'),
            const Text('• Prevent them from logging in'),
            const Text('• Allow their email to be reused'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final staffEmail = widget.staffData['email'];

      // Step 1: Delete Firebase Auth user first
      if (staffEmail != null && staffEmail.toString().isNotEmpty) {
        print('[StaffDelete] Deleting Firebase Auth user for: $staffEmail');

        try {
          // Call Cloud Function to delete Firebase Auth user
          final response = await http.post(
            Uri.parse(
              'https://us-central1-lifecare-connect.cloudfunctions.net/deleteFirebaseAuthUser',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': staffEmail}),
          );

          if (response.statusCode == 200) {
            final result = json.decode(response.body);
            print(
              '[StaffDelete] ✅ Firebase Auth user deleted: ${result['message']}',
            );
          } else {
            print(
              '[StaffDelete] ⚠️ Failed to delete Firebase Auth user: ${response.body}',
            );
            // Continue with Firestore deletion even if Auth deletion fails
          }
        } catch (authError) {
          print(
            '[StaffDelete] ⚠️ Error calling delete auth function: $authError',
          );
          // Continue with Firestore deletion even if Auth deletion fails
        }
      }

      // Step 2: Delete staff document from Firestore (email can be reused)
      await FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.staffDoc.id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Staff deleted permanently')),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting staff: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRestricted = widget.staffData['isRestricted'] ?? false;
    final dob = widget.staffData['dateOfBirth'];
    String dobString = 'N/A';
    if (dob != null) {
      if (dob is Timestamp) {
        final date = dob.toDate();
        dobString = '${date.day}/${date.month}/${date.year}';
      } else if (dob is DateTime) {
        dobString = '${dob.day}/${dob.month}/${dob.year}';
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isRestricted
                        ? Colors.red.shade100
                        : Colors.teal.shade100,
                    child: Icon(
                      isRestricted ? Icons.block : Icons.person,
                      size: 32,
                      color: isRestricted ? Colors.red : Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.staffData['fullName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.staffData['profession'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Details
              _buildDetailRow(
                Icons.badge,
                'Staff ID',
                widget.staffData['staffId'] ?? 'N/A',
              ),
              _buildDetailRow(
                Icons.email,
                'Email',
                widget.staffData['email'] ?? 'N/A',
              ),
              _buildDetailRow(
                Icons.phone,
                'Phone',
                widget.staffData['phone'] ?? 'N/A',
              ),
              _buildDetailRow(Icons.cake, 'Date of Birth', dobString),
              _buildDetailRow(
                Icons.business,
                'Department',
                widget.staffData['department'] ?? 'N/A',
              ),
              _buildDetailRow(
                Icons.info_outline,
                'Status',
                _getStatusText(
                  widget.staffData['status'] ?? 'pending',
                  isRestricted,
                ),
              ),
              _buildVerificationStatusRow(),
              if (widget.staffData['lastEmailSentAt'] != null)
                _buildLastEmailSentRow(),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Action Buttons
              if (_isLoading || _isResendingEmail)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  children: [
                    // Show resend email button for pending/unverified accounts
                    if (_shouldShowResendEmail())
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _resendSetupEmail,
                              icon: const Icon(Icons.email),
                              label: const Text('Resend Setup Email'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleRestriction,
                        icon: Icon(
                          isRestricted ? Icons.check_circle : Icons.block,
                        ),
                        label: Text(
                          isRestricted
                              ? 'Remove Restriction'
                              : 'Restrict Login',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRestricted
                              ? Colors.green
                              : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _deleteStaff,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Staff Permanently'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowResendEmail() {
    final status = widget.staffData['status'] ?? 'pending';
    final emailVerified = widget.staffData['emailVerified'] ?? false;
    final isRestricted = widget.staffData['isRestricted'] ?? false;

    // Show resend button if account is pending OR not email verified AND not restricted
    return !isRestricted && (status == 'pending' || !emailVerified);
  }

  Widget _buildVerificationStatusRow() {
    final emailVerified = widget.staffData['emailVerified'] ?? false;
    final status = widget.staffData['status'] ?? 'pending';

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (emailVerified && status == 'active') {
      statusText = 'Email Verified ✓';
      statusColor = Colors.green;
      statusIcon = Icons.verified;
    } else if (status == 'pending') {
      statusText = 'Email Verification Pending';
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    } else {
      statusText = 'Email Not Verified';
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Verification',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastEmailSentRow() {
    final lastEmailSent = widget.staffData['lastEmailSentAt'];
    final resendCount = widget.staffData['emailResendCount'] ?? 0;

    String timeText = 'N/A';
    if (lastEmailSent != null) {
      if (lastEmailSent is Timestamp) {
        final date = lastEmailSent.toDate();
        final now = DateTime.now();
        final difference = now.difference(date);

        if (difference.inDays > 0) {
          timeText = '${difference.inDays} day(s) ago';
        } else if (difference.inHours > 0) {
          timeText = '${difference.inHours} hour(s) ago';
        } else if (difference.inMinutes > 0) {
          timeText = '${difference.inMinutes} minute(s) ago';
        } else {
          timeText = 'Just now';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Email Sent',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeText${resendCount > 0 ? ' (Resent ${resendCount}x)' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status, bool isRestricted) {
    if (isRestricted) return 'RESTRICTED';
    switch (status.toLowerCase()) {
      case 'active':
        return 'ACTIVE';
      case 'pending':
        return 'PENDING SETUP';
      default:
        return status.toUpperCase();
    }
  }
}
