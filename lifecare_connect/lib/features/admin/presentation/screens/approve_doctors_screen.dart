// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ApproveDoctorsScreen extends StatelessWidget {
  const ApproveDoctorsScreen({super.key});

  Future<void> _approveDoctor(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'isApproved': true, 'isRejected': false});
  }

  Future<void> _rejectDoctor(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'isApproved': false, 'isRejected': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Doctor Approvals'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'doctor')
            .where('isApproved', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No pending doctor approvals'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doctor = docs[index];
              final name = doctor['fullName'] ?? doctor['name'] ?? 'No Name';
              final email = doctor['email'] ?? 'No Email';
              final specialization = doctor['specialization'] ?? 'N/A';
              final gender = doctor['gender'] ?? 'N/A';
              final dob = doctor['dob'] ?? 'N/A';
              final licenseUrl = doctor['licenseUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(name),
                  subtitle: Text(email),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Doctor Details'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: $name'),
                              Text('Email: $email'),
                              Text('Specialization: $specialization'),
                              Text('Gender: $gender'),
                              Text('DOB: $dob'),
                              const SizedBox(height: 12),
                              if (licenseUrl.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('View License'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Practicing License'),
                                        content: SizedBox(
                                          width: 400,
                                          height: 500,
                                          child: licenseUrl.endsWith('.pdf')
                                              ? const Center(child: Text('PDF viewing not supported in dialog. Open in browser.'))
                                              : Image.network(licenseUrl),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Close'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await launchUrl(Uri.parse(licenseUrl));
                                            },
                                            child: const Text('Open in Browser'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              if (licenseUrl.isEmpty)
                                const Text('No license uploaded.'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Approval'),
                                  content: Text('Are you sure you want to approve $name?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _approveDoctor(doctor.id);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Approved $name')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                            ),
                            child: const Text('Approve'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Rejection'),
                                  content: Text('Are you sure you want to reject $name?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _rejectDoctor(doctor.id);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Rejected $name')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Approval'),
                              content: Text('Are you sure you want to approve $name?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Approve'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _approveDoctor(doctor.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Approved $name')),
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Rejection'),
                              content: Text('Are you sure you want to reject $name?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _rejectDoctor(doctor.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Rejected $name')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Reject'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
