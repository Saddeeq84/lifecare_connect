// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lifecare_connect/core/utils/email_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminFacilitiesListScreen extends StatelessWidget {
  const AdminFacilitiesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Facilities List'),
          backgroundColor: Colors.indigo.shade700,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FacilityList(isApproved: false),
            _FacilityList(isApproved: true),
          ],
        ),
      ),
    );
  }
}

class _FacilityList extends StatelessWidget {
  final bool isApproved;

  const _FacilityList({required this.isApproved});

  static Future<void> rejectUser(
    String userId,
    BuildContext context, {
    String? reason,
    String? email,
    String? name,
  }) async {
    try {
      // Show confirmation dialog for complete account deletion
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Account Deletion'),
          content: const Text(
            'This will completely remove the account from both Firestore and Authentication, allowing the user to register again with the same email. Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete Completely'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Send rejection email first (before deletion)
      if (email != null && name != null && reason != null) {
        try {
          print('📧 Sending rejection email to $email (Name: $name)');
          await sendAccountRejectedEmail(email, name, reason);
          print('✅ Rejection email sent successfully');
        } catch (emailError) {
          print('⚠️ Failed to send rejection email: $emailError');
        }
      }

      // Delete Firestore document
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // Delete Firebase Auth account using Cloud Function
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'deleteFirebaseAuthUser',
        );
        await callable.call({'uid': userId});
        print('✅ Firebase Auth user deleted successfully');
      } catch (e) {
        print('⚠️ Failed to delete Firebase Auth user: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Account completely deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Deletion failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'facility');

    // Filter by approval status
    query = query.where('isApproved', isEqualTo: isApproved);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              isApproved ? 'No approved facilities' : 'No pending facilities',
              style: const TextStyle(fontSize: 16),
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final user = docs[index].data() as Map<String, dynamic>;
            final fullName =
                user['fullName'] ??
                user['name'] ??
                user['facilityName'] ??
                'N/A';
            final email = user['email'] ?? 'No email';
            final phone = user['phone'] ?? 'No phone';
            final location = user['location'] ?? 'No location';
            final facilityType = user['facilityType'] ?? 'N/A';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ExpansionTile(
                leading: const Icon(Icons.business, color: Colors.indigo),
                title: Text(
                  fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Type: $facilityType • $location'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Email', email),
                        _buildInfoRow('Phone', phone),
                        _buildInfoRow('Location', location),
                        _buildInfoRow('Type', facilityType),
                        if (user['contactPerson'] != null)
                          _buildInfoRow(
                            'Contact Person',
                            user['contactPerson'],
                          ),
                        if (user['licenseDocument'] != null) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(user['licenseDocument']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            icon: const Icon(Icons.description),
                            label: const Text('View License Document'),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 16.0,
                      left: 16,
                      right: 16,
                    ),
                    child: !isApproved
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Approval'),
                                      content: Text(
                                        'Are you sure you want to approve $fullName?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: const Text('Approve'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _approveUser(docs[index].id, context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Approved $fullName'),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                ),
                                child: const Text('Approve'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final reasonController =
                                      TextEditingController();
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Rejection'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Please provide a reason for rejection:',
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: reasonController,
                                            maxLines: 3,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              hintText: 'Reason for rejection',
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _FacilityList.rejectUser(
                                      docs[index].id,
                                      context,
                                      reason: reasonController.text.trim(),
                                      email: user['email'],
                                      name: fullName,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Reject'),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Revoke'),
                                      content: const Text(
                                        'Are you sure you want to revoke this facility approval?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Revoke'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    _revokeUser(docs[index].id, context);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  minimumSize: const Size(60, 32),
                                ),
                                child: const Text(
                                  'Revoke',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _approveUser(String userId, BuildContext context) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userDoc.data();
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isApproved': true,
      });
      if (userData != null && userData['email'] != null) {
        final name =
            userData['fullName'] ??
            userData['name'] ??
            userData['facilityName'] ??
            '';
        await sendAccountApprovedEmail(userData['email'], name);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Facility approved')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Approval failed: $e')));
    }
  }

  Future<void> _revokeUser(String userId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isApproved': false,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Facility approval revoked')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Revoke failed: $e')));
    }
  }
}
