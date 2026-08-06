import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OPDReportsAnalyticsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String doctorId;
  final String doctorName;

  const OPDReportsAnalyticsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<OPDReportsAnalyticsScreen> createState() =>
      _OPDReportsAnalyticsScreenState();
}

class _OPDReportsAnalyticsScreenState extends State<OPDReportsAnalyticsScreen> {
  int _totalAppointments = 0;
  int _approvedAppointments = 0;
  int _inPatients = 0;
  int _completedConsultations = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _loading = true);

    try {
      // Load total appointments
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('department', isEqualTo: 'Out-Patient Department (OPD)')
          .get();

      int totalAppts = appointmentsQuery.docs.length;
      int approvedAppts = appointmentsQuery.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .length;

      // Load in-patients
      final inPatientsQuery = await FirebaseFirestore.instance
          .collection('inpatients')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'admitted')
          .get();

      int inPatientsCount = inPatientsQuery.docs.length;

      // Load completed consultations
      final consultationsQuery = await FirebaseFirestore.instance
          .collection('health_records')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('recordType', isEqualTo: 'consultation')
          .where('status', isEqualTo: 'completed')
          .get();

      int completedCount = consultationsQuery.docs.length;

      if (mounted) {
        setState(() {
          _totalAppointments = totalAppts;
          _approvedAppointments = approvedAppts;
          _inPatients = inPatientsCount;
          _completedConsultations = completedCount;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      print('Error loading OPD statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade700,
                            Colors.indigo.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics,
                                size: 32,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'OPD Reports & Analytics',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      widget.facilityName,
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Department Statistics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Statistics Cards
                    _buildStatCard(
                      'Total Appointments',
                      _totalAppointments.toString(),
                      Icons.calendar_today,
                      Colors.blue,
                      'All appointments booked for OPD',
                    ),

                    const SizedBox(height: 12),

                    _buildStatCard(
                      'Approved Appointments',
                      _approvedAppointments.toString(),
                      Icons.check_circle,
                      Colors.green,
                      'Appointments approved and waiting',
                    ),

                    const SizedBox(height: 12),

                    _buildStatCard(
                      'In-Patients',
                      _inPatients.toString(),
                      Icons.hotel,
                      Colors.orange,
                      'Currently admitted patients',
                    ),

                    const SizedBox(height: 12),

                    _buildStatCard(
                      'Completed Consultations',
                      _completedConsultations.toString(),
                      Icons.assignment_turned_in,
                      Colors.purple,
                      'Consultations with notes saved',
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
