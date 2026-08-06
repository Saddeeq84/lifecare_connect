// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../facility/presentation/screens/patient_facility_booking_screen.dart';
import 'facility_services_view_screen.dart';
import 'patient_pharmacy_cart_screen.dart';

typedef FacilitySelectedCallback =
    void Function(String facilityId, Map<String, dynamic> facilityData);

class PatientFacilitySelectionScreen extends StatelessWidget {
  final String categoryType;
  final String categoryLabel;
  final FacilitySelectedCallback? onFacilitySelected;

  const PatientFacilitySelectionScreen({
    super.key,
    required this.categoryType,
    required this.categoryLabel,
    this.onFacilitySelected,
  });

  void _onFacilitySelected(BuildContext context, DocumentSnapshot facilityDoc) {
    final facilityData = facilityDoc.data() as Map<String, dynamic>;
    final facilityType =
        categoryType; // 'Pharmacy', 'Laboratory', 'Scan Center'

    if (onFacilitySelected != null) {
      onFacilitySelected!(facilityDoc.id, facilityData);
    } else {
      // Route to appropriate screen based on facility type
      if (facilityType == 'Pharmacy') {
        // Navigate to pharmacy cart screen for product browsing
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientPharmacyCartScreen(
              facilityId: facilityDoc.id,
              facilityData: facilityData,
            ),
          ),
        );
      } else {
        // Navigate to booking screen for lab/scan centers (appointment booking)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientFacilityBookingScreen(
              facilityId: facilityDoc.id,
              facilityData: facilityData,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Healthcare Facility'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade50, Colors.teal.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.medical_services,
                  size: 48,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Request Medical Services',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a healthcare facility to request services or medical supplies',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Facility Types Info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    const Text(
                      'Available Services',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Laboratory Tests & Diagnostics\n'
                  '• Pharmacy & Medical Supplies\n'
                  '• Imaging & Scan Services\n'
                  '• Physiotherapy & Rehabilitation\n'
                  '• Specialized Medical Procedures',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // Facility List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Healthcare Facilities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a facility to request their services',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildFacilityList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilityList() {
    // Query facilities by type field
    final facilitiesQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'facility')
        .where('isApproved', isEqualTo: true)
        .where('type', isEqualTo: categoryType);

    return StreamBuilder<QuerySnapshot>(
      stream: facilitiesQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final docs = snapshot.data?.docs ?? [];

        // Filter to only show active facilities (or those without isActive field for backward compatibility)
        final activeFacilities = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // If isActive field doesn't exist, assume facility is active (backward compatibility)
          // If isActive field exists, only show if it's true
          return !data.containsKey('isActive') || data['isActive'] == true;
        }).toList();

        if (activeFacilities.isEmpty) {
          return const Center(child: Text("No healthcare facilities found."));
        }

        return ListView.builder(
          itemCount: activeFacilities.length,
          itemBuilder: (context, index) {
            final facility = activeFacilities[index];
            final data = facility.data() as Map<String, dynamic>;
            final name =
                data['facilityName'] ?? data['name'] ?? 'Unknown Facility';
            final type = data['type'] ?? data['facilityType'] ?? 'Unknown Type';
            final location =
                data['location'] ?? data['address'] ?? 'Unknown Location';
            final phone = data['phone'] ?? 'N/A';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(_getFacilityIcon(type), color: Colors.teal),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$type\n$location\nPhone: $phone'),
                    isThreeLine: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FacilityServicesViewScreen(
                                        facilityId: facility.id,
                                        facilityData: data,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.list_alt, size: 18),
                            label: const Text('View Services'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _onFacilitySelected(context, facility),
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('Request Service'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
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

  IconData _getFacilityIcon(String facilityType) {
    final type = facilityType.toLowerCase();

    if (type.contains('hospital')) {
      return Icons.local_hospital;
    } else if (type.contains('clinic') && type.contains('dental')) {
      return Icons.medical_information;
    } else if (type.contains('clinic') && type.contains('eye')) {
      return Icons.visibility;
    } else if (type.contains('clinic')) {
      return Icons.local_hospital;
    } else if (type.contains('laboratory') || type.contains('lab')) {
      return Icons.science;
    } else if (type.contains('pharmacy')) {
      return Icons.local_pharmacy;
    } else if (type.contains('scan') || type.contains('imaging')) {
      return Icons.monitor_heart;
    } else if (type.contains('physiotherapy')) {
      return Icons.accessibility;
    } else if (type.contains('mental health')) {
      return Icons.psychology;
    } else if (type.contains('sunhive')) {
      return Icons.health_and_safety;
    } else {
      return Icons.business;
    }
  }
}
