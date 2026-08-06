// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ApproveFacilitiesScreen extends StatelessWidget {
  const ApproveFacilitiesScreen({super.key});

  Future<void> _approveFacility(DocumentSnapshot facilityDoc) async {
    final userId = facilityDoc.id;
    final data = facilityDoc.data() as Map<String, dynamic>;

    // 1. Approve in users collection
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'isApproved': true,
    });

    // 2. Copy to facilities collection
    final facilityData = {
      'name': data['name'] ?? '',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'location': data['location'] ?? '',
      'type': data['type'] ?? 'General',
      'approvedAt': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('facilities')
        .doc(userId)
        .set(facilityData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Facility Approvals'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'facility')
            .where('isApproved', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final facilities = snapshot.data!.docs;

          if (facilities.isEmpty) {
            return const Center(child: Text('No pending facility approvals'));
          }

          return ListView.builder(
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final facility = facilities[index];
              final name = facility['name'] ?? 'No Name';
              final email = facility['email'] ?? 'No Email';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: const Icon(Icons.local_hospital),
                  title: Text(name),
                  subtitle: Text(email),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await _approveFacility(facility);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Approved $name')));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text('Approve'),
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
