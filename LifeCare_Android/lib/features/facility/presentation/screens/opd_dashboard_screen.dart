import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'opd_patient_management_screen.dart';
import 'opd_referrals_screen.dart';
import 'ward_dashboard_screen.dart';
import 'opd_reports_analytics_screen.dart';
import 'opd_appointments_screen.dart';
import 'medical_records_patient_records_screen.dart';
import '../widgets/staff_password_change_dialog.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import '../../../shared/presentation/widgets/resource_popup_button.dart';

class OPDDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String doctorId;
  final String doctorName;

  const OPDDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<OPDDashboardScreen> createState() => _OPDDashboardScreenState();
}

class _OPDDashboardScreenState extends State<OPDDashboardScreen> {
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
    final facilityDisplayName = widget.facilityName.isEmpty
        ? 'Facility'
        : widget.facilityName;
    final doctorDisplayName = widget.doctorName.isEmpty
        ? 'Doctor'
        : widget.doctorName;

    return Scaffold(
      appBar: AppBar(
        title: Text('$facilityDisplayName - OPD'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          const ResourcePopupButton(assistantType: AIAssistantType.doctor),
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
                  colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.shade200,
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
                      Icon(Icons.local_hospital, size: 32, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, Dr. $doctorDisplayName',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Out-Patient Department',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.indigo.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 12),
                  Text(
                    'Manage appointments, patient care, ward operations, and medical records from this centralized dashboard.',
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
              'OPD Management',
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
      {
        'title': 'Appointments',
        'subtitle': 'Approve/reject appointments',
        'icon': Icons.event_available,
        'color': Colors.blue,
        'onTap': () => _navigateToAppointments(),
      },
      {
        'title': 'Patient Management',
        'subtitle': 'In-patient, out-patient & consultations',
        'icon': Icons.groups,
        'color': Colors.indigo,
        'onTap': () => _navigateToPatientManagement(),
      },
      {
        'title': 'Ward Management',
        'subtitle': 'Manage in-patient wards',
        'icon': Icons.local_hotel,
        'color': Colors.teal,
        'onTap': () => _navigateToWardManagement(),
      },
      {
        'title': 'Patient Records',
        'subtitle': 'View patient medical records',
        'icon': Icons.folder_open,
        'color': Colors.blue,
        'onTap': () => _navigateToPatientRecords(),
      },
      {
        'title': 'Referrals',
        'subtitle': 'Refer patients to specialists',
        'icon': Icons.send,
        'color': Colors.deepPurple,
        'onTap': () => _navigateToReferrals(),
      },
      {
        'title': 'Reports',
        'subtitle': 'View statistics and reports',
        'icon': Icons.analytics,
        'color': Colors.orange,
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

  void _navigateToReferrals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OPDReferralsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
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

  void _navigateToAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            OPDAppointmentsScreen(facilityId: widget.facilityId),
      ),
    );
  }

  void _navigateToPatientManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OPDPatientManagementScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
        ),
      ),
    );
  }

  void _navigateToReportsAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OPDReportsAnalyticsScreen(
          facilityId: widget.facilityId,
          facilityName: widget.facilityName,
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
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
          staffId: widget.doctorId,
          staffName: widget.doctorName,
          wardId: null, // null means access to all wards
          isFromOPD: true, // Mark as coming from OPD dashboard
        ),
      ),
    );
  }
}

// OPD Out-Patients Screen
// Shows patients currently receiving treatment at the OPD today
// These are patients who have approved appointments and are going through the treatment process
// Once all services are complete (consultation, vitals, labs, medication), they move to medical records
class OPDOutPatientsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String doctorId;
  final String doctorName;

  const OPDOutPatientsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<OPDOutPatientsScreen> createState() => _OPDOutPatientsScreenState();
}

