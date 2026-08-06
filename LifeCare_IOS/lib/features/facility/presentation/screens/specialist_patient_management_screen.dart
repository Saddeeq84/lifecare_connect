import 'package:flutter/material.dart';
import 'nursing_inpatients_screen.dart';
import 'facility_outpatient_screen.dart';

class SpecialistPatientManagementScreen extends StatelessWidget {
  final String facilityId;
  final String facilityName;
  final String specialistId;
  final String specialistName;

  const SpecialistPatientManagementScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.specialistId,
    required this.specialistName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Management'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                      Icon(Icons.groups, size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Patient Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              facilityName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      children: [
                        TextSpan(text: 'Manage in-patients and out-patients'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Dashboard Items
            _buildDashboardCard(
              context: context,
              title: 'In-Patient',
              subtitle: 'Admitted patients',
              icon: Icons.hotel,
              color: Colors.orange,
              onTap: () => _navigateToInPatients(context),
            ),
            const SizedBox(height: 12),

            _buildDashboardCard(
              context: context,
              title: 'Out-Patient',
              subtitle: 'Consultation screen',
              icon: Icons.people,
              color: Colors.green,
              onTap: () => _navigateToOutPatients(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
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
          size: 18,
          color: Colors.grey.shade400,
        ),
        onTap: onTap,
      ),
    );
  }

  void _navigateToInPatients(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NursingInpatientsScreen(
          facilityId: facilityId,
          facilityName: facilityName,
          staffId: specialistId,
          staffName: specialistName,
          isViewOnly: true, // View-only mode for specialist dashboard
          filterBySpecialistDepartments:
              true, // Show only specialist department admissions
          // wardId is null for specialists to see all wards
        ),
      ),
    );
  }

  void _navigateToOutPatients(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityOutpatientScreen(
          facilityId: facilityId,
          facilityName: facilityName,
          filterBySpecialistDepartments:
              true, // Only show specialist appointments
        ),
      ),
    );
  }
}
