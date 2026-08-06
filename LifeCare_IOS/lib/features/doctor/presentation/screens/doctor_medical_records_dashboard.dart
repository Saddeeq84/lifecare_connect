// Medical Records Dashboard for Doctors
// Provides centralized access to medical records features

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../facility/presentation/screens/patient_management_screen.dart';
import '../../../facility/presentation/screens/opd_dashboard_screen.dart';
import 'doctor_book_appointment_screen.dart';

class DoctorMedicalRecordsDashboard extends StatefulWidget {
  const DoctorMedicalRecordsDashboard({super.key});

  @override
  State<DoctorMedicalRecordsDashboard> createState() =>
      _DoctorMedicalRecordsDashboardState();
}

class _DoctorMedicalRecordsDashboardState
    extends State<DoctorMedicalRecordsDashboard> {
  String? _facilityId;
  String? _facilityName;
  String? _doctorId;
  String? _doctorName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            _facilityId = data?['facilityId'] as String?;
            _facilityName = data?['facilityName'] as String?;
            _doctorId = user.uid;
            _doctorName = data?['fullName'] as String?;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get medicalRecordItems {
    return [
      {
        "icon": Icons.people,
        "label": "Patient Management",
        "action": "patient_management",
        "color": Colors.teal,
        "description": "Manage all patient records and information",
      },
      {
        "icon": Icons.calendar_month,
        "label": "Book Appointment",
        "action": "book_appointment",
        "color": Colors.blue,
        "description": "Schedule appointments for patients",
      },
      {
        "icon": Icons.folder_shared,
        "label": "Medical Records",
        "action": "medical_records",
        "color": Colors.purple,
        "description": "View completed consultation records",
      },
    ];
  }

  void _handleNavigation(BuildContext context, String action) {
    if (_isLoading || _facilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading facility information...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      switch (action) {
        case 'patient_management':
          // Use the same patient management screen as facility admin
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PatientManagementScreen(),
            ),
          );
          break;
        case 'book_appointment':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DoctorBookAppointmentScreen(
                facilityId: _facilityId!,
                facilityName: _facilityName ?? '',
                doctorId: _doctorId!,
                doctorName: _doctorName ?? '',
              ),
            ),
          );
          break;
        case 'medical_records':
          // Use the same medical records screen as OPD dashboard
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OPDMedicalRecordsScreen(
                facilityId: _facilityId!,
                facilityName: _facilityName ?? '',
                doctorId: _doctorId!,
                doctorName: _doctorName ?? '',
              ),
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
        title: const Text('Medical Records'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: medicalRecordItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = medicalRecordItems[index];
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
