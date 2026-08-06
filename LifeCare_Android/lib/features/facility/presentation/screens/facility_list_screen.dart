import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_facility_booking_screen.dart';

class FacilityListScreen extends StatelessWidget {
  final String categoryType;
  final String categoryLabel;
  final void Function(String facilityId, Map<String, dynamic> facilityData)?
  onFacilitySelected;

  const FacilityListScreen({
    super.key,
    required this.categoryType,
    required this.categoryLabel,
    this.onFacilitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('facilities')
            .where('type', isEqualTo: categoryType)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load facilities.'));
          }

          final facilities = snapshot.data?.docs ?? [];

          if (facilities.isEmpty) {
            return const Center(
              child: Text('No facilities found in this category.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final doc = facilities[index];
              final facility = doc.data() as Map<String, dynamic>;
              final name = facility['name'] ?? 'Facility';
              final address = facility['address'] ?? '';
              final contact = facility['contact'] ?? '';
              final logoUrl = facility['logo_url'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: logoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            logoUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.local_hospital, color: Colors.green),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$address\n📞 $contact'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (onFacilitySelected != null) {
                      onFacilitySelected!(doc.id, facility);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientFacilityBookingScreen(
                            facilityId: doc.id,
                            facilityData: facility,
                          ),
                        ),
                      );
                    }
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

// -------------------- End of Facility List Screen --------------------
// This code provides a dynamic list of facilities based on category type, allowing users to view details
// and book appointments directly from the list.
