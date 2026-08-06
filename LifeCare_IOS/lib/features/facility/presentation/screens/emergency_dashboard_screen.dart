import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'emergency_appointments_screen.dart';
import 'emergency_patient_management_screen.dart';
import 'ward_dashboard_screen.dart';
import 'medical_records_patient_records_screen.dart';
import '../widgets/staff_password_change_dialog.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';

class EmergencyDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const EmergencyDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<EmergencyDashboardScreen> createState() =>
      _EmergencyDashboardScreenState();
}

class _EmergencyDashboardScreenState extends State<EmergencyDashboardScreen> {
  Stream<QuerySnapshot> _getEmergencyAdmissionsStream() {
    return FirebaseFirestore.instance
        .collection('admissions')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('admissionType', isEqualTo: 'emergency')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Map<String, int> _calculateStats(List<DocumentSnapshot> docs) {
    int critical = 0;
    int urgent = 0;
    int moderate = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final severity = (data['severity'] ?? 'moderate')
          .toString()
          .toLowerCase();

      if (severity == 'critical') {
        critical++;
      } else if (severity == 'urgent') {
        urgent++;
      } else {
        moderate++;
      }
    }

    return {
      'critical': critical,
      'urgent': urgent,
      'moderate': moderate,
      'total': docs.length,
    };
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
    final facilityDisplayName = widget.facilityName.isEmpty
        ? 'Facility'
        : widget.facilityName;
    final staffDisplayName = widget.staffName.isEmpty
        ? 'Staff'
        : widget.staffName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$facilityDisplayName - Emergency'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI Assistant - Emergency Triage Support',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIAssistantScreen(
                    assistantType: AIAssistantType.doctor,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Change Password',
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
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade200,
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
                      Icon(Icons.emergency, size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, $staffDisplayName',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Emergency Department',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Manage critical cases, triage assessments, emergency admissions, and urgent patient care.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.95),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main Dashboard Actions
            Text(
              'Emergency Management',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            _buildDashboardGrid(),

            const SizedBox(height: 32),

            // Emergency Statistics
            Text(
              'Emergency Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _getEmergencyAdmissionsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Error loading statistics: ${snapshot.error}',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingStats();
                }

                final stats = _calculateStats(snapshot.data?.docs ?? []);
                return _buildStatisticsList(
                  stats['critical']!,
                  stats['urgent']!,
                  stats['moderate']!,
                  stats['total']!,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStats() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildLoadingStatCard(),
        ),
      ),
    );
  }

  Widget _buildLoadingStatCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsList(
    int criticalCases,
    int urgentCases,
    int moderateCases,
    int totalCases,
  ) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Critical Cases',
          criticalCases.toString(),
          Icons.warning,
          Colors.red,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Urgent Cases',
          urgentCases.toString(),
          Icons.priority_high,
          Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Moderate Cases',
          moderateCases.toString(),
          Icons.info,
          Colors.yellow.shade700,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Total Active Cases',
          totalCases.toString(),
          Icons.local_hospital,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
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
        'subtitle': 'Review & approve emergency appointments',
        'icon': Icons.calendar_today,
        'color': Colors.green,
        'onTap': () => _navigateToAppointments(),
      },
      {
        'title': 'Patient Management',
        'subtitle': 'In-patient & out-patient management',
        'icon': Icons.groups,
        'color': Colors.indigo,
        'onTap': () => _navigateToPatientManagement(),
      },
      {
        'title': 'Ward Management',
        'subtitle': 'Manage admitted emergency patients',
        'icon': Icons.local_hotel,
        'color': Colors.orange,
        'onTap': () => _navigateToWardManagement(),
      },
      {
        'title': 'Patient Records',
        'subtitle': 'View patient medical records',
        'icon': Icons.folder_open,
        'color': Colors.blue,
        'onTap': () => _navigateToPatientRecords(),
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
        builder: (context) => EmergencyAppointmentsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToPatientManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencyPatientManagementScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  void _navigateToWardManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WardDashboardScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.staffId,
          staffName: widget.staffName,
          isFromOPD: false, // Allow full ward management in Emergency
          filterByEmergency: true,
        ),
      ),
    );
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
}
