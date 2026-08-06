import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'ward_dashboard_screen.dart';
import 'nursing_pending_admissions_screen.dart';
import 'medical_records_patient_records_screen.dart';
import 'facility_outpatient_screen.dart';
import '../widgets/staff_password_change_dialog.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';

/// Nursing Department Dashboard
/// Accessible by: Nurses, Nurse Assistants, CHOs, CHEWs, Midwives, Nurse Practitioners, Medical Assistants
class NursingDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const NursingDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<NursingDashboardScreen> createState() => _NursingDashboardScreenState();
}

class _NursingDashboardScreenState extends State<NursingDashboardScreen> {
  int _totalPatients = 0;
  int _inPatients = 0;
  int _pendingConsultations = 0;
  int _completedToday = 0;
  int _pendingAdmissions = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Load patients statistics
      final patientsQuery = await FirebaseFirestore.instance
          .collection('facility_patients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .get();

      int totalPatients = patientsQuery.docs.length;

      // Load in-patients statistics
      final inPatientsQuery = await FirebaseFirestore.instance
          .collection('inpatients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'admitted')
          .get();

      int inPatientsCount = inPatientsQuery.docs.length;

      // Load pending consultations
      final pendingQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'approved')
          .get();

      int pendingCount = pendingQuery.docs.length;

      // Load completed consultations today
      final completedQuery = await FirebaseFirestore.instance
          .collection('health_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'completed')
          .get();

      int completedToday = completedQuery.docs.where((doc) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        return createdAt != null && createdAt.isAfter(startOfDay);
      }).length;

      // Load pending admissions
      final pendingAdmissionsQuery = await FirebaseFirestore.instance
          .collection('admissions')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'pending_acceptance')
          .where('isActive', isEqualTo: true)
          .get();

      int pendingAdmissionsCount = pendingAdmissionsQuery.docs.length;

      if (mounted) {
        setState(() {
          _totalPatients = totalPatients;
          _inPatients = inPatientsCount;
          _pendingConsultations = pendingCount;
          _completedToday = completedToday;
          _pendingAdmissions = pendingAdmissionsCount;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
      print('Error loading nursing dashboard stats: $e');
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.facilityName} - Nursing'),
        backgroundColor: Colors.pink.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI Assistant - Diagnosis & Vital Signs Support',
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
            icon: const Icon(Icons.settings),
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
      body: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    colors: [Colors.pink.shade700, Colors.pink.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.shade200,
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
                        Icon(
                          Icons.local_hospital,
                          size: 32,
                          color: Colors.white,
                        ),
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
                                'Nursing Department',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.pink.shade100,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Manage patient care, vital signs, medications, and nursing procedures.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.pink.shade100,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Main Dashboard Actions
              Text(
                'Nursing Services',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              _buildDashboardList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardList() {
    final items = [
      {
        'title': 'Pending Admissions',
        'subtitle': _pendingAdmissions > 0
            ? '$_pendingAdmissions admission${_pendingAdmissions == 1 ? '' : 's'} awaiting approval'
            : 'No pending admissions',
        'icon': Icons.pending_actions,
        'color': Colors.orange,
        'onTap': () => _navigateToPendingAdmissions(),
        'badge': _pendingAdmissions,
      },
      {
        'title': 'Patient Records',
        'subtitle': 'View patient medical records',
        'icon': Icons.folder_open,
        'color': Colors.blue,
        'onTap': () => _navigateToPatientRecords(),
      },
      {
        'title': 'Out-Patient',
        'subtitle': 'Approved out-patient consultations',
        'icon': Icons.groups,
        'color': Colors.indigo,
        'onTap': () => _navigateToOutPatient(),
      },
      {
        'title': 'Ward Management',
        'subtitle': 'Manage patient wards',
        'icon': Icons.local_hotel,
        'color': Colors.teal,
        'onTap': () => _navigateToWardManagement(),
      },
      {
        'title': 'Reports',
        'subtitle': 'View statistics and reports',
        'icon': Icons.assessment,
        'color': Colors.indigo,
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
            badge: item['badge'] as int?,
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
    int? badge,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _navigateToReports() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.pink.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assessment, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Nursing Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Statistics List
            Expanded(
              child: _loadingStats
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildReportCard(
                          'Total Patients',
                          _totalPatients.toString(),
                          Icons.people,
                          Colors.blue,
                          'All registered patients in facility',
                        ),
                        const SizedBox(height: 12),
                        _buildReportCard(
                          'In-Patients',
                          _inPatients.toString(),
                          Icons.hotel,
                          Colors.orange,
                          'Currently admitted patients',
                        ),
                        const SizedBox(height: 12),
                        _buildReportCard(
                          'Pending Care',
                          _pendingConsultations.toString(),
                          Icons.pending_actions,
                          Colors.purple,
                          'Patients waiting for care',
                        ),
                        const SizedBox(height: 12),
                        _buildReportCard(
                          'Completed Today',
                          _completedToday.toString(),
                          Icons.check_circle,
                          Colors.green,
                          'Consultations completed today',
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPendingAdmissions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NursingPendingAdmissionsScreen(
          facilityId: widget.facilityId,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    ).then((_) => _loadDashboardStats());
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

  void _navigateToOutPatient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityOutpatientScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          isNursingView:
              true, // Mark as nursing view to disable OPD-only actions
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
          wardId: null,
        ),
      ),
    ).then((_) => _loadDashboardStats());
  }
}
