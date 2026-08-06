import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorFacilityReferralScreen extends StatelessWidget {
  const DoctorFacilityReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Facility Referral & Messaging")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('facilities')
            .where('isApproved', isEqualTo: true)
            .orderBy('name')
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

          final facilities = snapshot.data?.docs ?? [];

          if (facilities.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No facilities available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final facility = facilities[index];
              final facilityData = facility.data() as Map<String, dynamic>;
              final facilityName = facilityData['name'] ?? 'Unknown Facility';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(
                      _getFacilityIcon(facilityData['type']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    facilityName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (facilityData['type'] != null)
                        Text('Type: ${facilityData['type']}'),
                      if (facilityData['location'] != null)
                        Text('Location: ${facilityData['location']}'),
                      if (facilityData['contactPerson'] != null)
                        Text('Contact: ${facilityData['contactPerson']}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Refer patient or message $facilityName'),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getFacilityIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'hospital':
        return Icons.local_hospital;
      case 'clinic':
        return Icons.medical_services;
      case 'laboratory':
        return Icons.biotech;
      case 'pharmacy':
        return Icons.medication;
      case 'imaging center':
        return Icons.camera_alt;
      default:
        return Icons.business;
    }
  }
}
