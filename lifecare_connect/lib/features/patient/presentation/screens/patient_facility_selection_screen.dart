// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../facility/presentation/screens/patient_facility_booking_screen.dart';

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
    if (onFacilitySelected != null) {
      onFacilitySelected!(
        facilityDoc.id,
        facilityDoc.data() as Map<String, dynamic>,
      );
    } else {
      // Navigate directly to booking screen for selected facility
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientFacilityBookingScreen(
            facilityId: facilityDoc.id,
            facilityData: facilityDoc.data() as Map<String, dynamic>,
          ),
        ),
      );
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
    // Support both 'type' and 'facilityType' for compatibility
    final facilitiesQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'facility')
        .where('isActive', isEqualTo: true)
        .where('isApproved', isEqualTo: true)
        .where(
          Filter.or(
            Filter('type', isEqualTo: categoryType),
            Filter('facilityType', isEqualTo: categoryType),
          ),
        );
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

        if (docs.isEmpty) {
          return const Center(child: Text("No healthcare facilities found."));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final facility = docs[index];
            final data = facility.data() as Map<String, dynamic>;
            final name =
                data['facilityName'] ?? data['name'] ?? 'Unknown Facility';
            final type = data['type'] ?? data['facilityType'] ?? 'Unknown Type';
            final location =
                data['location'] ?? data['address'] ?? 'Unknown Location';
            final phone = data['phone'] ?? 'N/A';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: ListTile(
                leading: Icon(_getFacilityIcon(type), color: Colors.teal),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$type\n$location\nPhone: $phone'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _onFacilitySelected(context, facility),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getFacilityIcon(String facilityType) {
    switch (facilityType) {
      case 'hospital':
        return Icons.local_hospital;
      case 'laboratory':
        return Icons.science;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'scan_center':
        return Icons.monitor_heart;
      case 'physiotherapy_center':
        return Icons.accessibility;
      case 'dental_clinic':
        return Icons.medical_information;
      case 'eye_clinic':
        return Icons.visibility;
      case 'mental_health_center':
        return Icons.psychology;
      default:
        return Icons.business;
    }
  }
}
