import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'facility_book_appointment_screen.dart';

class MedicalRecordsAppointmentsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const MedicalRecordsAppointmentsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<MedicalRecordsAppointmentsScreen> createState() =>
      _MedicalRecordsAppointmentsScreenState();
}

class _MedicalRecordsAppointmentsScreenState
    extends State<MedicalRecordsAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _facilityType;
  bool _isLoadingFacilityType = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFacilityType();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityType() async {
    try {
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.facilityId)
          .get();

      if (facilityDoc.exists && mounted) {
        setState(() {
          _facilityType = facilityDoc.data()?['type'] as String?;
          _isLoadingFacilityType = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFacilityType = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildApprovedTab(),
          _buildRejectedTab(),
        ],
      ),
      floatingActionButton: _isLoadingFacilityType
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FacilityBookAppointmentScreen(
                      facilityId: widget.facilityId,
                      facilityName: widget.facilityName,
                      facilityType: _facilityType,
                    ),
                  ),
                );
              },
              backgroundColor: Colors.orange.shade700,
              icon: const Icon(Icons.add),
              label: const Text('Book Appointment'),
            ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs ?? [];

        // Sort by createdAt in memory to avoid composite index requirement
        appointments.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending order
        });

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Pending Appointments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All pending appointments will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final docId = appointments[index].id;
            final appointment =
                appointments[index].data() as Map<String, dynamic>;
            return _buildAppointmentCard(
              context,
              appointment,
              index + 1,
              isApproved: false,
              isPending: true,
              docId: docId,
            );
          },
        );
      },
    );
  }

  Widget _buildApprovedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs ?? [];

        // Debug: Log approved appointments to check doctorType field
        print(
          '🔍 [MedicalRecords-Approved] Found ${appointments.length} approved appointments',
        );
        if (appointments.isNotEmpty) {
          for (var i = 0; i < appointments.length && i < 3; i++) {
            final data = appointments[i].data() as Map<String, dynamic>;
            print(
              '🔍 [Approved-$i] Patient: ${data['patientName']}, Doctor: ${data['doctorName']}, DoctorType: "${data['doctorType']}", BookedBy: "${data['bookedBy']}"',
            );
          }
        }

        // Sort by createdAt in memory to avoid composite index requirement
        appointments.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending order
        });

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Approved Appointments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All approved appointments will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment =
                appointments[index].data() as Map<String, dynamic>;
            return _buildAppointmentCard(
              context,
              appointment,
              index + 1,
              isApproved: true,
            );
          },
        );
      },
    );
  }

  Widget _buildRejectedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('status', isEqualTo: 'rejected')
          .orderBy('appointmentDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Rejected Appointments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All rejected appointments will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final docId = appointments[index].id;
            final appointment =
                appointments[index].data() as Map<String, dynamic>;
            return _buildAppointmentCard(
              context,
              appointment,
              index + 1,
              isApproved: false,
              docId: docId,
            );
          },
        );
      },
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    Map<String, dynamic> appointment,
    int displayIndex, {
    required bool isApproved,
    bool isPending = false,
    String? docId,
  }) {
    // Handle both Timestamp and String date formats
    DateTime? appointmentDate;
    final dateValue = appointment['appointmentDate'];
    if (dateValue is Timestamp) {
      appointmentDate = dateValue.toDate();
    } else if (dateValue is String) {
      appointmentDate = DateTime.tryParse(dateValue);
    }

    final patientId = appointment['patientId'] as String?;

    // Simplified card - just show essential info with a View button
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: FutureBuilder<DocumentSnapshot>(
        future: patientId != null
            ? FirebaseFirestore.instance
                  .collection('facility_patients')
                  .doc(patientId)
                  .get()
            : null,
        builder: (context, patientSnapshot) {
          String patientName = 'Unknown Patient';
          int? patientAge;

          if (patientSnapshot.hasData && patientSnapshot.data?.exists == true) {
            final patientData =
                patientSnapshot.data!.data() as Map<String, dynamic>?;
            patientName =
                patientData?['fullName'] ??
                patientData?['name'] ??
                'Unknown Patient';

            // Calculate age from dateOfBirth
            final dobValue = patientData?['dateOfBirth'];
            if (dobValue != null) {
              DateTime? dob;
              if (dobValue is Timestamp) {
                dob = dobValue.toDate();
              } else if (dobValue is String) {
                dob = DateTime.tryParse(dobValue);
              }
              if (dob != null) {
                patientAge = DateTime.now().year - dob.year;
                if (DateTime.now().month < dob.month ||
                    (DateTime.now().month == dob.month &&
                        DateTime.now().day < dob.day)) {
                  patientAge--;
                }
              }
            }
          }

          return InkWell(
            onTap: () => _showAppointmentDetails(
              context,
              appointment,
              patientName,
              patientAge,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Patient Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isPending
                        ? Colors.amber.shade100
                        : (isApproved
                              ? Colors.green.shade100
                              : Colors.red.shade100),
                    child: Text(
                      patientName.isNotEmpty
                          ? patientName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isPending
                            ? Colors.amber.shade700
                            : (isApproved
                                  ? Colors.green.shade700
                                  : Colors.red.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Patient Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (patientAge != null) ...[
                              Icon(
                                Icons.cake,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$patientAge years',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              appointmentDate != null
                                  ? '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}'
                                  : 'Not set',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPending
                                ? Colors.amber.shade50
                                : (isApproved
                                      ? Colors.green.shade50
                                      : Colors.red.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPending
                                  ? Colors.amber.shade300
                                  : (isApproved
                                        ? Colors.green.shade300
                                        : Colors.red.shade300),
                            ),
                          ),
                          child: Text(
                            isPending
                                ? 'PENDING'
                                : (isApproved ? 'APPROVED' : 'REJECTED'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPending
                                  ? Colors.amber.shade800
                                  : (isApproved
                                        ? Colors.green.shade800
                                        : Colors.red.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons - View and Cancel (for pending only)
                  if (isPending && docId != null)
                    Row(
                      children: [
                        // View button
                        InkWell(
                          onTap: () => _showAppointmentDetails(
                            context,
                            appointment,
                            patientName,
                            patientAge,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: Colors.teal.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Cancel button
                        InkWell(
                          onTap: () =>
                              _cancelAppointment(context, docId, patientName),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cancel,
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // View button only (for approved/rejected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.teal.shade700,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAppointmentDetails(
    BuildContext context,
    Map<String, dynamic> appointment,
    String patientName,
    int? patientAge,
  ) {
    // Handle both Timestamp and String date formats
    DateTime? appointmentDate;
    final dateValue = appointment['appointmentDate'];
    if (dateValue is Timestamp) {
      appointmentDate = dateValue.toDate();
    } else if (dateValue is String) {
      appointmentDate = DateTime.tryParse(dateValue);
    }

    final reason = appointment['reason'] as String? ?? 'No reason provided';
    final rejectionReason = appointment['rejectionReason'] as String?;
    final status = appointment['status'] as String? ?? 'unknown';
    final staffId = appointment['staffId'] as String?;
    final appointmentType =
        appointment['appointmentType'] as String? ?? 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.event,
                      color: Colors.teal.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Appointment Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'pending'
                                ? Colors.amber.shade100
                                : (status == 'approved'
                                      ? Colors.green.shade100
                                      : Colors.red.shade100),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: status == 'pending'
                                  ? Colors.amber.shade800
                                  : (status == 'approved'
                                        ? Colors.green.shade800
                                        : Colors.red.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Patient Information
              const Text(
                'Patient Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.person, 'Name', patientName, Colors.purple),
              if (patientAge != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.cake,
                  'Age',
                  '$patientAge years',
                  Colors.blue,
                ),
              ],

              const SizedBox(height: 24),

              // Appointment Information
              const Text(
                'Appointment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.medical_services,
                'Type',
                appointmentType,
                Colors.teal,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.calendar_today,
                'Date',
                appointmentDate != null
                    ? '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}'
                    : 'Not set',
                Colors.orange,
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.access_time,
                'Time',
                appointmentDate != null
                    ? '${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}'
                    : 'Not set',
                Colors.blue,
              ),
              if (staffId != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.badge,
                  'Booked by Staff',
                  staffId,
                  Colors.indigo,
                ),
              ],
              const SizedBox(height: 8),
              _buildDetailRow(Icons.note, 'Reason', reason, Colors.green),
              if (rejectionReason != null) ...[
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.warning,
                  'Rejection Reason',
                  rejectionReason,
                  Colors.red,
                ),
              ],

              if (status == 'pending') ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Waiting for approval from OPD/Specialist department',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancelAppointment(
    BuildContext context,
    String appointmentId,
    String patientName,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
          'Are you sure you want to cancel the appointment for $patientName?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the appointment from Firestore
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Appointment cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to cancel appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Medical Records staff don't approve/reject appointments
  // That's done by OPD/Specialist departments
}
