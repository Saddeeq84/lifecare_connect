// approvals_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lifecare_connect/core/utils/email_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Users'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Review and manage user accounts',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView(
                children: [
                  _buildUserCard(
                    context,
                    icon: Icons.pending_actions,
                    title: 'Pending Approvals',
                    subtitle: 'Review all pending account requests',
                    color: Colors.orange,
                    count: _getPendingCount(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const _UserListScreen(
                            title: 'Pending Approvals',
                            role: null,
                            isApproved: false,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildUserCard(
                    context,
                    icon: Icons.health_and_safety,
                    title: 'Community Health Workers',
                    subtitle: 'Manage CHW accounts',
                    color: Colors.blue,
                    count: _getRoleCount('chw'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const _UserListScreen(
                            title: 'Community Health Workers',
                            role: 'chw',
                            isApproved: null,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildUserCard(
                    context,
                    icon: Icons.medical_services,
                    title: 'Doctors',
                    subtitle: 'Manage doctor accounts',
                    color: Colors.green,
                    count: _getRoleCount('doctor'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const _UserListScreen(
                            title: 'Doctors',
                            role: 'doctor',
                            isApproved: null,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget count,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  count,
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getPendingCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isApproved', isEqualTo: false)
          .where('isRejected', isNotEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        );
      },
    );
  }

  Widget _getRoleCount(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final color = role == 'chw' ? Colors.blue : Colors.green;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        );
      },
    );
  }
}

class _UserListScreen extends StatelessWidget {
  final String title;
  final String? role;
  final bool? isApproved;

  const _UserListScreen({
    required this.title,
    required this.role,
    required this.isApproved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.teal),
      body: _ApprovalList(role: role, isApproved: isApproved),
    );
  }
}

class _ApprovalList extends StatelessWidget {
  final String? role;
  final bool?
  isApproved; // Made nullable to show both pending and approved CHWs

  const _ApprovalList({required this.role, required this.isApproved});

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

      // Create a record of the deletion for audit purposes
      await FirebaseFirestore.instance
          .collection('deleted_accounts')
          .doc(userId)
          .set({
            'userId': userId,
            'email': email,
            'name': name,
            'rejectionReason': reason ?? '',
            'deletedAt': FieldValue.serverTimestamp(),
            'deletedBy': 'admin',
            'deletionType': 'rejection',
          });

      // Delete the user document from Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // Note: Firebase Auth user deletion must be done via Firebase Admin SDK in a Cloud Function
      // We'll create a callable function for this
      try {
        final functions = FirebaseFunctions.instance;
        await functions.httpsCallable('deleteUserAuth').call({'uid': userId});
        print('✅ Firebase Auth user deleted successfully');
      } catch (e) {
        print('⚠️ Failed to delete Firebase Auth user: $e');
        // Even if Auth deletion fails, Firestore deletion succeeded
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Account completely deleted. User can now register again with the same email.',
          ),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Account deletion failed: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Account deletion failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'users',
    );

    if (role == null) {
      // Pending users (doctors, facilities, and CHWs)
      // Note: We can't filter by isRejected in the query because it would exclude accounts
      // that don't have this field (created before this field was added)
      // We'll filter rejected accounts in the StreamBuilder instead
      query = query
          .where('role', whereIn: ['doctor', 'facility', 'chw'])
          .where('isApproved', isEqualTo: false);
    } else if (isApproved == null) {
      // Show all users (both pending and approved) for specific role
      query = query.where('role', isEqualTo: role);
    } else {
      // Filter by specific approval status
      query = query
          .where('role', isEqualTo: role)
          .where('isApproved', isEqualTo: isApproved);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('❌ [ADMIN APPROVALS] Error loading users: ${snapshot.error}');
          return const Center(child: Text('❌ Error loading users'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        print(
          '📊 [ADMIN APPROVALS] Total documents from query: ${snapshot.data!.docs.length}',
        );
        print(
          '🔍 [ADMIN APPROVALS] Query role filter: $role, isApproved filter: $isApproved',
        );

        // Log all documents before filtering
        for (var doc in snapshot.data!.docs) {
          final data = doc.data();
          print(
            '📄 [ADMIN APPROVALS] Document ${doc.id}: role=${data['role']}, isApproved=${data['isApproved']}, isRejected=${data['isRejected']}, fullName=${data['fullName']}',
          );
        }

        // Filter out rejected accounts (accounts where isRejected == true)
        // This handles both accounts with isRejected: true and accounts without the field
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final isRejected = data['isRejected'] ?? false;
          return !isRejected; // Exclude rejected accounts
        }).toList();

        print(
          '✅ [ADMIN APPROVALS] Documents after filtering rejected: ${docs.length}',
        );

        if (docs.isEmpty) {
          print('⚠️ [ADMIN APPROVALS] No users found after filtering');
          return const Center(child: Text('No users found.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = docs[index].data();
            final fullName = user['fullName'] ?? user['name'] ?? 'Unnamed User';
            final email = user['email'] ?? 'No Email';
            final userRole = user['role'] ?? 'Unknown';

            // All users (CHW, doctors, facilities) use the same ListTile format
            return ListTile(
              leading: const Icon(Icons.account_circle, size: 32),
              title: Text(fullName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(email),
                  Text("Role: $userRole", style: const TextStyle(fontSize: 12)),
                  Text(
                    user['isRejected'] == true
                        ? "Status: Rejected"
                        : user['isApproved'] == true
                        ? "Status: Approved"
                        : "Status: Pending",
                    style: TextStyle(
                      fontSize: 12,
                      color: user['isRejected'] == true
                          ? Colors.red
                          : user['isApproved'] == true
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: user['isRejected'] == true
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Restore Account'),
                                content: Text(
                                  'Restore ${user['fullName'] ?? user['name'] ?? 'this user'}\'s account? This will set it back to pending approval.',
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
                                      backgroundColor: Colors.green,
                                    ),
                                    child: const Text('Restore'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(docs[index].id)
                                    .update({
                                      'isRejected': false,
                                      'isApproved': false,
                                      'rejectionReason': FieldValue.delete(),
                                    });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✅ Account restored to pending approval',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Failed to restore: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Permanently Delete Account'),
                                content: Text(
                                  '⚠️ PERMANENTLY DELETE ${user['fullName'] ?? user['name'] ?? 'this user'}\'s account?\n\nThis action CANNOT be undone. All their data, appointments, and messages will be permanently removed.',
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
                                    child: const Text('DELETE PERMANENTLY'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                // Delete the user document completely
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(docs[index].id)
                                    .delete();

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✅ Account permanently deleted',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Failed to delete: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : ((isApproved == null && user['isApproved'] != true) ||
                        (isApproved == false))
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Format date of birth
                            String formatDob(dynamic dobValue) {
                              if (dobValue == null) return 'Not provided';
                              if (dobValue is Timestamp) {
                                return DateFormat(
                                  'MMMM dd, yyyy',
                                ).format(dobValue.toDate());
                              }
                              if (dobValue is String) {
                                try {
                                  final date = DateTime.parse(dobValue);
                                  return DateFormat(
                                    'MMMM dd, yyyy',
                                  ).format(date);
                                } catch (e) {
                                  return dobValue;
                                }
                              }
                              return dobValue.toString();
                            }

                            // Format created at timestamp
                            String formatCreatedAt(dynamic createdAtValue) {
                              if (createdAtValue == null) {
                                return 'Not available';
                              }
                              if (createdAtValue is Timestamp) {
                                return DateFormat(
                                  'MMM dd, yyyy • hh:mm a',
                                ).format(createdAtValue.toDate());
                              }
                              return 'Not available';
                            }

                            // Review dialog
                            showDialog<void>(
                              context: context,
                              builder: (context) => Dialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Container(
                                  width: 600,
                                  constraints: const BoxConstraints(
                                    maxHeight: 700,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Header
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade600,
                                              Colors.blue.shade800,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.person_search,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            const Expanded(
                                              child: Text(
                                                'Account Review',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Content
                                      Flexible(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // User Info Section
                                              for (final entry in user.entries)
                                                if (entry.value != null &&
                                                    entry.value
                                                        .toString()
                                                        .isNotEmpty &&
                                                    entry.key != 'password' &&
                                                    entry.key != 'isApproved' &&
                                                    entry.key != 'isRejected' &&
                                                    entry.key !=
                                                        'licenseFile' &&
                                                    entry.key != 'licenseUrl' &&
                                                    entry.key !=
                                                        'credentialUrl' &&
                                                    entry.key != 'credential' &&
                                                    entry.key != 'license' &&
                                                    entry.key !=
                                                        'govDocument' &&
                                                    entry.key !=
                                                        'registrationDocUrl' &&
                                                    entry.key !=
                                                        'documentUrl' &&
                                                    entry.key !=
                                                        'qualificationUrl' &&
                                                    entry.key !=
                                                        'certificateUrl' &&
                                                    entry.key != 'photoUrl')
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.grey.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Expanded(
                                                            flex: 2,
                                                            child: Text(
                                                              entry.key
                                                                  .replaceAll(
                                                                    RegExp(
                                                                      r'([A-Z])',
                                                                    ),
                                                                    ' \$1',
                                                                  )
                                                                  .trim()
                                                                  .split(' ')
                                                                  .map(
                                                                    (word) =>
                                                                        word[0]
                                                                            .toUpperCase() +
                                                                        word.substring(
                                                                          1,
                                                                        ),
                                                                  )
                                                                  .join(' '),
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                              entry.key ==
                                                                          'dob' ||
                                                                      entry.key ==
                                                                          'dateOfBirth'
                                                                  ? formatDob(
                                                                      entry
                                                                          .value,
                                                                    )
                                                                  : entry.key ==
                                                                        'createdAt'
                                                                  ? formatCreatedAt(
                                                                      entry
                                                                          .value,
                                                                    )
                                                                  : entry.value
                                                                        .toString(),
                                                              style: const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),

                                              const SizedBox(height: 24),

                                              // Documents Section
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.folder_outlined,
                                                          color: Colors
                                                              .blue
                                                              .shade700,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'Uploaded Documents',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .blue
                                                                .shade900,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ...[
                                                      [
                                                        'licenseUrl',
                                                        'License Document',
                                                        Icons.card_membership,
                                                      ],
                                                      [
                                                        'credentialUrl',
                                                        'CHW Credential/License',
                                                        Icons.verified,
                                                      ],
                                                      [
                                                        'credential',
                                                        'CHW Credential',
                                                        Icons.verified,
                                                      ],
                                                      [
                                                        'license',
                                                        'License/Credential',
                                                        Icons.card_membership,
                                                      ],
                                                      [
                                                        'govDocument',
                                                        'Government Document',
                                                        Icons.badge,
                                                      ],
                                                      [
                                                        'registrationDocUrl',
                                                        'Registration Document',
                                                        Icons.app_registration,
                                                      ],
                                                      [
                                                        'documentUrl',
                                                        'Submitted Document',
                                                        Icons.description,
                                                      ],
                                                      [
                                                        'qualificationUrl',
                                                        'Qualification Document',
                                                        Icons.school,
                                                      ],
                                                      [
                                                        'certificateUrl',
                                                        'Certificate',
                                                        Icons.workspace_premium,
                                                      ],
                                                    ].map((docField) {
                                                      final value =
                                                          user[docField[0]];
                                                      if (value != null &&
                                                          value
                                                              .toString()
                                                              .trim()
                                                              .isNotEmpty) {
                                                        return Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .blue
                                                                  .shade100,
                                                            ),
                                                          ),
                                                          child: InkWell(
                                                            onTap: () async {
                                                              final url = value
                                                                  .toString();
                                                              final uri =
                                                                  Uri.tryParse(
                                                                    url,
                                                                  );
                                                              if (uri != null &&
                                                                  await canLaunchUrl(
                                                                    uri,
                                                                  )) {
                                                                await launchUrl(
                                                                  uri,
                                                                );
                                                              }
                                                            },
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              child: Row(
                                                                children: [
                                                                  Container(
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          8,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      color: Colors
                                                                          .blue
                                                                          .shade50,
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            8,
                                                                          ),
                                                                    ),
                                                                    child: Icon(
                                                                      docField[2]
                                                                          as IconData,
                                                                      color: Colors
                                                                          .blue
                                                                          .shade700,
                                                                      size: 20,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      docField[1]
                                                                          as String,
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        fontSize:
                                                                            14,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Icon(
                                                                    Icons
                                                                        .open_in_new,
                                                                    color: Colors
                                                                        .blue
                                                                        .shade600,
                                                                    size: 18,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return const SizedBox.shrink();
                                                    }),
                                                    if (![
                                                      'licenseUrl',
                                                      'credentialUrl',
                                                      'credential',
                                                      'license',
                                                      'govDocument',
                                                      'registrationDocUrl',
                                                      'documentUrl',
                                                      'qualificationUrl',
                                                      'certificateUrl',
                                                    ].any(
                                                      (field) =>
                                                          user[field] != null &&
                                                          user[field]
                                                              .toString()
                                                              .trim()
                                                              .isNotEmpty,
                                                    ))
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .orange
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .orange
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .warning_amber,
                                                              color: Colors
                                                                  .orange
                                                                  .shade700,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                userRole.toString().toLowerCase() ==
                                                                        'chw'
                                                                    ? 'No credential documents uploaded'
                                                                    : 'No documents uploaded',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .orange
                                                                      .shade700,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Footer
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          border: Border(
                                            top: BorderSide(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text(
                                                'Close',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text('Review'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) {
                                // Check if CHW has credentials
                                final isChwWithoutCredentials =
                                    userRole.toString().toLowerCase() ==
                                        'chw' &&
                                    ![
                                      'licenseUrl',
                                      'credentialUrl',
                                      'credential',
                                      'license',
                                      'govDocument',
                                      'registrationDocUrl',
                                      'documentUrl',
                                      'qualificationUrl',
                                      'certificateUrl',
                                    ].any(
                                      (field) =>
                                          user[field] != null &&
                                          user[field]
                                              .toString()
                                              .trim()
                                              .isNotEmpty,
                                    );

                                return AlertDialog(
                                  title: const Text('Confirm Approval'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Are you sure you want to approve $fullName?',
                                      ),
                                      if (isChwWithoutCredentials) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            border: Border.all(
                                              color: Colors.orange.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                                                  'Warning: This CHW has not uploaded any credential documents. Consider requesting credentials before approval.',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirm == true) {
                              await _approveUser(docs[index].id, context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Approved $fullName')),
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
                            final reasonController = TextEditingController();
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
                              await _ApprovalList.rejectUser(
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
                  : (user['isApproved'] == true
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // View details dialog for approved users
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) => Dialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Container(
                                        width: 500,
                                        constraints: const BoxConstraints(
                                          maxHeight: 700,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Header
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                color: userRole == 'doctor'
                                                    ? Colors.green
                                                    : Colors.blue,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        16,
                                                      ),
                                                      topRight: Radius.circular(
                                                        16,
                                                      ),
                                                    ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    userRole == 'doctor'
                                                        ? Icons.medical_services
                                                        : Icons
                                                              .health_and_safety,
                                                    color: Colors.white,
                                                    size: 28,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text(
                                                      'User Details',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Content
                                            Flexible(
                                              child: SingleChildScrollView(
                                                padding: const EdgeInsets.all(
                                                  24,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Profile Picture
                                                    if (user['photoUrl'] !=
                                                            null &&
                                                        user['photoUrl']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Center(
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 20,
                                                              ),
                                                          child: CircleAvatar(
                                                            radius: 60,
                                                            backgroundImage:
                                                                NetworkImage(
                                                                  user['photoUrl'],
                                                                ),
                                                            backgroundColor:
                                                                Colors
                                                                    .grey
                                                                    .shade200,
                                                          ),
                                                        ),
                                                      )
                                                    else
                                                      Center(
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 20,
                                                              ),
                                                          child: CircleAvatar(
                                                            radius: 60,
                                                            backgroundColor:
                                                                userRole ==
                                                                    'doctor'
                                                                ? Colors
                                                                      .green
                                                                      .shade100
                                                                : Colors
                                                                      .blue
                                                                      .shade100,
                                                            child: Icon(
                                                              userRole ==
                                                                      'doctor'
                                                                  ? Icons
                                                                        .medical_services
                                                                  : Icons
                                                                        .health_and_safety,
                                                              size: 60,
                                                              color:
                                                                  userRole ==
                                                                      'doctor'
                                                                  ? Colors.green
                                                                  : Colors.blue,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                    // Full Name
                                                    _buildDetailCard(
                                                      icon: Icons.person,
                                                      label: 'Full Name',
                                                      value:
                                                          user['fullName'] ??
                                                          user['name'] ??
                                                          'Not provided',
                                                      color: Colors.purple,
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // Specialization
                                                    _buildDetailCard(
                                                      icon: Icons.work,
                                                      label:
                                                          userRole == 'doctor'
                                                          ? 'Specialization'
                                                          : 'Role',
                                                      value:
                                                          user['specialization'] ??
                                                          user['specialty'] ??
                                                          userRole
                                                              .toUpperCase(),
                                                      color: Colors.orange,
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // Email
                                                    _buildDetailCard(
                                                      icon: Icons.email,
                                                      label: 'Email',
                                                      value:
                                                          user['email'] ??
                                                          'Not provided',
                                                      color: Colors.blue,
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // Phone Number
                                                    _buildDetailCard(
                                                      icon: Icons.phone,
                                                      label: 'Phone Number',
                                                      value:
                                                          user['phoneNumber'] ??
                                                          user['phone'] ??
                                                          'Not provided',
                                                      color: Colors.green,
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // License Number
                                                    if (user['licenseNumber'] !=
                                                            null ||
                                                        user['license'] != null)
                                                      Column(
                                                        children: [
                                                          _buildDetailCard(
                                                            icon: Icons.badge,
                                                            label:
                                                                'License Number',
                                                            value:
                                                                user['licenseNumber'] ??
                                                                user['license'] ??
                                                                'Not provided',
                                                            color: Colors.teal,
                                                          ),
                                                          const SizedBox(
                                                            height: 12,
                                                          ),
                                                        ],
                                                      ),

                                                    // Bio
                                                    if (user['bio'] != null &&
                                                        user['bio']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .info_outline,
                                                                  color: Colors
                                                                      .indigo,
                                                                  size: 20,
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                const Text(
                                                                  'Bio',
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .black87,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 8,
                                                            ),
                                                            Text(
                                                              user['bio'],
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .grey
                                                                    .shade700,
                                                                height: 1.4,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                    const SizedBox(height: 20),

                                                    // Documents Section
                                                    const Divider(),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.folder_outlined,
                                                          color: Colors
                                                              .grey
                                                              .shade700,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'Documents',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .grey
                                                                .shade800,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),

                                                    ...[
                                                      [
                                                        'licenseUrl',
                                                        'License Document',
                                                        Icons.card_membership,
                                                      ],
                                                      [
                                                        'credentialUrl',
                                                        'Credential/License',
                                                        Icons.verified,
                                                      ],
                                                      [
                                                        'credential',
                                                        'Credential',
                                                        Icons.verified,
                                                      ],
                                                      [
                                                        'license',
                                                        'License',
                                                        Icons.card_membership,
                                                      ],
                                                      [
                                                        'govDocument',
                                                        'Government ID',
                                                        Icons.badge,
                                                      ],
                                                      [
                                                        'registrationDocUrl',
                                                        'Registration',
                                                        Icons.app_registration,
                                                      ],
                                                      [
                                                        'documentUrl',
                                                        'Document',
                                                        Icons.description,
                                                      ],
                                                      [
                                                        'qualificationUrl',
                                                        'Qualification',
                                                        Icons.school,
                                                      ],
                                                      [
                                                        'certificateUrl',
                                                        'Certificate',
                                                        Icons.workspace_premium,
                                                      ],
                                                    ].map((docField) {
                                                      final value =
                                                          user[docField[0]];
                                                      if (value != null &&
                                                          value
                                                              .toString()
                                                              .trim()
                                                              .isNotEmpty) {
                                                        return Container(
                                                          margin:
                                                              const EdgeInsets.only(
                                                                bottom: 8,
                                                              ),
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .blue
                                                                .shade50,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .blue
                                                                  .shade200,
                                                            ),
                                                          ),
                                                          child: InkWell(
                                                            onTap: () async {
                                                              final url = value
                                                                  .toString();
                                                              final uri =
                                                                  Uri.tryParse(
                                                                    url,
                                                                  );
                                                              if (uri != null &&
                                                                  await canLaunchUrl(
                                                                    uri,
                                                                  )) {
                                                                await launchUrl(
                                                                  uri,
                                                                );
                                                              }
                                                            },
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  docField[2]
                                                                      as IconData,
                                                                  color: Colors
                                                                      .blue
                                                                      .shade700,
                                                                  size: 20,
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    docField[1]
                                                                        as String,
                                                                    style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                      fontSize:
                                                                          14,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const Icon(
                                                                  Icons
                                                                      .open_in_new,
                                                                  color: Colors
                                                                      .blue,
                                                                  size: 18,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                      return const SizedBox.shrink();
                                                    }),

                                                    if (![
                                                      'licenseUrl',
                                                      'credentialUrl',
                                                      'credential',
                                                      'license',
                                                      'govDocument',
                                                      'registrationDocUrl',
                                                      'documentUrl',
                                                      'qualificationUrl',
                                                      'certificateUrl',
                                                    ].any(
                                                      (field) =>
                                                          user[field] != null &&
                                                          user[field]
                                                              .toString()
                                                              .trim()
                                                              .isNotEmpty,
                                                    ))
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .orange
                                                              .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .orange
                                                                .shade200,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .warning_amber,
                                                              color: Colors
                                                                  .orange
                                                                  .shade700,
                                                              size: 20,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                userRole.toString().toLowerCase() ==
                                                                        'chw'
                                                                    ? 'No credential documents uploaded'
                                                                    : 'No documents uploaded',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .orange
                                                                      .shade700,
                                                                  fontSize: 13,
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
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: const Size(60, 32),
                                ),
                                child: const Text(
                                  'View Details',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Revoke'),
                                      content: const Text(
                                        'Are you sure you want to revoke this account approval?',
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
                          )
                        : const Icon(Icons.check_circle, color: Colors.green)),
            );
          },
        );
      },
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
      if (userData != null &&
          userData['email'] != null &&
          (userData['role'] == 'doctor' ||
              userData['role'] == 'chw' ||
              userData['role'] == 'facility')) {
        final name = userData['fullName'] ?? userData['name'] ?? '';
        await sendAccountApprovedEmail(userData['email'], name);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ User approved')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('⚠️ User approval revoked')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Revoke failed: $e')));
    }
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
