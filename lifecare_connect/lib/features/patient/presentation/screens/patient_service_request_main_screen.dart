// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'patient_facility_selection_screen.dart';
import '../../../facility/presentation/screens/patient_facility_booking_screen.dart';
// import 'patient_services_request_screen.dart'; // Removed: file does not exist

class PatientServiceRequestMainScreen extends StatefulWidget {
  const PatientServiceRequestMainScreen({super.key});

  @override
  State<PatientServiceRequestMainScreen> createState() =>
      _PatientServiceRequestMainScreenState();
}

class _PatientServiceRequestMainScreenState
    extends State<PatientServiceRequestMainScreen> {
  String? selectedCategoryType;
  String? selectedCategoryLabel;
  String? selectedFacilityId;
  Map<String, dynamic>? selectedFacilityData;

  final categories = [
    {'type': 'hospital', 'label': 'Hospitals', 'icon': Icons.local_hospital},
    {'type': 'clinic', 'label': 'Clinics', 'icon': Icons.local_hospital},
    {'type': 'laboratory', 'label': 'Laboratories', 'icon': Icons.science},
    {'type': 'pharmacy', 'label': 'Pharmacies', 'icon': Icons.local_pharmacy},
    {
      'type': 'dental_clinic',
      'label': 'Dental Clinics',
      'icon': Icons.medical_information,
    },
    {
      'type': 'scan_center',
      'label': 'Scan Centers',
      'icon': Icons.monitor_heart,
    },
    {'type': 'eye_clinic', 'label': 'Eye Clinics', 'icon': Icons.visibility},
    {
      'type': 'mental_health_center',
      'label': 'Mental Health Centers',
      'icon': Icons.psychology,
    },
    {
      'type': 'physiotherapy_center',
      'label': 'Physiotherapy Centers',
      'icon': Icons.accessibility,
    },
  ];

  @override
  Widget build(BuildContext context) {
    // The PatientServicesRequestScreen widget and file do not exist. If you need to show a request screen, implement it here or use an alternative.

    if (selectedCategoryType != null && selectedCategoryLabel != null) {
      // Show the facility selection screen for the selected category
      return PatientFacilitySelectionScreen(
        key: ValueKey(selectedCategoryType),
        categoryType: selectedCategoryType!,
        categoryLabel: selectedCategoryLabel!,
        onFacilitySelected: (facilityId, facilityData) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PatientFacilityBookingScreen(
                facilityId: facilityId,
                facilityData: facilityData,
              ),
            ),
          );
        },
      );
    }

    // Show the category list (vertical)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Healthcare Services'),
        backgroundColor: Colors.green.shade700,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                category['icon'] as IconData,
                size: 36,
                color: Colors.teal,
              ),
              title: Text(
                category['label'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 18),
              onTap: () {
                setState(() {
                  selectedCategoryType = category['type'] as String;
                  selectedCategoryLabel = category['label'] as String;
                });
              },
            ),
          );
        },
      ),
    );
  }
}
