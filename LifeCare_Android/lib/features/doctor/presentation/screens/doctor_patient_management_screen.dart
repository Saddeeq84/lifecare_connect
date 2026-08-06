// Doctor Patient Management Screen
// Patient management specifically for doctors in medical records

import 'package:flutter/material.dart';
import 'doctor_outpatient_screen.dart';
import '../../presentation/screens/doctor_patient_list_screen.dart';
import '../../../facility/presentation/screens/facility_remote_consultations_screen.dart';
import '../../../facility/presentation/screens/facility_remote_patients_screen.dart';

class DoctorPatientManagementScreen extends StatefulWidget {
  const DoctorPatientManagementScreen({super.key});

  @override
  State<DoctorPatientManagementScreen> createState() =>
      _DoctorPatientManagementScreenState();
}

class _DoctorPatientManagementScreenState
    extends State<DoctorPatientManagementScreen> {
  List<Map<String, dynamic>> get patientManagementItems {
    return [
      // 1. My Patients (Registered Patients under this doctor)
      {
        "icon": Icons.people,
        "label": "My Patients",
        "action": "my_patients",
        "color": Colors.blue,
        "description": "Patients under your care",
      },
      // 2. Out-Patients
      {
        "icon": Icons.person_outline,
        "label": "Out-Patients",
        "action": "out_patients",
        "color": Colors.cyan,
        "description": "Outpatient appointments and consultations",
      },
      // 3. Remote Patients
      {
        "icon": Icons.people_outline,
        "label": "Remote Patients",
        "action": "remote_patients",
        "color": Colors.teal,
        "description": "Patients from remote consultations",
      },
      // 4. Remote Consultations
      {
        "icon": Icons.video_call,
        "label": "Remote Consultations",
        "action": "remote_consultations",
        "color": Colors.purple,
        "description": "Virtual consultation appointments",
      },
    ];
  }

  void _handleNavigation(BuildContext context, String action) {
    try {
      switch (action) {
        case 'my_patients':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorPatientListScreen(),
            ),
          );
          break;
        case 'out_patients':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DoctorOutpatientScreen(),
            ),
          );
          break;
        case 'remote_patients':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FacilityRemotePatientsScreen(),
            ),
          );
          break;
        case 'remote_consultations':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FacilityRemoteConsultationsScreen(),
            ),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: patientManagementItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = patientManagementItems[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: (item['color'] as Color).withOpacity(0.1),
                child: Icon(
                  item['icon'] as IconData,
                  color: item['color'] as Color,
                  size: 32,
                ),
              ),
              title: Text(
                item['label'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item['description'] as String,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onTap: () => _handleNavigation(context, item['action'] as String),
            ),
          );
        },
      ),
    );
  }
}
