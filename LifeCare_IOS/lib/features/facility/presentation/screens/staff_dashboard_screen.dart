// Staff Dashboard Screen
// Role-based dashboard for facility staff members

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:lifecare_connect/core/services/facility_pricing_service.dart';
import 'vitals_recording_screen.dart';

import 'pharmacy_dispensing_screen.dart';
import 'pharmacy_inventory_screen.dart';
import 'lab_results_entry_screen.dart';
import 'sample_management_screen.dart';
import 'radiology_reporting_screen.dart';
import 'billing_dashboard_screen.dart';
import 'patient_medical_records_screen.dart';
import 'nursing_patients_screen.dart';
import 'nursing_pending_consultation_screen.dart';
import 'specialist_dashboard_screen.dart';
import 'nursing_medical_records_screen.dart';
import 'nursing_inpatients_screen.dart';
import 'admission_screen.dart';
import 'inpatient_dashboard_screen.dart';
import 'bed_management_screen.dart';
import 'ward_rounds_screen.dart';
import 'discharge_screen.dart';
import 'ward_setup_screen.dart';
import 'patient_management_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  Map<String, dynamic>? _staffData;
  String? _facilityId;
  String? _facilityName;
  String? _staffCollection;
  bool _isLoading = true;

  // Role categories based on profession
  static const List<String> _clinicalRoles = [
    'Doctor',
    'Nurse',
    'Community Health Worker',
    'Community Health Officer',
    'Community Health Extension Worker',
    'Midwife',
    'Surgeon',
    'Dentist',
    'Physiotherapist',
  ];

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    try {
      // Get staff info from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final staffRole = prefs.getString('user_role');

      if (staffRole != 'facility_staff') {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      final staffId = prefs.getString('staff_id');
      _facilityName = prefs.getString('facility_name');
      _staffCollection = prefs.getString('staff_collection');

      if (staffId == null ||
          _facilityName == null ||
          _staffCollection == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid session. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          context.go('/login');
        }
        return;
      }

      // Get facility ID from facility name
      final facilityQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .where('name', isEqualTo: _facilityName)
          .limit(1)
          .get();

      if (facilityQuery.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Facility not found. Please contact admin.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      _facilityId = facilityQuery.docs.first.id;

      // Load staff data from facility collection
      final staffQuery = await FirebaseFirestore.instance
          .collection(_staffCollection!)
          .where('staffId', isEqualTo: staffId)
          .limit(1)
          .get();

      if (staffQuery.docs.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Staff account not found. Please contact your facility admin.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final staffDoc = staffQuery.docs.first;

      if (mounted) {
        setState(() {
          _staffData = {...staffDoc.data(), 'id': staffDoc.id};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading staff data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  bool _hasPatientAccess() {
    final profession = _staffData?['profession'] as String?;
    return profession != null && _clinicalRoles.contains(profession);
  }

  List<Map<String, dynamic>> _getDashboardItems() {
    final items = <Map<String, dynamic>>[];
    final department = _staffData?['department'] as String?;
    final profession = _staffData?['profession'] as String?;

    // Department-specific items based on facility departments
    final departmentItems = _getDepartmentSpecificItems(department, profession);
    items.addAll(departmentItems);

    // Common items for all staff
    items.addAll([
      {
        'icon': Icons.message,
        'label': 'Messages',
        'color': Colors.indigo,
        'route': 'messages',
      },
    ]);

    return items;
  }

  List<Map<String, dynamic>> _getDepartmentSpecificItems(
    String? department,
    String? profession,
  ) {
    final items = <Map<String, dynamic>>[];

    if (department == null) return items;

    switch (department) {
      // Emergency Department
      case 'Emergency Department':
        items.addAll([
          {
            'icon': Icons.people,
            'label': 'My Patients',
            'color': Colors.teal,
            'route': 'patients',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Quick Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.person_add,
            'label': 'Admit to ICU/Ward',
            'color': Colors.deepOrange,
            'route': 'admit_patient',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // OPD
      case 'Outpatient Department (OPD)':
      case 'General Consultation':
        items.addAll([
          {
            'icon': Icons.people_outline,
            'label': 'Out-Patients',
            'color': Colors.teal,
            'route': 'out_patients',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Specialist Department
      case 'Specialist Department':
        items.addAll([
          {
            'icon': Icons.medical_services,
            'label': 'Specialist Dashboard',
            'color': Colors.deepPurple,
            'route': 'specialist_dashboard',
          },
          {
            'icon': Icons.people,
            'label': 'Specialist Patients',
            'color': Colors.teal,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // IPD
      case 'Inpatient Department (IPD)':
        items.addAll([
          {
            'icon': Icons.hotel,
            'label': 'Inpatients',
            'color': Colors.teal,
            'route': 'inpatients',
          },
          {
            'icon': Icons.person_add,
            'label': 'Admit Patient',
            'color': Colors.orange,
            'route': 'admit_patient',
          },
          {
            'icon': Icons.bed,
            'label': 'Bed Management',
            'color': Colors.blue,
            'route': 'bed_management',
          },
          {
            'icon': Icons.assignment,
            'label': 'Ward Rounds',
            'color': Colors.purple,
            'route': 'ward_rounds',
          },
          {
            'icon': Icons.exit_to_app,
            'label': 'Discharge Patient',
            'color': Colors.deepOrange,
            'route': 'discharge_patient',
          },
          {
            'icon': Icons.settings,
            'label': 'Ward Setup',
            'color': Colors.grey,
            'route': 'ward_setup',
          },
          {
            'icon': Icons.people,
            'label': 'All Patients',
            'color': Colors.blueGrey,
            'route': 'patients',
          },
        ]);
        break;

      // ICU
      case 'Intensive Care Unit (ICU)':
        items.addAll([
          {
            'icon': Icons.health_and_safety,
            'label': 'Critical Patients',
            'color': Colors.red,
            'route': 'patients',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Surgery
      case 'Surgery Department':
      case 'Surgical Unit':
      case 'Oral Surgery':
        items.addAll([
          {
            'icon': Icons.people,
            'label': 'Surgical Patients',
            'color': Colors.teal,
            'route': 'patients',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Surgical Consultation',
            'color': Colors.indigo,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Surgical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
          {
            'icon': Icons.hotel,
            'label': 'Admit Patient',
            'color': Colors.deepOrange,
            'route': 'admit_patient',
          },
        ]);
        break;

      // Pediatrics
      case 'Pediatrics':
      case 'Pediatric Dentistry':
      case 'Pediatric Physiotherapy':
        items.addAll([
          {
            'icon': Icons.child_care,
            'label': 'Child Patients',
            'color': Colors.pink,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // OB-GYN
      case 'Obstetrics & Gynecology':
        items.addAll([
          {
            'icon': Icons.pregnant_woman,
            'label': 'Patients',
            'color': Colors.deepPurple,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Cardiology
      case 'Cardiology':
        items.addAll([
          {
            'icon': Icons.favorite,
            'label': 'Cardiac Patients',
            'color': Colors.red,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Neurology
      case 'Neurology':
        items.addAll([
          {
            'icon': Icons.psychology,
            'label': 'Neuro Patients',
            'color': Colors.deepOrange,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Orthopedics
      case 'Orthopedics':
      case 'Orthopedic Physiotherapy':
        items.addAll([
          {
            'icon': Icons.accessible,
            'label': 'Patients',
            'color': Colors.indigo,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Radiology
      case 'Radiology':
        items.addAll([
          {
            'icon': Icons.scanner,
            'label': 'Imaging & Reports',
            'color': Colors.blue,
            'route': 'radiology_reporting',
          },
          {
            'icon': Icons.people,
            'label': 'Patients',
            'color': Colors.teal,
            'route': 'patients',
          },
        ]);
        break;

      // Laboratory departments
      case 'Laboratory':
      case 'Clinical Chemistry':
      case 'Hematology':
      case 'Microbiology':
      case 'Histopathology':
      case 'Immunology':
      case 'Molecular Biology':
      case 'Blood Bank':
      case 'Sample Collection':
        items.addAll([
          {
            'icon': Icons.science,
            'label': 'Lab Tests & Results',
            'color': Colors.green,
            'route': 'laboratory',
          },
          {
            'icon': Icons.biotech,
            'label': 'Sample Management',
            'color': Colors.purple,
            'route': 'sample_management',
          },
          {
            'icon': Icons.analytics,
            'label': 'Reports & Analytics',
            'color': Colors.blue,
            'route': 'lab_reports',
          },
        ]);
        break;

      // Pharmacy (Prescription management and inventory)
      case 'Pharmacy':
      case 'Dispensary':
      case 'Clinical Pharmacy':
      case 'Drug Information':
      case 'Inventory Management':
        items.addAll([
          {
            'icon': Icons.medication_liquid,
            'label': 'Patients & Dispensing',
            'color': Colors.green,
            'route': 'pharmacy_dispensing',
          },
          {
            'icon': Icons.inventory_2,
            'label': 'Inventory Management',
            'color': Colors.orange,
            'route': 'pharmacy_inventory',
          },
        ]);
        break;

      // Physiotherapy
      case 'Physiotherapy':
      case 'Neurological Physiotherapy':
      case 'Cardiopulmonary Physiotherapy':
      case 'Sports Physiotherapy':
      case 'Geriatric Physiotherapy':
        items.addAll([
          {
            'icon': Icons.accessibility_new,
            'label': 'Patients',
            'color': Colors.amber,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Nutrition & Dietetics
      case 'Nutrition & Dietetics':
        items.addAll([
          {
            'icon': Icons.restaurant,
            'label': 'Patients',
            'color': Colors.lime,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Dental Departments
      case 'General Dentistry':
      case 'Orthodontics':
      case 'Periodontics':
        items.addAll([
          {
            'icon': Icons.medical_services,
            'label': 'Dental Patients',
            'color': Colors.blue,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.indigo,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Eye Clinic Departments
      case 'Ophthalmology':
      case 'Optometry':
      case 'Contact Lens Service':
      case 'Optical Dispensary':
        items.addAll([
          {
            'icon': Icons.visibility,
            'label': 'Eye Patients',
            'color': Colors.blue,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.indigo,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Mental Health Departments
      case 'Psychiatry':
      case 'Clinical Psychology':
      case 'Counseling':
      case 'Occupational Therapy':
      case 'Social Work':
      case 'Substance Abuse Treatment':
      case 'Crisis Intervention':
        items.addAll([
          {
            'icon': Icons.psychology,
            'label': 'Patients',
            'color': Colors.purple,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_today,
            'label': 'Appointments',
            'color': Colors.blue,
            'route': 'appointments',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Consultation',
            'color': Colors.purple,
            'route': 'consultation',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'medical_records',
          },
        ]);
        break;

      // Medical Records (Front desk operations, patient coordination, and administrative functions)
      case 'Medical Records':
        items.addAll([
          {
            'icon': Icons.people,
            'label': 'Patient Management',
            'color': Colors.teal,
            'route': 'patient_management',
          },
          {
            'icon': Icons.people_outline,
            'label': 'All Patients',
            'color': Colors.blue,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_month,
            'label': 'Book Appointment',
            'color': Colors.orange,
            'route': 'book_appointment',
          },
          {
            'icon': Icons.account_balance_wallet,
            'label': 'Billing',
            'color': Colors.green,
            'route': 'billing',
          },
          {
            'icon': Icons.bar_chart,
            'label': 'Reports',
            'color': Colors.grey,
            'route': 'medical_reports',
          },
        ]);
        break;

      // Reception staff redirected to Medical Records (backward compatibility)
      case 'Reception':
        items.addAll([
          {
            'icon': Icons.people,
            'label': 'All Patients',
            'color': Colors.teal,
            'route': 'patients',
          },
          {
            'icon': Icons.calendar_month,
            'label': 'Book Appointment',
            'color': Colors.blue,
            'route': 'book_appointment',
          },
          {
            'icon': Icons.account_balance_wallet,
            'label': 'Billing',
            'color': Colors.green,
            'route': 'billing',
          },
          {
            'icon': Icons.bar_chart,
            'label': 'Reports',
            'color': Colors.grey,
            'route': 'medical_reports',
          },
        ]);
        break;

      // Housekeeping
      case 'Housekeeping':
        items.addAll([
          {
            'icon': Icons.cleaning_services,
            'label': 'Cleaning Schedule',
            'color': Colors.brown,
            'route': 'cleaning_schedule',
          },
          {
            'icon': Icons.delete,
            'label': 'Waste Management',
            'color': Colors.red,
            'route': 'waste_management',
          },
          {
            'icon': Icons.sanitizer,
            'label': 'Disinfection',
            'color': Colors.blue,
            'route': 'disinfection',
          },
          {
            'icon': Icons.assignment,
            'label': 'Task Reports',
            'color': Colors.grey,
            'route': 'housekeeping_reports',
          },
        ]);
        break;

      // Security
      case 'Security':
        items.addAll([
          {
            'icon': Icons.security,
            'label': 'Incident Reports',
            'color': Colors.grey,
            'route': 'incident_reports',
          },
          {
            'icon': Icons.video_camera_front,
            'label': 'Surveillance',
            'color': Colors.blueGrey,
            'route': 'surveillance',
          },
          {
            'icon': Icons.verified_user,
            'label': 'Access Control',
            'color': Colors.blue,
            'route': 'access_control',
          },
          {
            'icon': Icons.emergency,
            'label': 'Emergency Alerts',
            'color': Colors.red,
            'route': 'emergency_alerts',
          },
        ]);
        break;

      // Nursing (for standalone nursing department)
      case 'Nursing':
        items.addAll([
          {
            'icon': Icons.people,
            'label': 'Approved Patients',
            'color': Colors.teal,
            'route': 'nursing_patients',
          },
          {
            'icon': Icons.medical_information,
            'label': 'Pending Consultation',
            'color': Colors.orange,
            'route': 'nursing_pending_consultation',
          },
          {
            'icon': Icons.hotel,
            'label': 'In-Patients',
            'color': Colors.blue,
            'route': 'nursing_inpatients',
          },
          {
            'icon': Icons.folder_shared,
            'label': 'Medical Records',
            'color': Colors.blueGrey,
            'route': 'nursing_medical_records',
          },
        ]);
        break;

      // Default for unspecified departments
      default:
        if (_hasPatientAccess()) {
          items.addAll([
            {
              'icon': Icons.people,
              'label': 'My Patients',
              'color': Colors.teal,
              'route': 'patients',
            },
            {
              'icon': Icons.calendar_today,
              'label': 'Appointments',
              'color': Colors.blue,
              'route': 'appointments',
            },
            {
              'icon': Icons.calendar_month,
              'label': 'Book Appointment',
              'color': Colors.indigo,
              'route': 'book_appointment',
            },
            {
              'icon': Icons.medical_services,
              'label': 'Consultations',
              'color': Colors.purple,
              'route': 'consultations',
            },
          ]);
        }
    }

    return items;
  }

  void _handleItemTap(String route) {
    if (route == 'book_appointment') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffBookAppointmentScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'record_vitals') {
      // Navigate to patient selection first, then to vitals recording
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffPatientsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
            selectForVitals: true,
          ),
        ),
      );
    } else if (route == 'consultation') {
      // Navigate to patient selection first, then to consultation form
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffPatientsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
            selectForConsultation: true,
          ),
        ),
      );
    } else if (route == 'pharmacy_dispensing') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PharmacyDispensingScreen(
            facilityId: _facilityId!,
            pharmacistId: _staffData?['staffId'] ?? '',
            pharmacistName: _staffData?['fullName'] ?? 'Pharmacist',
          ),
        ),
      );
    } else if (route == 'pharmacy_inventory') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PharmacyInventoryScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'laboratory') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LabResultsEntryScreen(
            facilityId: _facilityId!,
            laboratoryStaffId: _staffData?['staffId'] ?? '',
            laboratoryStaffName: _staffData?['fullName'] ?? 'Lab Staff',
          ),
        ),
      );
    } else if (route == 'lab_reports') {
      // Show coming soon dialog for lab reports & analytics
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue),
              SizedBox(width: 8),
              Text('Reports & Analytics'),
            ],
          ),
          content: const Text(
            'Lab Reports & Analytics feature is coming soon. This will include:\n\n'
            '• Test volume statistics\n'
            '• Turnaround time analysis\n'
            '• Quality control reports\n'
            '• Monthly lab summaries\n'
            '• Performance metrics',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else if (route == 'sample_management') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SampleManagementScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Lab Staff',
          ),
        ),
      );
    } else if (route == 'radiology_reporting') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RadiologyReportingScreen(
            facilityId: _facilityId!,
            radiologistId: _staffData?['staffId'] ?? '',
            radiologistName: _staffData?['fullName'] ?? 'Radiologist',
          ),
        ),
      );
    } else if (route == 'patient_management') {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PatientManagementScreen(),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening patient management: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else if (route == 'patients') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffPatientsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'out_patients') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffOutPatientsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'in_patients') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InpatientDashboardScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'appointments') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffAppointmentsScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'specialist_dashboard') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SpecialistDashboardScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            doctorId: _staffData?['staffId'] ?? '',
            doctorName: _staffData?['fullName'] ?? 'Specialist',
          ),
        ),
      );
    } else if (route == 'consultations') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffConsultationsScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'referrals') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffReferralsScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffProfileScreen(
            staffData: _staffData!,
            facilityName: _facilityName!,
          ),
        ),
      );
    } else if (route == 'settings') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffSettingsScreen(
            staffData: _staffData!,
            facilityName: _facilityName!,
            staffCollection: _staffCollection!,
          ),
        ),
      );
    } else if (route == 'billing') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BillingDashboardScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'medical_records') {
      // Navigate to completed consultations screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompletedConsultationsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'messages') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffMessagingScreen(
            facilityId: _facilityId!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'nursing_patients') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NursingPatientsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Nursing Staff',
          ),
        ),
      );
    } else if (route == 'nursing_pending_consultation') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NursingPendingConsultationScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Nursing Staff',
          ),
        ),
      );
    } else if (route == 'nursing_medical_records') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NursingMedicalRecordsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Nursing Staff',
          ),
        ),
      );
    } else if (route == 'admit_patient') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdmissionScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'nursing_inpatients') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NursingInpatientsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Nursing Staff',
            wardId: _staffData?['wardId'], // Ward assignment for nursing staff
            wardName: _staffData?['wardName'], // Ward name for display
          ),
        ),
      );
    } else if (route == 'inpatients') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InpatientDashboardScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'bed_management') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BedManagementScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
          ),
        ),
      );
    } else if (route == 'ward_rounds') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WardRoundsScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'discharge_patient') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DischargeScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
            staffId: _staffData?['staffId'] ?? '',
            staffName: _staffData?['fullName'] ?? 'Staff',
          ),
        ),
      );
    } else if (route == 'ward_setup') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WardSetupScreen(
            facilityId: _facilityId!,
            facilityName: _facilityName!,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$route - Coming Soon'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear SharedPreferences for staff
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('staff_id');
      await prefs.remove('facility_name');
      await prefs.remove('staff_collection');

      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.teal.shade800),
              const SizedBox(height: 16),
              const Text('Loading your dashboard...'),
            ],
          ),
        ),
      );
    }

    if (_staffData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Staff account not found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleLogout,
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    final dashboardItems = _getDashboardItems();

    return Scaffold(
      appBar: AppBar(
        title: Text(_facilityName ?? 'Staff Dashboard'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications - Coming Soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _handleItemTap('profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _handleItemTap('settings'),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade800, Colors.teal.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _staffData?['fullName'] ?? 'Staff',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _staffData?['profession'] ?? 'Staff Member',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (_staffData?['department'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _staffData!['department'],
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Dashboard Items Grid
              Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashboardItems.length,
                itemBuilder: (context, index) {
                  final item = dashboardItems[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      onTap: () => _handleItemTap(item['route']),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'],
                          size: 28,
                          color: item['color'],
                        ),
                      ),
                      title: Text(
                        item['label'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Staff Out-Patients Screen - Shows only patients with approved appointments
class StaffOutPatientsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const StaffOutPatientsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffOutPatientsScreen> createState() => _StaffOutPatientsScreenState();
}

class _StaffOutPatientsScreenState extends State<StaffOutPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Out-Patients'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Approved Appointments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('assignedStaffId', isEqualTo: widget.staffId)
                  .where('status', isEqualTo: 'approved')
                  .orderBy('appointmentDate', descending: true)
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No approved appointments',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patients with approved appointments will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Filter appointments by search query
                var appointments = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();

                  return patientName.contains(_searchQuery);
                }).toList();

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final doc = appointments[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Patient Info Row
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.teal.shade100,
                                        child: Text(
                                          (data['patientName'] ?? 'P')[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.teal.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              data['patientName'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              'Appointment: ${_formatAppointmentDate(data['appointmentDate'])}',
                                            ),
                                            Text(
                                              'Time: ${data['appointmentTime'] ?? 'N/A'}',
                                            ),
                                            if (data['reason'] != null)
                                              Text('Reason: ${data['reason']}'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Action Buttons Row for this patient
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    VitalsRecordingScreen(
                                                      patientId:
                                                          data['patientId'] ??
                                                          '',
                                                      patientName:
                                                          data['patientName'] ??
                                                          'Unknown',
                                                      facilityId:
                                                          widget.facilityId,
                                                    ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.monitor_heart,
                                            size: 18,
                                          ),
                                          label: const Text('Vital Signs'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    FacilityConsultationScreen(
                                                      patientId:
                                                          data['patientId'] ??
                                                          '',
                                                      patientName:
                                                          data['patientName'] ??
                                                          'Unknown',
                                                      facilityId:
                                                          widget.facilityId,
                                                      clinicianId:
                                                          widget.staffId,
                                                      clinicianName:
                                                          widget.staffName,
                                                    ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.medical_information,
                                            size: 18,
                                          ),
                                          label: const Text('Consultation'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.purple.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => AdmissionScreen(
                                                  facilityId: widget.facilityId,
                                                  facilityName:
                                                      widget.facilityName,
                                                  staffId: widget.staffId,
                                                  staffName: widget.staffName,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.hotel,
                                            size: 18,
                                          ),
                                          label: const Text('Admit'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.orange.shade600,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatAppointmentDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date;
      }
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

// Staff Patients Screen - Shows patients assigned/referred to this staff member
class StaffPatientsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final bool selectForVitals;
  final bool selectForConsultation;
  final bool selectForMedicalRecords;

  const StaffPatientsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.selectForVitals = false,
    this.selectForConsultation = false,
    this.selectForMedicalRecords = false,
  });

  @override
  State<StaffPatientsScreen> createState() => _StaffPatientsScreenState();
}

class _StaffPatientsScreenState extends State<StaffPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name, household, or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Patients List - All facility patients for Medical Records staff
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facility_patients')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('isActive', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No patients found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter patients by search query
                var patients = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = (data['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final householdName = (data['householdName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();

                  return fullName.contains(_searchQuery) ||
                      householdName.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();

                // Limit to 10 if not showing all
                final displayPatients = _showAll
                    ? patients
                    : patients.take(10).toList();
                final hasMore = patients.length > 10 && !_showAll;

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: displayPatients.length,
                        itemBuilder: (context, index) {
                          final doc = displayPatients[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Text(
                                  (data['fullName'] ?? 'P')[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.teal.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                data['fullName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (data['householdName'] != null)
                                    Text('Household: ${data['householdName']}'),
                                  if (data['phone'] != null)
                                    Text('Phone: ${data['phone']}'),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                _handlePatientTap(context, data);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _showAll = true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'View All (${patients.length} patients)',
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handlePatientTap(BuildContext context, Map<String, dynamic> data) {
    final patientId = data['id'];
    final patientName = data['fullName'] ?? 'Unknown';

    if (widget.selectForVitals) {
      // Navigate to vitals recording screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VitalsRecordingScreen(
            patientId: patientId,
            patientName: patientName,
            facilityId: widget.facilityId,
          ),
        ),
      );
    } else if (widget.selectForConsultation) {
      // Navigate to consultation form screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FacilityConsultationScreen(
            patientId: patientId,
            patientName: patientName,
            facilityId: widget.facilityId,
            clinicianId: widget.staffId,
            clinicianName: widget.staffName,
          ),
        ),
      );
    } else if (widget.selectForMedicalRecords) {
      // Navigate to patient medical records screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PatientMedicalRecordsScreen(
            patientId: patientId,
            patientName: patientName,
          ),
        ),
      );
    } else {
      // Show patient details dialog
      _showPatientDetails(context, data);
    }
  }

  void _showPatientDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['fullName'] ?? 'Patient Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Phone', data['phone']),
              _buildDetailRow('Email', data['email']),
              _buildDetailRow('Date of Birth', data['dateOfBirth']),
              _buildDetailRow('Gender', data['gender']),
              _buildDetailRow('Address', data['address']),
              _buildDetailRow('Household', data['householdName']),
              _buildDetailRow('Emergency Contact', data['emergencyContact']),
              _buildDetailRow('Emergency Name', data['emergencyContactName']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }
}

// Staff Profile Screen
class StaffProfileScreen extends StatelessWidget {
  final Map<String, dynamic> staffData;
  final String facilityName;

  const StaffProfileScreen({
    super.key,
    required this.staffData,
    required this.facilityName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade800, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Text(
                      (staffData['fullName'] ?? 'S')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    staffData['fullName'] ?? 'Staff',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    staffData['profession'] ?? 'Staff Member',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Details
            _buildInfoCard('Personal Information', [
              _buildInfoRow(Icons.badge, 'Staff ID', staffData['staffId']),
              _buildInfoRow(Icons.email, 'Email', staffData['email']),
              _buildInfoRow(Icons.phone, 'Phone', staffData['phone']),
              _buildInfoRow(
                Icons.cake,
                'Date of Birth',
                staffData['dateOfBirth'],
              ),
            ]),
            const SizedBox(height: 16),
            _buildInfoCard('Work Information', [
              _buildInfoRow(Icons.business, 'Facility', facilityName),
              _buildInfoRow(Icons.work, 'Profession', staffData['profession']),
              _buildInfoRow(
                Icons.apartment,
                'Department',
                staffData['department'],
              ),
              _buildInfoRow(Icons.info, 'Status', staffData['status']),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Staff Appointments Screen
class StaffAppointmentsScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const StaffAppointmentsScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffAppointmentsScreen> createState() =>
      _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState extends State<StaffAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingAppointments(), _buildApprovedAppointments()],
      ),
    );
  }

  Widget _buildPendingAppointments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('assignedStaffId', isEqualTo: widget.staffId)
          .where('status', isEqualTo: 'pending')
          .orderBy('appointmentDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending appointments',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.person, color: Colors.blue.shade800),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${_formatAppointmentDate(data['appointmentDate'])}',
                    ),
                    Text('Reason: ${data['reason'] ?? 'N/A'}'),
                    Text('Booked by: ${data['bookedBy'] ?? 'Medical Records'}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _showApproveDialog(doc.id, data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _showRejectDialog(doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedAppointments() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('assignedStaffId', isEqualTo: widget.staffId)
          .where('status', isEqualTo: 'approved')
          .orderBy('appointmentDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No approved appointments',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.check, color: Colors.green.shade800),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${_formatAppointmentDate(data['appointmentDate'])}',
                    ),
                    Text('Reason: ${data['reason'] ?? 'N/A'}'),
                    Text('Status: Approved'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAppointmentAction(
    String appointmentId,
    String status,
    String? reason,
  ) async {
    try {
      // Get appointment details
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }

      final appointmentData = appointmentDoc.data()!;
      final bookedById = appointmentData['bookedById'] as String?;
      final bookedBy = appointmentData['bookedBy'] as String?;

      if (status == 'approved') {
        // Process payment when approving
        final patientId = appointmentData['patientId'] as String;
        final patientName = appointmentData['patientName'] as String;
        final appointmentFee =
            (appointmentData['appointmentFee'] as num?)?.toDouble() ?? 0.0;
        final facilityId = appointmentData['facilityId'] as String;
        final facilityName = appointmentData['facilityName'] as String;

        print(
          '💰 [ApproveAppointment] Processing payment for appointment $appointmentId',
        );
        print('   Patient: $patientName ($patientId)');
        print('   Fee: ₦$appointmentFee');

        // Process payment
        bool paymentSuccessful = await _processAppointmentPayment(
          patientId: patientId,
          patientName: patientName,
          appointmentFee: appointmentFee,
          facilityId: facilityId,
          facilityName: facilityName,
        );

        if (!paymentSuccessful) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment failed. Cannot approve appointment.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Update appointment with approval and payment status
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
              'status': 'approved',
              'paymentStatus': 'paid',
              'approvedBy': widget.staffName,
              'approvedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Appointment approved and payment of ₦${appointmentFee.toStringAsFixed(2)} processed',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Rejected - update status and send message to booker
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
              'status': 'rejected',
              'rejectionReason': reason,
              'rejectedBy': widget.staffName,
              'rejectedAt': FieldValue.serverTimestamp(),
            });

        // Send rejection message to the staff who booked the appointment
        if (bookedById != null && bookedBy != null) {
          await FirebaseFirestore.instance.collection('messages').add({
            'conversationId': bookedById,
            'senderId': widget.staffId,
            'senderName': widget.staffName,
            'senderRole': 'staff',
            'receiverId': bookedById,
            'receiverName': bookedBy,
            'receiverRole': 'staff',
            'content':
                '❌ APPOINTMENT REJECTED\n\n'
                'Your appointment booking for ${appointmentData['patientName']} has been rejected.\n\n'
                '📋 Appointment Details:\n'
                '• Patient: ${appointmentData['patientName']}\n'
                '• Department: ${appointmentData['department']}\n'
                '• Date: ${appointmentData['appointmentDate']}\n'
                '• Reason for visit: ${appointmentData['reason']}\n\n'
                '❌ Rejection Reason:\n$reason\n\n'
                'Please review and rebook if necessary.',
            'type': 'appointment_rejection',
            'priority': 'high',
            'read': false,
            'timestamp': FieldValue.serverTimestamp(),
            'appointmentId': appointmentId,
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appointment rejected and notification sent'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [HandleAppointmentAction] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<bool> _processAppointmentPayment({
    required String patientId,
    required String patientName,
    required double appointmentFee,
    required String facilityId,
    required String facilityName,
  }) async {
    print('💳 [ProcessAppointmentPayment] Starting payment process...');
    print('   Patient ID: $patientId');
    print('   Amount: ₦$appointmentFee');

    // Skip payment processing if fee is 0
    if (appointmentFee == 0) {
      print('✅ [ProcessAppointmentPayment] No payment needed - fee is ₦0');
      return true;
    }

    try {
      // Get patient details from facility_patients collection
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) {
        print('❌ [ProcessAppointmentPayment] Patient record not found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient record not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final patientData = patientDoc.data()!;
      final patientType = patientData['patientType'] as String?;
      final householdId = patientData['householdId'] as String?;

      print('👤 [ProcessAppointmentPayment] Patient Type: $patientType');
      print('🏠 [ProcessAppointmentPayment] Household ID: $householdId');

      double walletBalance = 0.0;

      // Check if patient is part of a household (LifeCare member)
      if ((patientType == 'household_member' || patientType == 'household') &&
          householdId != null) {
        // Household patient - check household wallet
        print(
          '🔍 [ProcessAppointmentPayment] Fetching household wallet: $householdId',
        );
        try {
          final householdWalletDoc = await FirebaseFirestore.instance
              .collection('household_wallets')
              .doc(householdId)
              .get();

          if (!householdWalletDoc.exists) {
            print('❌ [ProcessAppointmentPayment] Household wallet not found');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Household wallet not found.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }

          walletBalance = (householdWalletDoc.data()?['balance'] ?? 0)
              .toDouble();
          print(
            '💰 [ProcessAppointmentPayment] Household wallet balance: ₦${walletBalance.toStringAsFixed(2)}',
          );
        } catch (e) {
          print(
            '❌ [ProcessAppointmentPayment] Error fetching household wallet: $e',
          );
          return false;
        }

        if (walletBalance < appointmentFee) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient household wallet balance.\nRequired: ₦${appointmentFee.toStringAsFixed(2)}\nAvailable: ₦${walletBalance.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        // Use Firestore transaction for atomic payment
        // Facility patients (registered at facility): 100% to facility
        print(
          '💳 [ProcessAppointmentPayment] Starting atomic transaction for household wallet payment',
        );
        print('   💰 Total: ₦${appointmentFee.toStringAsFixed(2)}');
        print('   🏥 Facility patient - 100% to facility');

        try {
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final householdWalletRef = FirebaseFirestore.instance
                .collection('household_wallets')
                .doc(householdId);
            final facilityWalletRef = FirebaseFirestore.instance
                .collection('wallets')
                .doc(facilityId);

            transaction.update(householdWalletRef, {
              'balance': FieldValue.increment(-appointmentFee),
              'lastUpdated': FieldValue.serverTimestamp(),
            });

            transaction.set(facilityWalletRef, {
              'balance': FieldValue.increment(appointmentFee),
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          });

          print('✅ [ProcessAppointmentPayment] Atomic transaction completed');

          // Record transactions
          await FirebaseFirestore.instance
              .collection('household_wallets')
              .doc(householdId)
              .collection('transactions')
              .add({
                'type': 'debit',
                'amount': appointmentFee,
                'description': 'Appointment booking fee for $patientName',
                'patientId': patientId,
                'patientName': patientName,
                'facilityId': facilityId,
                'facilityName': facilityName,
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'completed',
                'processedBy': widget.staffName,
              });

          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(facilityId)
              .collection('transactions')
              .add({
                'type': 'credit',
                'amount': appointmentFee,
                'description':
                    'Appointment fee from $patientName (Facility Patient)',
                'patientId': patientId,
                'patientName': patientName,
                'householdId': householdId,
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'completed',
                'processedBy': widget.staffName,
              });
        } catch (e) {
          print('❌ [ProcessAppointmentPayment] Transaction failed: $e');
          return false;
        }
      } else {
        // Individual patient
        print(
          '💳 [ProcessAppointmentPayment] Processing individual patient payment',
        );
        final individualWalletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(patientId)
            .get();

        if (!individualWalletDoc.exists) {
          print('❌ [ProcessAppointmentPayment] Individual wallet not found');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Patient wallet not found. Please fund wallet first.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        walletBalance = (individualWalletDoc.data()?['balance'] ?? 0)
            .toDouble();
        print(
          '💰 [ProcessAppointmentPayment] Individual wallet balance: ₦${walletBalance.toStringAsFixed(2)}',
        );

        if (walletBalance < appointmentFee) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Insufficient wallet balance.\nRequired: ₦${appointmentFee.toStringAsFixed(2)}\nAvailable: ₦${walletBalance.toStringAsFixed(2)}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }

        // Use Firestore transaction for atomic payment
        print(
          '💳 [ProcessAppointmentPayment] Starting atomic transaction for individual wallet payment',
        );
        try {
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final individualWalletRef = FirebaseFirestore.instance
                .collection('wallets')
                .doc(patientId);
            final facilityWalletRef = FirebaseFirestore.instance
                .collection('wallets')
                .doc(facilityId);

            transaction.update(individualWalletRef, {
              'balance': FieldValue.increment(-appointmentFee),
              'lastUpdated': FieldValue.serverTimestamp(),
            });

            transaction.set(facilityWalletRef, {
              'balance': FieldValue.increment(appointmentFee),
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          });

          print('✅ [ProcessAppointmentPayment] Atomic transaction completed');

          // Record transactions
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(patientId)
              .collection('transactions')
              .add({
                'type': 'debit',
                'amount': appointmentFee,
                'description': 'Appointment booking fee',
                'facilityId': facilityId,
                'facilityName': facilityName,
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'completed',
                'processedBy': widget.staffName,
              });

          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(facilityId)
              .collection('transactions')
              .add({
                'type': 'credit',
                'amount': appointmentFee,
                'description': 'Appointment fee from $patientName (Individual)',
                'patientId': patientId,
                'patientName': patientName,
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'completed',
                'processedBy': widget.staffName,
              });
        } catch (e) {
          print('❌ [ProcessAppointmentPayment] Transaction failed: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ [ProcessAppointmentPayment] Error: $e');
      return false;
    }
  }

  void _showApproveDialog(
    String appointmentId,
    Map<String, dynamic> appointmentData,
  ) {
    final appointmentFee =
        (appointmentData['appointmentFee'] as num?)?.toDouble() ?? 0.0;
    final patientName = appointmentData['patientName'] ?? 'Unknown Patient';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: $patientName'),
            Text('Department: ${appointmentData['department'] ?? 'N/A'}'),
            Text(
              'Date: ${_formatAppointmentDate(appointmentData['appointmentDate'])}',
            ),
            Text('Fee: ₦${appointmentFee.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'This will process payment from the patient\'s wallet and approve the appointment.',
              style: TextStyle(fontSize: 14, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAppointmentAction(appointmentId, 'approved', null);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String appointmentId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection *',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.pop(context);
              _handleAppointmentAction(
                appointmentId,
                'rejected',
                reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  String _formatAppointmentDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date;
      }
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

// Staff Consultations Screen
class StaffConsultationsScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const StaffConsultationsScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffConsultationsScreen> createState() =>
      _StaffConsultationsScreenState();
}

class _StaffConsultationsScreenState extends State<StaffConsultationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultations'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingConsultations(),
          _buildCompletedConsultations(),
        ],
      ),
    );
  }

  Widget _buildPendingConsultations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('assignedStaffId', isEqualTo: widget.staffId)
          .where('status', isEqualTo: 'approved')
          .where('consultationStatus', isEqualTo: 'pending')
          .orderBy('appointmentDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending consultations',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Icon(Icons.person, color: Colors.purple.shade800),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${_formatAppointmentDate(data['appointmentDate'])}',
                    ),
                    Text('Reason: ${data['reason'] ?? 'N/A'}'),
                    const Text('Status: Ready for consultation'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _recordVitalSigns(doc.id, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.favorite, size: 16),
                      label: const Text('Vitals'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _startConsultation(doc.id, data),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.medical_services, size: 16),
                      label: const Text('Consult'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedConsultations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('assignedStaffId', isEqualTo: widget.staffId)
          .where('consultationStatus', isEqualTo: 'completed')
          .orderBy('consultationDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No completed consultations',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.check_circle, color: Colors.green.shade800),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${data['consultationDate']}'),
                    Text('Diagnosis: ${data['diagnosis'] ?? 'N/A'}'),
                    const Text('Status: Completed'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _viewConsultationDetails(data),
              ),
            );
          },
        );
      },
    );
  }

  void _recordVitalSigns(
    String appointmentId,
    Map<String, dynamic> appointmentData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VitalsRecordingScreen(
          patientId: appointmentData['patientId'],
          patientName: appointmentData['patientName'],
          facilityId: widget.facilityId,
        ),
      ),
    );
  }

  void _startConsultation(
    String appointmentId,
    Map<String, dynamic> appointmentData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsultationFormScreen(
          appointmentId: appointmentId,
          appointmentData: appointmentData,
          staffId: widget.staffId,
          staffName: widget.staffName,
          facilityId: widget.facilityId,
        ),
      ),
    );
  }

  void _viewConsultationDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['patientName'] ?? 'Consultation Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Date', data['consultationDate']),
              _buildDetailRow('Chief Complaint', data['chiefComplaint']),
              _buildDetailRow('Diagnosis', data['diagnosis']),
              _buildDetailRow('Treatment', data['treatment']),
              _buildDetailRow('Prescription', data['prescription']),
              _buildDetailRow('Notes', data['notes']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }

  String _formatAppointmentDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date;
      }
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

