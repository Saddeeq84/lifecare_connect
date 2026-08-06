import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'ward_dashboard_screen.dart';
import 'medical_records_patient_records_screen.dart';
import 'specialist_appointments_screen.dart';
import 'specialist_patient_management_screen.dart';
import 'specialist_referrals_screen.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import '../widgets/staff_password_change_dialog.dart';

class SpecialistDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String doctorId;
  final String doctorName;

  const SpecialistDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<SpecialistDashboardScreen> createState() =>
      _SpecialistDashboardScreenState();
}

class _SpecialistDashboardScreenState extends State<SpecialistDashboardScreen> {
  int _totalAppointments = 0;
  int _approvedAppointments = 0;
  bool _loadingStats = true;

  // Specialist departments that should route here
  final List<String> _specialistDepartments = [
    'emergency',
    'pediatrics',
    'obstetrics',
    'cardiology',
    'neurology',
    'surgery',
    'orthopedic',
    'dermatology',
    'ophthalmology',
    'ENT',
    'dental',
    'physiotherapy',
    'mental health',
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      // Load specialist appointments statistics
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('department', whereIn: _specialistDepartments)
          .get();

      int totalAppts = appointmentsQuery.docs.length;
      int approvedAppts = appointmentsQuery.docs
          .where((doc) => (doc.data())['status'] == 'approved')
          .length;

      if (mounted) {
        setState(() {
          _totalAppointments = totalAppts;
          _approvedAppointments = approvedAppts;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
      print('Error loading specialist dashboard stats: $e');
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
        title: Text('${widget.facilityName} - Specialist'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI Assistant - Specialist Diagnosis Support',
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
            tooltip: 'Profile & Settings',
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
              // Welcome header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to Specialist Department',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage specialized medical services and consultations',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Specialized Care Services',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Dashboard Navigation Section
              Text(
                'Specialist Services',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              _buildDashboardGrid(),

              const SizedBox(height: 32),

              // Statistics Section
              Text(
                'Department Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),

              _loadingStats ? _buildLoadingStats() : _buildStatisticsGrid(),
            ],
          ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Specialist Appointments',
          _totalAppointments.toString(),
          Icons.medical_services,
          Colors.teal,
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Approved Appointments',
          _approvedAppointments.toString(),
          Icons.check_circle,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    final items = [
      {
        'title': 'Specialist Appointments',
        'subtitle': 'Manage specialist appointments',
        'icon': Icons.medical_services,
        'color': Colors.teal,
        'onTap': () => _navigateToSpecialistAppointments(),
      },
      {
        'title': 'OPD Referrals',
        'subtitle': 'Manage referrals from OPD',
        'icon': Icons.send,
        'color': Colors.deepPurple,
        'onTap': () => _navigateToReferrals(),
      },
      {
        'title': 'Patient Management',
        'subtitle': 'Manage in-patients and out-patients',
        'icon': Icons.groups,
        'color': Colors.indigo,
        'onTap': () => _navigateToPatientManagement(),
      },
      {
        'title': 'Patient Records',
        'subtitle': 'View patient medical records',
        'icon': Icons.folder_open,
        'color': Colors.blue,
        'onTap': () => _navigateToPatientRecords(),
      },
      {
        'title': 'Ward Management',
        'subtitle': 'Manage in-patient wards',
        'icon': Icons.local_hotel,
        'color': Colors.orange,
        'onTap': () => _navigateToWardManagement(),
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

  void _navigateToSpecialistAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistAppointmentsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          specialistId: widget.doctorId,
          specialistName: widget.doctorName,
        ),
      ),
    );
  }

  void _navigateToPatientManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistPatientManagementScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          specialistId: widget.doctorId,
          specialistName: widget.doctorName,
        ),
      ),
    );
  }

  void _navigateToReferrals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialistReferralsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          specialistId: widget.doctorId,
          specialistName: widget.doctorName,
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

  void _navigateToWardManagement() {
    // Navigate to ward management screen (view-only for specialists)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WardDashboardScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          staffId: widget.doctorId,
          staffName: widget.doctorName,
          wardId: null,
          isFromOPD: true, // View-only mode for specialists
        ),
      ),
    );
  }
}
