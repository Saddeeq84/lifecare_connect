// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../facility/presentation/screens/patient_facility_booking_screen.dart';
import 'patient_pharmacy_cart_screen.dart';

class FacilityServicesViewScreen extends StatelessWidget {
  final String facilityId;
  final Map<String, dynamic> facilityData;

  const FacilityServicesViewScreen({
    super.key,
    required this.facilityId,
    required this.facilityData,
  });

  @override
  Widget build(BuildContext context) {
    final facilityName = facilityData['name'] ?? 'Facility';
    final facilityType = facilityData['type'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text('$facilityName Services'),
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
                  _getFacilityIcon(facilityType),
                  size: 48,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(height: 8),
                Text(
                  facilityName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  facilityType,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                if (facilityData['location'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        facilityData['location'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Services List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facility_services')
                  .where('facilityId', isEqualTo: facilityId)
                  .where('type', isEqualTo: 'service')
                  .where('isAvailable', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to load services',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final services = snapshot.data?.docs ?? [];

                if (services.isEmpty) {
                  return _buildNoServicesView(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final serviceData = service.data() as Map<String, dynamic>;

                    return _buildServiceCard(context, serviceData);
                  },
                );
              },
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _requestCustomService(context),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  facilityType == 'Pharmacy'
                      ? 'Browse All Products'
                      : 'Request Custom Service',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    Map<String, dynamic> serviceData,
  ) {
    final name = serviceData['name'] ?? 'Unnamed Service';
    final description = serviceData['description'] ?? '';
    final price = serviceData['price'] ?? 0.0;
    final category = serviceData['category'] ?? 'General';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _requestService(context, serviceData),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: Colors.teal.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₦${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoServicesView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No Services Listed Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This facility hasn\'t added their services yet.\nYou can still request a custom service.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _requestCustomService(context),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                facilityData['type'] == 'Pharmacy'
                    ? 'Browse All Products'
                    : 'Request Custom Service',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requestService(BuildContext context, Map<String, dynamic> serviceData) {
    final facilityType = facilityData['type'] ?? '';

    if (facilityType == 'Pharmacy') {
      // Navigate to pharmacy cart screen for product shopping
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientPharmacyCartScreen(
            facilityId: facilityId,
            facilityData: facilityData,
          ),
        ),
      );
    } else {
      // Navigate to booking screen with pre-selected service for lab/scan
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientFacilityBookingScreen(
            facilityId: facilityId,
            facilityData: facilityData,
            preSelectedService: serviceData,
          ),
        ),
      );
    }
  }

  void _requestCustomService(BuildContext context) {
    final facilityType = facilityData['type'] ?? '';

    if (facilityType == 'Pharmacy') {
      // Navigate to pharmacy cart screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientPharmacyCartScreen(
            facilityId: facilityId,
            facilityData: facilityData,
          ),
        ),
      );
    } else {
      // Navigate to booking screen without pre-selected service for lab/scan
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientFacilityBookingScreen(
            facilityId: facilityId,
            facilityData: facilityData,
          ),
        ),
      );
    }
  }

  IconData _getFacilityIcon(String facilityType) {
    final type = facilityType.toLowerCase();

    if (type.contains('hospital')) {
      return Icons.local_hospital;
    } else if (type.contains('laboratory') || type.contains('lab')) {
      return Icons.science;
    } else if (type.contains('pharmacy')) {
      return Icons.local_pharmacy;
    } else if (type.contains('scan') || type.contains('imaging')) {
      return Icons.monitor_heart;
    } else if (type.contains('dental')) {
      return Icons.medical_information;
    } else if (type.contains('eye')) {
      return Icons.visibility;
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

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'laboratory':
        return Icons.biotech;
      case 'radiology':
      case 'imaging':
        return Icons.camera_alt;
      case 'consultation':
        return Icons.person;
      case 'surgery':
        return Icons.healing;
      case 'emergency':
        return Icons.emergency;
      case 'pharmacy':
        return Icons.medication;
      case 'dental':
        return Icons.mood;
      case 'physiotherapy':
        return Icons.accessibility;
      default:
        return Icons.medical_services;
    }
  }
}