class _OPDOutPatientsScreenState extends State<OPDOutPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getOutPatientsStream() {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('status', isEqualTo: 'approved')
        .orderBy('appointmentDate', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Out-Patients'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Approved Out-Patients',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Patients with approved appointments ready for consultation',
                  style: TextStyle(color: Colors.green.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search patients by name...',
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
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOutPatientsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading out-patients',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final patients = snapshot.data?.docs ?? [];

                // Filter patients based on search query
                final filteredPatients = patients.where((patient) {
                  final data = patient.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return _searchQuery.isEmpty ||
                      patientName.contains(_searchQuery);
                }).toList();

                if (filteredPatients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No patients found matching "$_searchQuery"'
                              : 'No approved out-patients found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patientDoc = filteredPatients[index];
                    final patient = patientDoc.data() as Map<String, dynamic>;

                    return _buildPatientCard(patient, patientDoc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient, String appointmentId) {
    final patientName = patient['patientName'] ?? 'Unknown Patient';
    final patientPhone = patient['patientPhone'] ?? 'N/A';
    final appointmentDate = patient['appointmentDate']?.toString() ?? 'N/A';
    final reasonForVisit = patient['reasonForVisit'] ?? 'Not specified';
    final patientAge = patient['patientAge']?.toString() ?? 'N/A';
    final patientGender = patient['patientGender'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$patientAge years, $patientGender',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'APPROVED',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildInfoRow('Phone', patientPhone),
            _buildInfoRow('Appointment Date', appointmentDate),
            _buildInfoRow('Reason', reasonForVisit),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewPatientHistory(patient),
                    icon: const Icon(Icons.history),
                    label: const Text('View History'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startConsultation(patient, appointmentId),
                    icon: const Icon(Icons.medical_services),
                    label: const Text('Consult'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _viewPatientHistory(Map<String, dynamic> patient) {
    // Show patient medical history
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${patient['patientName']} - Medical History'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Previous Consultations'),
              SizedBox(height: 8),
              Text(
                'This feature will show previous consultations and medical records.',
              ),
              SizedBox(height: 16),
              Text('Coming Soon: Complete medical history integration.'),
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

  void _startConsultation(Map<String, dynamic> patient, String appointmentId) {
    // Navigate to consultation screen or show consultation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Consultation'),
        content: Text(
          'Starting consultation with ${patient['patientName']}.\n\n'
          'This will create a health record and begin the consultation process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createConsultationRecord(patient, appointmentId);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _createConsultationRecord(
    Map<String, dynamic> patient,
    String appointmentId,
  ) async {
    try {
      // Update appointment status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'in-progress',
            'consultationStartedAt': FieldValue.serverTimestamp(),
            'consultingDoctor': widget.doctorName,
          });

      // Create health record
      await FirebaseFirestore.instance.collection('health_records').add({
        'patientId': patient['patientId'],
        'patientName': patient['patientName'],
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'appointmentId': appointmentId,
        'recordType': 'consultation',
        'status': 'in-progress',
        'createdAt': FieldValue.serverTimestamp(),
        'complaints': '',
        'diagnosis': '',
        'treatment': '',
        'prescriptions': [],
        'labTests': [],
        'followUp': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting consultation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// OPD Medical Records Screen
class OPDMedicalRecordsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String doctorId;
  final String doctorName;

  const OPDMedicalRecordsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<OPDMedicalRecordsScreen> createState() =>
      _OPDMedicalRecordsScreenState();
}

class _OPDMedicalRecordsScreenState extends State<OPDMedicalRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getMedicalRecordsStream() {
    return FirebaseFirestore.instance
        .collection('health_records')
        .where('facilityId', isEqualTo: widget.facilityId)
        .where('recordType', isEqualTo: 'consultation')
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_information,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Completed Consultations',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'View all completed consultations with saved consultation notes',
                  style: TextStyle(color: Colors.purple.shade600, fontSize: 14),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search records by patient name...',
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
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Records List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMedicalRecordsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading medical records',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final records = snapshot.data?.docs ?? [];

                // Filter records based on search query
                final filteredRecords = records.where((record) {
                  final data = record.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return _searchQuery.isEmpty ||
                      patientName.contains(_searchQuery);
                }).toList();

                if (filteredRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.medical_information_outlined,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No records found matching "$_searchQuery"'
                              : 'No completed consultations found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final recordDoc = filteredRecords[index];
                    final record = recordDoc.data() as Map<String, dynamic>;

                    return _buildRecordCard(record, recordDoc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, String recordId) {
    final patientName = record['patientName'] ?? 'Unknown Patient';
    final doctorName = record['doctorName'] ?? 'Unknown Doctor';
    final createdAt = (record['createdAt'] as Timestamp?)?.toDate();
    final diagnosis = record['diagnosis'] ?? 'No diagnosis recorded';
    final complaints = record['complaints'] ?? 'No complaints recorded';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewRecordDetails(record, recordId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Text(
                      patientName.isNotEmpty
                          ? patientName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Dr. $doctorName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: Colors.purple.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (createdAt != null)
                _buildInfoRow(
                  'Date',
                  '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                ),
              _buildInfoRow(
                'Diagnosis',
                diagnosis.length > 50
                    ? '${diagnosis.substring(0, 50)}...'
                    : diagnosis,
              ),
              _buildInfoRow(
                'Complaints',
                complaints.length > 50
                    ? '${complaints.substring(0, 50)}...'
                    : complaints,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    Icons.visibility,
                    size: 16,
                    color: Colors.purple.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view full record',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _viewRecordDetails(Map<String, dynamic> record, String recordId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${record['patientName']} - Medical Record'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Patient', record['patientName'] ?? 'N/A'),
                _buildDetailRow('Doctor', record['doctorName'] ?? 'N/A'),
                if (record['createdAt'] != null)
                  _buildDetailRow(
                    'Date',
                    '${(record['createdAt'] as Timestamp).toDate().day}/'
                        '${(record['createdAt'] as Timestamp).toDate().month}/'
                        '${(record['createdAt'] as Timestamp).toDate().year}',
                  ),
                const SizedBox(height: 16),

                const Text(
                  'Clinical Information:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Complaints',
                  record['complaints'] ?? 'No complaints recorded',
                ),
                _buildDetailRow(
                  'Diagnosis',
                  record['diagnosis'] ?? 'No diagnosis recorded',
                ),
                _buildDetailRow(
                  'Treatment',
                  record['treatment'] ?? 'No treatment recorded',
                ),

                if (record['prescriptions'] != null &&
                    (record['prescriptions'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Prescriptions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...(record['prescriptions'] as List).map(
                    (prescription) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Text('• $prescription'),
                    ),
                  ),
                ],

                if (record['labTests'] != null &&
                    (record['labTests'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Lab Tests:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  ...(record['labTests'] as List).map(
                    (test) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Text('• $test'),
                    ),
                  ),
                ],

                if (record['followUp'] != null &&
                    record['followUp'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow('Follow-up', record['followUp']),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _printRecord(record);
            },
            icon: const Icon(Icons.print),
            label: const Text('Print'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _printRecord(Map<String, dynamic> record) {
    // Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print functionality coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
