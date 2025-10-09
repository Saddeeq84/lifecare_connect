import 'facility_staff_create_account.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityStaffListScreen extends StatelessWidget {
  final String facilityName;
  const FacilityStaffListScreen({super.key, required this.facilityName});

  @override
  Widget build(BuildContext context) {
    final collection = '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';
    return Scaffold(
      appBar: AppBar(title: const Text('All Staff'), leading: const BackButton()),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Register Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FacilityStaffCreateAccountScreen(facilityName: facilityName),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection(collection).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No staff found'));
                return ListView(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['fullName'] ?? ''),
                      subtitle: Text('Staff ID: ${data['staffId'] ?? ''}'),
                      trailing: Text(data['status'] ?? ''),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
