import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'nursing_inpatients_screen.dart';
import 'ward_reports_analytics_screen.dart';
import 'ward_setup_screen.dart';
import 'patient_daily_report_screen.dart';
import 'emergency_pending_admissions_screen.dart';

/// Ward Dashboard Screen
/// Provides centralized access to ward management features
/// Accessible by: Doctors, Surgeons (all medical specialists), Nurses, Midwives, Nurse Assistants, Nurse Practitioners
class WardDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String? wardId; // Optional - null means access to all wards
  final bool isFromOPD; // True when accessed from OPD dashboard
  final bool
  filterByEmergency; // True when accessed from Emergency dashboard to show only emergency admissions

  const WardDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.wardId,
    this.isFromOPD = false, // Default to false for normal ward management
    this.filterByEmergency = false, // Default to false for general access
  });

  @override
  State<WardDashboardScreen> createState() => _WardDashboardScreenState();
}

class _WardDashboardScreenState extends State<WardDashboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.wardId != null
              ? '${widget.facilityName} - Ward Management'
              : '${widget.facilityName} - All Wards',
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_hotel, size: 32, color: Colors.white),
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
                              'Ward Management',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.teal.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.wardId != null
                        ? 'Manage admitted patients, ward rounds, and patient care in your assigned ward.'
                        : 'Manage admitted patients, ward rounds, and patient care across all wards.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.teal.shade100,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main Dashboard Actions
            Text(
              'Ward Management',
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

  Widget _buildDashboardGrid() {
    final items = [
      // Show "Pending Admissions" ONLY when accessed from Emergency dashboard
      if (widget.filterByEmergency)
        {
          'title': 'Pending Admissions',
          'subtitle': 'Accept emergency admissions',
          'icon': Icons.pending_actions,
          'color': Colors.amber,
          'onTap': () => _navigateToPendingAdmissions(),
        },
      // Only show "Create New Ward" if NOT from OPD dashboard
      if (!widget.isFromOPD)
        {
          'title': 'Create New Ward',
          'subtitle': 'Setup new ward with beds',
          'icon': Icons.add_business,
          'color': Colors.orange,
          'onTap': () => _navigateToWardSetup(),
        },
      {
        'title': 'In-Patients',
        'subtitle': 'Admitted patients',
        'icon': Icons.hotel,
        'color': Colors.blue,
        'onTap': () => _navigateToInPatients(),
      },
      {
        'title': 'Ward Rounds',
        'subtitle': 'Daily ward rounds',
        'icon': Icons.medical_services,
        'color': Colors.green,
        'onTap': () => _navigateToWardRounds(),
      },
      {
        'title': 'Discharges',
        'subtitle': 'Discharge patients',
        'icon': Icons.logout,
        'color': Colors.purple,
        'onTap': () => _navigateToDischarges(),
      },
      {
        'title': 'Vital Signs',
        'subtitle': 'Record vital signs',
        'icon': Icons.monitor_heart,
        'color': Colors.red,
        'onTap': () => _navigateToVitalSigns(),
      },
      {
        'title': 'Medications',
        'subtitle': 'Medication administration',
        'icon': Icons.medication,
        'color': Colors.teal,
        'onTap': () => _navigateToMedications(),
      },
      {
        'title': 'Reports',
        'subtitle': 'Ward statistics and reports',
        'icon': Icons.analytics,
        'color': Colors.indigo,
        'onTap': () => _navigateToReportsAnalytics(),
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

  void _navigateToInPatients() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NursingInpatientsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          wardId: widget.wardId, // Pass wardId to filter patients if specified
          isViewOnly: widget.isFromOPD, // View-only if from OPD dashboard
          filterByEmergency: widget
              .filterByEmergency, // Filter emergency admissions when from Emergency dashboard
          excludeEmergencyAdmissions: !widget
              .filterByEmergency, // Exclude emergency when NOT from Emergency dashboard (includes Nursing and Specialist dashboards)
        ),
      ),
    );
  }

  void _navigateToWardRounds() {
    context.push(
      '/ward_rounds',
      extra: {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'wardId': widget.wardId,
        'excludeEmergencyAdmissions': !widget
            .filterByEmergency, // Exclude emergency when NOT from Emergency dashboard
        'filterByEmergency': widget.filterByEmergency,
      },
    );
  }

  void _navigateToDischarges() {
    context.push(
      '/ward_discharges',
      extra: {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'wardId': widget.wardId,
        'excludeEmergencyAdmissions': !widget
            .filterByEmergency, // Exclude emergency when NOT from Emergency dashboard
        'filterByEmergency': widget.filterByEmergency,
      },
    );
  }

  void _navigateToVitalSigns() {
    context.push(
      '/ward_vital_signs',
      extra: {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'wardId': widget.wardId,
        'excludeEmergencyAdmissions': !widget
            .filterByEmergency, // Exclude emergency when NOT from Emergency dashboard
        'filterByEmergency': widget.filterByEmergency,
      },
    );
  }

  void _navigateToMedications() {
    context.push(
      '/ward_medications',
      extra: {
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'staffId': widget.staffId,
        'staffName': widget.staffName,
        'wardId': widget.wardId,
        'excludeEmergencyAdmissions': !widget
            .filterByEmergency, // Exclude emergency when NOT from Emergency dashboard
        'filterByEmergency': widget.filterByEmergency,
      },
    );
  }

  void _navigateToReportsAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WardReportsAnalyticsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          wardId: widget.wardId,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  // ignore: unused_element
  void _navigateToPatientDailyReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDailyReportScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToPendingAdmissions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyPendingAdmissionsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToWardSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WardSetupScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
        ),
      ),
    );
  }
}
