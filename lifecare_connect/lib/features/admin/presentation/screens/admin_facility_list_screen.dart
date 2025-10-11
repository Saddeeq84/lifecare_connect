// screens/adminscreen/admin_facility_list_screen.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../sharedscreen/facility_list_widget.dart'; // Commented out - widget not found

class AdminFacilityListScreen extends StatelessWidget {
  final String? facilityType;

  const AdminFacilityListScreen({super.key, this.facilityType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          facilityType != null ? '$facilityType Facilities' : 'All Facilities',
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: facilityType != null
            ? FirebaseFirestore.instance
                  .collection('healthFacilities')
                  .where('type', isEqualTo: facilityType)
                  .snapshots()
            : FirebaseFirestore.instance
                  .collection('healthFacilities')
                  .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading facilities: ${snapshot.error}'),
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
                    'No facilities found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final facility = facilities[index];
              final data = facility.data() as Map<String, dynamic>?;

              if (data == null) return const SizedBox.shrink();

              final name = data['name'] ?? 'Unnamed Facility';
              final type = data['type'] ?? 'Unknown Type';
              final address = data['address'] ?? 'No address provided';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    child: const Icon(Icons.local_hospital, color: Colors.teal),
                  ),
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Type: $type'), Text('Address: $address')],
                  ),
                  onTap: () {
                    // Handle tap on facility item
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening details for $name')),
                    );
                    // You can push to a detail screen here if needed.
                    // Example: context.push('/admin/facility_details', extra: facility);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
