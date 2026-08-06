import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'patient_management_screen.dart';
import 'medical_records_reports_screen.dart';
import 'medical_records_appointments_screen.dart';
import 'medical_records_patient_records_screen.dart';
import 'facility_household_screen.dart';
import 'medical_records_refund_screen.dart';
import '../widgets/staff_password_change_dialog.dart';

/// Medical Records Department Dashboard
/// Accessible by: Medical Records Officers, Health Information Managers, Front Desk Officers
class MedicalRecordsDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const MedicalRecordsDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<MedicalRecordsDashboardScreen> createState() =>
      _MedicalRecordsDashboardScreenState();
}

class _MedicalRecordsDashboardScreenState
    extends State<MedicalRecordsDashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await FirebaseAuth.instance.signOut();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏥 [MedicalRecords] facilityId: ${widget.facilityId}');
    print('🏥 [MedicalRecords] facilityName: ${widget.facilityName}');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.facilityName} - Medical Records'),
        backgroundColor: Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => StaffPasswordChangeDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            Text(
              'Medical Records Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildDashboardGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared, size: 32, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${widget.staffName}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Medical Records Department',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey.shade100,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Manage appointments, patient records, and generate reports.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey.shade100,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    final items = [
      {
        'title': 'Appointments',
        'subtitle': 'Manage appointments',
        'icon': Icons.calendar_today,
        'color': Colors.orange,
        'onTap': () => _navigateToAppointments(),
      },
      {
        'title': 'Patient Management',
        'subtitle': 'Register and manage facility patients',
        'icon': Icons.people,
        'color': Colors.teal,
        'onTap': () => _navigateToPatientManagement(),
      },
      {
        'title': 'Patient Records',
        'subtitle': 'View completed medical records',
        'icon': Icons.folder_open,
        'color': Colors.blue,
        'onTap': () => _navigateToPatientRecords(),
      },
      {
        'title': 'Apply Refund',
        'subtitle': 'Request wallet refund for patients',
        'icon': Icons.monetization_on,
        'color': Colors.purple,
        'onTap': () => _navigateToRefund(),
      },
      {
        'title': 'Lifecare Insurance',
        'subtitle': 'Manage household subscriptions',
        'icon': Icons.home_work,
        'color': Colors.indigo,
        'onTap': () => _navigateToHouseholds(),
      },
      {
        'title': 'Reports',
        'subtitle': 'View statistics and reports',
        'icon': Icons.assessment,
        'color': Colors.purple.shade300,
        'onTap': () => _navigateToReports(),
      },
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildDashboardCard(
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            icon: item['icon'] as IconData,
            color: item['color'] as Color,
            onTap: item['onTap'] as VoidCallback,
          ),
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 28, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }

  void _navigateToAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordsAppointmentsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
        ),
      ),
    );
  }

  void _navigateToPatientManagement() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientManagementScreen(
            facilityId: widget.facilityId,
            facilityName: widget.facilityName,
            hideOutPatients:
                true, // Hide out-patients for Medical Records dashboard
          ),
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
  }

  void _navigateToPatientRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordsPatientRecordsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
        ),
      ),
    );
  }

  void _navigateToReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordsReportsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToRefund() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalRecordsRefundScreen(
          facilityId: widget.facilityId,
          staffId: widget.staffId,
          staffName: widget.staffName,
          department: 'Medical Records',
        ),
      ),
    );
  }

  void _navigateToHouseholds() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FacilityHouseholdScreen(facilityId: widget.facilityId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening households: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