// Consultation Form Screen
class ConsultationFormScreen extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;
  final String staffId;
  final String staffName;
  final String facilityId;

  const ConsultationFormScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
    required this.staffId,
    required this.staffName,
    required this.facilityId,
  });

  @override
  State<ConsultationFormScreen> createState() => _ConsultationFormScreenState();
}

class _ConsultationFormScreenState extends State<ConsultationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chiefComplaintController = TextEditingController();
  final _vitalSignsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _vitalSignsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _prescriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final consultationData = {
        'patientId': widget.appointmentData['patientId'],
        'patientName': widget.appointmentData['patientName'],
        'facilityId': widget.facilityId,
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'appointmentId': widget.appointmentId,
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'vitalSigns': _vitalSignsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatment': _treatmentController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'notes': _notesController.text.trim(),
        'consultationDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to medical records
      await FirebaseFirestore.instance
          .collection('medical_records')
          .add(consultationData);

      // Update appointment status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
            'consultationStatus': 'completed',
            'consultationDate': DateTime.now().toIso8601String(),
            'diagnosis': _diagnosisController.text.trim(),
            'completedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Form'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Card
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.appointmentData['patientName'] ??
                            'Unknown Patient',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appointment: ${_formatAppointmentDate(widget.appointmentData['appointmentDate'])}',
                      ),
                      Text(
                        'Reason: ${widget.appointmentData['reason'] ?? 'N/A'}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Chief Complaint
              TextFormField(
                controller: _chiefComplaintController,
                decoration: const InputDecoration(
                  labelText: 'Chief Complaint *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.report),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Vital Signs
              TextFormField(
                controller: _vitalSignsController,
                decoration: const InputDecoration(
                  labelText: 'Vital Signs',
                  hintText: 'BP, Temp, Pulse, etc.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Diagnosis
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_information),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Treatment
              TextFormField(
                controller: _treatmentController,
                decoration: const InputDecoration(
                  labelText: 'Treatment Plan *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.healing),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Prescription
              TextFormField(
                controller: _prescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Prescription',
                  hintText: 'Medications and dosage',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConsultation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Consultation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAppointmentDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date;
      }
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

// Staff Referrals Screen
class StaffReferralsScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const StaffReferralsScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffReferralsScreen> createState() => _StaffReferralsScreenState();
}

class _StaffReferralsScreenState extends State<StaffReferralsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referrals'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingReferrals(), _buildApprovedReferrals()],
      ),
    );
  }

  Widget _buildPendingReferrals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('referrals')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('referredToStaffId', isEqualTo: widget.staffId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_alt_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending referrals',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.person_add, color: Colors.orange.shade800),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${data['referredByName'] ?? 'N/A'}'),
                    Text('Reason: ${data['reason'] ?? 'N/A'}'),
                    Text('Date: ${data['createdAt'] ?? 'N/A'}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () =>
                          _handleReferralAction(doc.id, 'approved', null),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _showRejectDialog(doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedReferrals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('referrals')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('referredToStaffId', isEqualTo: widget.staffId)
          .where('status', isEqualTo: 'approved')
          .orderBy('approvedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No approved referrals',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.check, color: Colors.green.shade800),
                ),
                title: Text(
                  data['patientName'] ?? 'Unknown Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${data['referredByName'] ?? 'N/A'}'),
                    Text('Reason: ${data['reason'] ?? 'N/A'}'),
                    const Text('Status: Approved - Ready for consultation'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleReferralAction(
    String referralId,
    String status,
    String? reason,
  ) async {
    try {
      final updateData = {
        'status': status,
        'approvedBy': widget.staffName,
        'approvedAt': FieldValue.serverTimestamp(),
        'rejectionReason': ?reason,
      };

      await FirebaseFirestore.instance
          .collection('referrals')
          .doc(referralId)
          .update(updateData);

      // If approved, create an appointment automatically
      if (status == 'approved') {
        final referralDoc = await FirebaseFirestore.instance
            .collection('referrals')
            .doc(referralId)
            .get();
        final referralData = referralDoc.data();

        if (referralData != null) {
          await FirebaseFirestore.instance.collection('appointments').add({
            'facilityId': widget.facilityId,
            'patientId': referralData['patientId'],
            'patientName': referralData['patientName'],
            'assignedStaffId': widget.staffId,
            'assignedStaffName': widget.staffName,
            'reason': referralData['reason'],
            'referralId': referralId,
            'status': 'approved',
            'consultationStatus': 'pending',
            'appointmentDate': DateTime.now().toIso8601String(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Referral ${status == 'approved' ? 'approved and appointment created' : 'rejected'}',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRejectDialog(String referralId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Referral'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection *',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason')),
                );
                return;
              }
              Navigator.pop(context);
              _handleReferralAction(
                referralId,
                'rejected',
                reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// Staff - Book Appointment Screen
class StaffBookAppointmentScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const StaffBookAppointmentScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffBookAppointmentScreen> createState() =>
      _StaffBookAppointmentScreenState();
}

class _StaffBookAppointmentScreenState
    extends State<StaffBookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedDepartment;
  String? _selectedStaffId;
  String? _selectedStaffName;
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  String _doctorType = 'facility'; // 'facility' or 'remote'
  double _appointmentFee = 0.0;
  bool _isLoading = false;

  final List<String> departments = [
    'General Consultation',
    'Emergency Department',
    'Pediatrics',
    'Obstetrics & Gynecology',
    'Cardiology',
    'Neurology',
    'Surgery Department',
    'Orthopedics',
    'Dermatology',
    'Ophthalmology',
    'ENT (Ear, Nose, Throat)',
    'Dental',
    'Physiotherapy',
    'Mental Health',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _appointmentDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _appointmentTime = picked);
    }
  }

  Future<void> _bookAppointment() async {
    print('📝 [BookAppointment] Starting appointment booking...');

    if (!_formKey.currentState!.validate()) {
      print('❌ [BookAppointment] Form validation failed');
      return;
    }
    if (_selectedPatientId == null) {
      print('❌ [BookAppointment] No patient selected');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a patient')));
      return;
    }
    if (_selectedDepartment == null) {
      print('❌ [BookAppointment] No department selected');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select department')));
      return;
    }
    if (_selectedStaffId == null) {
      print('❌ [BookAppointment] No doctor/staff selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor/staff')),
      );
      return;
    }
    if (_appointmentDate == null) {
      print('❌ [BookAppointment] No appointment date selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select appointment date')),
      );
      return;
    }
    if (_appointmentTime == null) {
      print('❌ [BookAppointment] No appointment time selected');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select appointment time')),
      );
      return;
    }

    print('✅ [BookAppointment] All validations passed');
    print('📋 [BookAppointment] Details:');
    print('   Patient ID: $_selectedPatientId');
    print('   Patient Name: $_selectedPatientName');
    print('   Department: $_selectedDepartment');
    print('   Doctor Type: $_doctorType');
    print('   Staff ID: $_selectedStaffId');
    print('   Staff Name: $_selectedStaffName');
    print('   Fee: ₦$_appointmentFee');

    setState(() => _isLoading = true);

    try {
      // DO NOT process payment yet - payment will be processed when doctor approves
      print(
        '📝 [BookAppointment] Creating appointment without payment (pending approval)...',
      );

      final appointmentDateTime = DateTime(
        _appointmentDate!.year,
        _appointmentDate!.month,
        _appointmentDate!.day,
        _appointmentTime!.hour,
        _appointmentTime!.minute,
      );

      print('📅 [BookAppointment] Creating appointment data...');
      final appointmentData = {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'department': _selectedDepartment,
        'assignedStaffId': _selectedStaffId,
        'assignedStaffName': _selectedStaffName,
        'doctorType': _doctorType,
        'reason': _reasonController.text.trim(),
        'appointmentDate': appointmentDateTime.toIso8601String(),
        'appointmentTime':
            '${_appointmentTime!.hour.toString().padLeft(2, '0')}:${_appointmentTime!.minute.toString().padLeft(2, '0')}',
        'appointmentFee': _appointmentFee,
        'paymentMethod': 'wallet',
        'paymentStatus': 'pending', // Payment will be processed after approval
        'status':
            'pending', // Must be pending so it shows in doctor's pending appointments
        'consultationStatus': 'pending',
        'bookedBy': widget.staffName,
        'bookedById': widget.staffId,
        'bookedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('📤 [BookAppointment] Saving appointment to Firestore...');
      print('   Data: $appointmentData');

      await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      print('✅ [BookAppointment] Appointment saved successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment booked successfully! Pending doctor approval. Payment of ₦${_appointmentFee.toStringAsFixed(2)} will be processed upon approval.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('❌ [BookAppointment] Error occurred: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appointment Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              // Select Patient
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('facility_patients')
                    .where('facilityId', isEqualTo: widget.facilityId)
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final patients = snapshot.data!.docs;

                  return DropdownButtonFormField<String>(
                    value: _selectedPatientId,
                    decoration: const InputDecoration(
                      labelText: 'Select Patient *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: patients.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['fullName'] ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPatientId = value;
                        final selected = patients.firstWhere(
                          (d) => d.id == value,
                        );
                        final data = selected.data() as Map<String, dynamic>;
                        _selectedPatientName = data['fullName'];
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Select Department
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Select Department *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
                items: departments.map((dept) {
                  return DropdownMenuItem(value: dept, child: Text(dept));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                    _selectedStaffId =
                        null; // Reset staff selection when department changes
                  });
                },
              ),
              const SizedBox(height: 16),

              // Doctor Type Selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor Type',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Facility Doctor'),
                            value: 'facility',
                            groupValue: _doctorType,
                            onChanged: (value) async {
                              setState(() {
                                _doctorType = value!;
                                _selectedStaffId = null;
                              });
                              // Fetch appointment booking fee from facility pricing
                              final price =
                                  await FacilityPricingService.getServicePrice(
                                    widget.facilityId,
                                    'appointment_booking',
                                    1000.0, // Default fallback
                                  );
                              setState(() {
                                _appointmentFee = price;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Remote Doctor'),
                            value: 'remote',
                            groupValue: _doctorType,
                            onChanged: (value) async {
                              setState(() {
                                _doctorType = value!;
                                _selectedStaffId = null;
                              });
                              // Fetch telemedicine consultation fee from facility pricing
                              final price =
                                  await FacilityPricingService.getServicePrice(
                                    widget.facilityId,
                                    'telemedicine_consultation',
                                    2000.0, // Default fallback
                                  );
                              setState(() {
                                _appointmentFee = price;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Select Staff (Facility or Remote)
              if (_doctorType == 'facility')
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(
                        '${widget.facilityName.toLowerCase().replaceAll(' ', '_')}_users',
                      )
                      .where('emailVerified', isEqualTo: true)
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final staff = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final profession = data['profession'] as String?;
                      final dept = data['department'] as String?;
                      // Filter by selected department and clinical staff
                      return profession != null &&
                          (_selectedDepartment == null ||
                              dept == _selectedDepartment) &&
                          [
                            'Doctor',
                            'Nurse',
                            'Community Health Officer',
                            'Midwife',
                          ].contains(profession);
                    }).toList();

                    return DropdownButtonFormField<String>(
                      value: _selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Select Facility Doctor/Staff *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                      items: staff.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: data['staffId'] as String?,
                          child: Text(
                            '${data['fullName']} (${data['profession']})',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStaffId = value;
                          final selected = staff.firstWhere(
                            (d) =>
                                (d.data() as Map<String, dynamic>)['staffId'] ==
                                value,
                          );
                          final data = selected.data() as Map<String, dynamic>;
                          _selectedStaffName = data['fullName'];
                        });
                      },
                    );
                  },
                )
              else
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: 'doctor')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    // Filter doctors that are approved (if isApproved field exists)
                    final doctors = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      // Include doctor if isApproved is true or field doesn't exist
                      return data['isApproved'] == true ||
                          !data.containsKey('isApproved');
                    }).toList();

                    return DropdownButtonFormField<String>(
                      value: _selectedStaffId,
                      decoration: const InputDecoration(
                        labelText: 'Select Remote Doctor *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.video_call),
                        helperText:
                            'Online doctors available for remote consultation',
                      ),
                      items: doctors.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final doctorName =
                            data['fullName'] ??
                            data['displayName'] ??
                            'Unknown';
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dr. $doctorName'),
                              Text(
                                data['specialization'] ?? 'General Practice',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStaffId = value;
                          final selected = doctors.firstWhere(
                            (d) => d.id == value,
                          );
                          final data = selected.data() as Map<String, dynamic>;
                          final doctorName =
                              data['fullName'] ??
                              data['displayName'] ??
                              'Doctor';
                          _selectedStaffName = 'Dr. $doctorName';
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Appointment Date *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _appointmentDate == null
                        ? 'Select date'
                        : '${_appointmentDate!.day}/${_appointmentDate!.month}/${_appointmentDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time
              InkWell(
                onTap: _selectTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Appointment Time *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    _appointmentTime == null
                        ? 'Select time'
                        : _appointmentTime!.format(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Appointment *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Payment Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Appointment Fee: ₦${_appointmentFee.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Method: Patient Wallet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Amount will be deducted from patient wallet (household or individual)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Book Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _bookAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Book Appointment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// Staff Settings Screen
// =====================================================
class StaffSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> staffData;
  final String facilityName;
  final String staffCollection;

  const StaffSettingsScreen({
    super.key,
    required this.staffData,
    required this.facilityName,
    required this.staffCollection,
  });

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: Colors.teal),
              SizedBox(width: 8),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureCurrentPassword = !obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Password must be at least 6 characters',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final currentPassword = currentPasswordController.text
                          .trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirmPassword = confirmPasswordController.text
                          .trim();

                      // Validation
                      if (currentPassword.isEmpty ||
                          newPassword.isEmpty ||
                          confirmPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All fields are required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPassword != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Passwords do not match'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Verify current password
                      final storedPassword = widget.staffData['password'];
                      if (storedPassword != currentPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Current password is incorrect'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        // Get the document ID from SharedPreferences
                        final prefs = await SharedPreferences.getInstance();
                        final staffId = prefs.getString('staff_id');

                        if (staffId == null) {
                          throw Exception('Staff ID not found');
                        }

                        // Find the staff document
                        final staffQuery = await FirebaseFirestore.instance
                            .collection(widget.staffCollection)
                            .where('staffId', isEqualTo: staffId)
                            .limit(1)
                            .get();

                        if (staffQuery.docs.isEmpty) {
                          throw Exception('Staff document not found');
                        }

                        final staffDoc = staffQuery.docs.first;

                        // Update password
                        await staffDoc.reference.update({
                          'password': newPassword,
                          'passwordSetAt': FieldValue.serverTimestamp(),
                          'passwordChangedByUser': true,
                        });

                        // Update widget staffData with new password to keep it in sync
                        widget.staffData['password'] = newPassword;

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Password changed successfully!'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // Account Settings Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.lock_reset, color: Colors.white),
              ),
              title: const Text(
                'Change Password',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Update your account password'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showChangePasswordDialog,
            ),
          ),
          const SizedBox(height: 16),
          // Account Information Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Account Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Staff ID', widget.staffData['staffId']),
                  const Divider(),
                  _buildInfoRow('Full Name', widget.staffData['fullName']),
                  const Divider(),
                  _buildInfoRow('Profession', widget.staffData['profession']),
                  const Divider(),
                  _buildInfoRow('Department', widget.staffData['department']),
                  const Divider(),
                  _buildInfoRow('Email', widget.staffData['email']),
                  const Divider(),
                  _buildInfoRow('Phone', widget.staffData['phone']),
                  const Divider(),
                  _buildInfoRow('Facility', widget.facilityName),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// Staff Messaging Screen
class StaffMessagingScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const StaffMessagingScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<StaffMessagingScreen> createState() => _StaffMessagingScreenState();
}

class _StaffMessagingScreenState extends State<StaffMessagingScreen> {
  final _messageController = TextEditingController();
  String? _selectedRecipientId;
  String? _selectedRecipientName;
  List<Map<String, dynamic>> _facilityStaff = [];
  bool _isLoadingStaff = true;

  @override
  void initState() {
    super.initState();
    _loadFacilityStaff();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityStaff() async {
    try {
      // Get all staff in the facility (excluding current user)
      final staffQuerySnapshot = await FirebaseFirestore.instance
          .collection('${widget.facilityId}_users')
          .where('status', isEqualTo: 'active')
          .get();

      // Get facility admin
      final adminQuerySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .where('uid', isEqualTo: widget.facilityId)
          .get();

      List<Map<String, dynamic>> allStaff = [];

      // Add facility staff
      allStaff.addAll(
        staffQuerySnapshot.docs
            .where((doc) => doc.id != widget.staffId) // Exclude current user
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['fullName'] ?? 'Unknown',
                'profession': data['profession'] ?? 'Staff',
                'department': data['department'] ?? 'General',
              };
            })
            .toList(),
      );

      // Add facility admin
      if (adminQuerySnapshot.docs.isNotEmpty) {
        final adminData = adminQuerySnapshot.docs.first.data();
        if (adminQuerySnapshot.docs.first.id != widget.staffId) {
          allStaff.add({
            'id': adminQuerySnapshot.docs.first.id,
            'name': adminData['name'] ?? 'Facility Admin',
            'profession': 'Facility Administrator',
            'department': 'Administration',
          });
        }
      }

      setState(() {
        _facilityStaff = allStaff;
        _isLoadingStaff = false;
      });
    } catch (e) {
      print('Error loading facility staff: $e');
      setState(() {
        _isLoadingStaff = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showNewMessageDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Staff Directory Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Facility Staff',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingStaff)
                  const Center(child: CircularProgressIndicator())
                else if (_facilityStaff.isEmpty)
                  const Text('No other staff found in this facility')
                else
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _facilityStaff.length,
                      itemBuilder: (context, index) {
                        final staff = _facilityStaff[index];
                        return GestureDetector(
                          onTap: () =>
                              _selectRecipient(staff['id'], staff['name']),
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: _selectedRecipientId == staff['id']
                                  ? Colors.green.shade100
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedRecipientId == staff['id']
                                    ? Colors.green
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green.shade700,
                                  child: Text(
                                    staff['name'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  staff['name'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  staff['profession'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Messages Section
          Expanded(
            child: _selectedRecipientId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Select a staff member to start messaging',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildChatSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.shade700,
                child: Text(
                  _selectedRecipientName![0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRecipientName!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Active now',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Messages List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .where(
                  'conversationId',
                  whereIn: [
                    '${widget.staffId}_$_selectedRecipientId',
                    '${_selectedRecipientId}_${widget.staffId}',
                  ],
                )
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet. Start a conversation!',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final messageData =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final isMe = messageData['senderId'] == widget.staffId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.green.shade700,
                            child: Text(
                              messageData['senderName'][0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.green.shade700
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              messageData['content'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.green.shade700,
                            child: Text(
                              widget.staffName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Message Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, color: Colors.green.shade700),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectRecipient(String recipientId, String recipientName) {
    setState(() {
      _selectedRecipientId = recipientId;
      _selectedRecipientName = recipientName;
    });
  }

  void _showNewMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Message'),
        content: const Text(
          'Select a staff member from the list above to start messaging.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _selectedRecipientId == null) {
      return;
    }

    try {
      final conversationId = '${widget.staffId}_$_selectedRecipientId';

      await FirebaseFirestore.instance.collection('messages').add({
        'conversationId': conversationId,
        'senderId': widget.staffId,
        'senderName': widget.staffName,
        'senderRole': 'staff',
        'receiverId': _selectedRecipientId,
        'receiverName': _selectedRecipientName,
        'receiverRole': 'staff',
        'content': _messageController.text.trim(),
        'type': 'text',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Completed Consultations Screen - Shows patients with completed consultations for medical records access
class CompletedConsultationsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const CompletedConsultationsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<CompletedConsultationsScreen> createState() =>
      _CompletedConsultationsScreenState();
}

class _CompletedConsultationsScreenState
    extends State<CompletedConsultationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Completed Consultations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('appointments')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('assignedStaffId', isEqualTo: widget.staffId)
                  .where('status', isEqualTo: 'completed')
                  .orderBy('completedAt', descending: true)
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_shared,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No completed consultations',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patients with completed consultations will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Filter appointments by search query
                var appointments = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;

                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();

                  return patientName.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final doc = appointments[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade800,
                          ),
                        ),
                        title: Text(
                          data['patientName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consultation Date: ${_formatAppointmentDate(data['appointmentDate'])}',
                            ),
                            if (data['completedAt'] != null)
                              Text(
                                'Completed: ${_formatTimestamp(data['completedAt'])}',
                              ),
                            if (data['reason'] != null)
                              Text('Reason: ${data['reason']}'),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientMedicalRecordsScreen(
                                patientId: data['patientId'] ?? '',
                                patientName: data['patientName'] ?? 'Unknown',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }

  String _formatAppointmentDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date; // Return as-is if parsing fails
      }
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}

// Facility Consultation Screen with wallet integration and patient movement
class FacilityConsultationScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String facilityId;
  final String clinicianId;
  final String clinicianName;

  const FacilityConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.facilityId,
    required this.clinicianId,
    required this.clinicianName,
  });

  @override
  State<FacilityConsultationScreen> createState() =>
      _FacilityConsultationScreenState();
}

class _FacilityConsultationScreenState
    extends State<FacilityConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chiefComplaintController = TextEditingController();
  final _vitalSignsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _consultationFeeController = TextEditingController(
    text: '5000',
  ); // Default fee
  bool _isLoading = false;
  String? _appointmentId;

  @override
  void initState() {
    super.initState();
    _findPatientAppointment();
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _vitalSignsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _prescriptionController.dispose();
    _notesController.dispose();
    _consultationFeeController.dispose();
    super.dispose();
  }

  Future<void> _findPatientAppointment() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('assignedStaffId', isEqualTo: widget.clinicianId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _appointmentId = querySnapshot.docs.first.id;
        });
      }
    } catch (e) {
      print('Error finding appointment: $e');
    }
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final consultationFee =
          double.tryParse(_consultationFeeController.text) ?? 5000.0;

      // Create consultation data
      final consultationData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'facilityId': widget.facilityId,
        'staffId': widget.clinicianId,
        'staffName': widget.clinicianName,
        'appointmentId': _appointmentId,
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'vitalSigns': _vitalSignsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatment': _treatmentController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'notes': _notesController.text.trim(),
        'consultationFee': consultationFee,
        'consultationDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to medical records
      await FirebaseFirestore.instance
          .collection('medical_records')
          .add(consultationData);

      // Process wallet transaction and move patient to medical records
      await _processConsultationCompletion(consultationFee);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consultation completed successfully. Fee of ₦${consultationFee.toStringAsFixed(0)} deducted from patient wallet.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processConsultationCompletion(double consultationFee) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Update appointment status to completed
    if (_appointmentId != null) {
      final appointmentRef = FirebaseFirestore.instance
          .collection('appointments')
          .doc(_appointmentId!);

      batch.update(appointmentRef, {
        'consultationStatus': 'completed',
        'consultationDate': DateTime.now().toIso8601String(),
        'diagnosis': _diagnosisController.text.trim(),
        'completedAt': FieldValue.serverTimestamp(),
        'status': 'completed', // Move from approved to completed
      });
    }

    // 2. Deduct from patient/household wallet
    await _deductFromPatientWallet(consultationFee);

    // 3. Credit facility admin wallet
    await _creditFacilityWallet(consultationFee);

    // Commit the batch
    await batch.commit();
  }

  Future<void> _deductFromPatientWallet(double amount) async {
    try {
      // First check patient's own wallet
      final patientWalletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.patientId)
          .get();

      if (patientWalletDoc.exists) {
        final currentBalance = (patientWalletDoc.data()?['balance'] ?? 0.0)
            .toDouble();

        if (currentBalance >= amount) {
          // Deduct from patient's wallet
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(widget.patientId)
              .update({
                'balance': FieldValue.increment(-amount),
                'lastUpdated': FieldValue.serverTimestamp(),
              });

          // Record transaction
          await FirebaseFirestore.instance
              .collection('wallet_transactions')
              .add({
                'walletId': widget.patientId,
                'type': 'debit',
                'amount': amount,
                'description': 'Consultation fee - ${widget.patientName}',
                'reference':
                    'CONSULTATION_${DateTime.now().millisecondsSinceEpoch}',
                'facilityId': widget.facilityId,
                'staffId': widget.clinicianId,
                'createdAt': FieldValue.serverTimestamp(),
              });
          return;
        }
      }

      // If patient wallet insufficient, try household wallet
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .get();

      final householdId = patientDoc.data()?['householdId'];
      if (householdId != null) {
        final householdWalletDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        if (householdWalletDoc.exists) {
          final householdBalance =
              (householdWalletDoc.data()?['balance'] ?? 0.0).toDouble();

          if (householdBalance >= amount) {
            // Deduct from household wallet
            await FirebaseFirestore.instance
                .collection('household_wallets')
                .doc(householdId)
                .update({
                  'balance': FieldValue.increment(-amount),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });

            // Record transaction
            await FirebaseFirestore.instance
                .collection('wallet_transactions')
                .add({
                  'walletId': householdId,
                  'type': 'debit',
                  'amount': amount,
                  'description': 'Consultation fee for ${widget.patientName}',
                  'reference':
                      'CONSULTATION_${DateTime.now().millisecondsSinceEpoch}',
                  'facilityId': widget.facilityId,
                  'staffId': widget.clinicianId,
                  'patientId': widget.patientId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
            return;
          }
        }
      }

      throw Exception('Insufficient balance in patient and household wallets');
    } catch (e) {
      throw Exception('Wallet deduction failed: $e');
    }
  }

  Future<void> _creditFacilityWallet(double amount) async {
    try {
      // Get facility admin ID
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.facilityId)
          .get();

      if (!facilityDoc.exists) {
        throw Exception('Facility not found');
      }

      // Credit facility wallet
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.facilityId)
          .set({
            'balance': FieldValue.increment(amount),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Record transaction
      await FirebaseFirestore.instance.collection('wallet_transactions').add({
        'walletId': widget.facilityId,
        'type': 'credit',
        'amount': amount,
        'description': 'Consultation fee from ${widget.patientName}',
        'reference': 'CONSULTATION_${DateTime.now().millisecondsSinceEpoch}',
        'patientId': widget.patientId,
        'staffId': widget.clinicianId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Facility wallet credit failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Form'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Card
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient: ${widget.patientName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Patient ID: ${widget.patientId}'),
                      Text('Clinician: ${widget.clinicianName}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Chief Complaint
              TextFormField(
                controller: _chiefComplaintController,
                decoration: const InputDecoration(
                  labelText: 'Chief Complaint',
                  hintText: 'Patient\'s main concern or reason for visit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.record_voice_over),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Vital Signs
              TextFormField(
                controller: _vitalSignsController,
                decoration: const InputDecoration(
                  labelText: 'Vital Signs',
                  hintText: 'BP, Temperature, Pulse, etc.',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_heart),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Diagnosis
              TextFormField(
                controller: _diagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  hintText: 'Medical diagnosis or assessment',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medical_services),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Treatment
              TextFormField(
                controller: _treatmentController,
                decoration: const InputDecoration(
                  labelText: 'Treatment Plan',
                  hintText: 'Recommended treatment or procedures',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.healing),
                ),
                maxLines: 2,
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Prescription
              TextFormField(
                controller: _prescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Prescription',
                  hintText: 'Medications and dosage',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Consultation Fee
              TextFormField(
                controller: _consultationFeeController,
                decoration: const InputDecoration(
                  labelText: 'Consultation Fee (₦)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Required';
                  if (double.tryParse(value!) == null) {
                    return 'Enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConsultation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Complete Consultation & Process Payment',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
