// Patient Management Screen
// Centralized screen for managing all patient-related activities

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'facility_remote_consultations_screen.dart';
import 'facility_patient_list_screen.dart';
import 'inpatient_dashboard_screen.dart';
import 'facility_outpatient_screen.dart';
import 'billing_dashboard_screen.dart';

class PatientManagementScreen extends StatefulWidget {
  final String? facilityId;
  final String? facilityName;
  final bool
  hideOutPatients; // Hide out-patients option (for Medical Records dashboard)

  const PatientManagementScreen({
    super.key,
    this.facilityId,
    this.facilityName,
    this.hideOutPatients = false, // Default to false to show out-patients
  });

  @override
  State<PatientManagementScreen> createState() =>
      _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  String? _facilityType;
  String? _facilityId;
  String? _facilityName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFacilityType();
  }

  Future<void> _loadFacilityType() async {
    try {
      // First check if facility data was passed as parameters
      if (widget.facilityId != null && widget.facilityName != null) {
        // Get facility type from Firestore using facilityId
        final facilityDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.facilityId)
            .get();

        if (facilityDoc.exists) {
          final data = facilityDoc.data();
          if (mounted) {
            setState(() {
              _facilityType = data?['type'] as String?;
              _facilityId = widget.facilityId;
              _facilityName = widget.facilityName;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Fallback: Try to get from Firebase Auth user (for facility admin login)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (mounted) {
          setState(() {
            _facilityType = data?['type'] as String?;
            _facilityId = user.uid;
            _facilityName = data?['name'] as String?;
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

  List<Map<String, dynamic>> get patientManagementItems {
    // Facility types that should have In-Patients
    final typesWithInPatients = [
      'hospital',
      'clinic',
      'dental clinic',
      'eye clinic',
      'mental health center',
      'physiotherapy center',
    ];

    final bool hasInPatients =
        _facilityType != null &&
        typesWithInPatients.any(
          (type) => _facilityType!.toLowerCase().trim() == type.toLowerCase(),
        );

    List<Map<String, dynamic>> items = [
      // 1. Registered Patients
      {
        "icon": Icons.person_add,
        "label": "Registered Patients",
        "action": "registered_patients",
        "color": Colors.blue,
      },
    ];

    // 2. In-Patients (conditional)
    if (hasInPatients) {
      items.add({
        "icon": Icons.local_hotel,
        "label": "In-Patients",
        "action": "in_patients",
        "color": Colors.orange,
      });
    }

    // 3. Out-Patients (conditional - hidden for Medical Records dashboard)
    if (!widget.hideOutPatients) {
      items.add({
        "icon": Icons.person_outline,
        "label": "Out-Patients",
        "action": "out_patients",
        "color": Colors.cyan,
      });
    }

    // 4. Remote Consultations
    items.add({
      "icon": Icons.video_call,
      "label": "Remote Consultations",
      "action": "remote_consultations",
      "color": Colors.purple,
    });

    // 5. Billing
    items.add({
      "icon": Icons.payment,
      "label": "Billing",
      "action": "billing",
      "color": Colors.green,
    });

    return items;
  }

  Future<void> _handleNavigation(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'registered_patients':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FacilityPatientListScreen(),
            ),
          );
          break;
        case 'in_patients':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InpatientDashboardScreen(
                facilityId: _facilityId ?? '',
                facilityName: _facilityName ?? '',
                staffId: 'admin',
                staffName: 'Facility Admin',
              ),
            ),
          );
          break;
        case 'out_patients':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FacilityOutpatientScreen(),
            ),
          );
          break;
        case 'remote_consultations':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FacilityRemoteConsultationsScreen(
                facilityId: _facilityId,
                facilityName: _facilityName,
              ),
            ),
          );
          break;
        case 'billing':
          await _navigateToBilling(context);
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _navigateToBilling(BuildContext context) async {
    try {
      // Get facility ID and name
      String? facilityId = _facilityId;
      String? facilityName = _facilityName;
      String staffId = 'admin';
      String staffName = 'Staff';

      // If facility data is not available from parameters, try to get from Firebase Auth
      if (facilityId == null || facilityName == null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw Exception('User data not found');
        }

        final userData = userDoc.data()!;

        // Check if user is a staff member or facility admin
        if (userData['userType'] == 'staff' || userData['role'] == 'staff') {
          // Staff member accessing from medical records department
          facilityId = userData['facilityId'] as String?;
          staffId = user.uid;
          staffName = userData['fullName'] ?? 'Staff';

          // Get facility name from facility document
          if (facilityId != null) {
            final facilityDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(facilityId)
                .get();
            if (facilityDoc.exists) {
              facilityName = facilityDoc.data()?['fullName'] as String?;
            }
          }
        } else {
          // Facility admin
          facilityId = user.uid;
          facilityName = userData['fullName'] as String? ?? 'Facility Admin';
          staffId = 'admin';
          staffName = facilityName;
        }
      }

      if (facilityId == null || facilityName == null) {
        throw Exception('Facility information not available');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BillingDashboardScreen(
            facilityId: facilityId!,
            staffId: staffId,
            staffName: staffName,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening billing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.teal.shade800),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: patientManagementItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = patientManagementItems[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: (item['color'] as Color).withOpacity(
                        0.1,
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      item['label'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                    onTap: () =>
                        _handleNavigation(context, item['action'] as String),
                  ),
                );
              },
            ),
    );
  }
}
