import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OPDAppointmentsScreen extends StatelessWidget {
  final String facilityId;

  const OPDAppointmentsScreen({super.key, required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OPD Appointments'),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OPDAppointmentsList(facilityId: facilityId, status: 'pending'),
            _OPDAppointmentsList(facilityId: facilityId, status: 'approved'),
          ],
        ),
      ),
    );
  }
}

class _OPDAppointmentsList extends StatelessWidget {
  final String facilityId;
  final String status;

  const _OPDAppointmentsList({required this.facilityId, required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: facilityId)
          .where('department', isEqualTo: 'Out-Patient Department (OPD)')
          .where('status', isEqualTo: status)
          .snapshots(), // Removed orderBy to avoid index requirement
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading appointments',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Sort appointments in-memory by createdAt (newest first)
        final allAppointments = snapshot.data?.docs ?? [];
        final appointments = List<QueryDocumentSnapshot>.from(allAppointments);
        appointments.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreatedAt = aData['createdAt'] ?? aData['created_at'];
          final bCreatedAt = bData['createdAt'] ?? bData['created_at'];

          if (aCreatedAt == null && bCreatedAt == null) return 0;
          if (aCreatedAt == null) return 1;
          if (bCreatedAt == null) return -1;

          if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
            return bCreatedAt.compareTo(aCreatedAt); // Descending order
          }
          return 0;
        });

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending'
                      ? Icons.pending_actions
                      : Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? 'No Pending Appointments'
                      : 'No Approved Appointments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'pending'
                      ? 'New appointment requests will appear here'
                      : 'Approved appointments will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // The StreamBuilder will automatically refresh
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final doc = appointments[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildAppointmentCard(context, doc, data, index + 1);
            },
          ),
        );
      },
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    int displayIndex,
  ) {
    // If approved, show simplified view with only name, age, and View button
    if (status == 'approved') {
      return _buildApprovedAppointmentCard(context, doc, data, displayIndex);
    }

    // For pending appointments, show full details
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final doctorName = data['doctorName'] ?? 'Unknown Doctor';
    final appointmentDate = data['appointmentDate'];
    final appointmentTime = data['appointmentTime'] ?? '';
    final reasonForVisit =
        data['reason'] ?? data['reasonForVisit'] ?? 'No reason specified';
    final createdAt =
        data['createdAt'] ?? data['created_at']; // Support both field names

    // Format dates
    String dateStr = 'Not specified';
    if (appointmentDate != null) {
      if (appointmentDate is Timestamp) {
        dateStr = DateFormat('MMM dd, yyyy').format(appointmentDate.toDate());
      } else if (appointmentDate is String) {
        try {
          final parsedDate = DateTime.parse(appointmentDate);
          dateStr = DateFormat('MMM dd, yyyy').format(parsedDate);
        } catch (e) {
          dateStr = appointmentDate;
        }
      }
    }

    String createdAtStr = 'Unknown';
    if (createdAt != null && createdAt is Timestamp) {
      createdAtStr = DateFormat(
        'MMM dd, yyyy hh:mm a',
      ).format(createdAt.toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Name Header
            Row(
              children: [
                // Index Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$displayIndex',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.person, color: Colors.teal, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'pending'
                        ? Colors.orange.shade100
                        : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'pending' ? 'PENDING' : 'APPROVED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: status == 'pending'
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Doctor Info
            _buildInfoRow(
              icon: Icons.medical_services,
              label: 'Doctor',
              value: doctorName,
            ),
            const SizedBox(height: 12),

            // Appointment Date & Time
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value:
                  '$dateStr ${appointmentTime.isNotEmpty ? '($appointmentTime)' : ''}',
            ),
            const SizedBox(height: 12),

            // Reason for Visit
            _buildInfoRow(
              icon: Icons.medical_information,
              label: 'Reason',
              value: reasonForVisit,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Request Time
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Requested',
              value: createdAtStr,
            ),

            // Action Buttons (only for pending appointments)
            if (status == 'pending') ...[
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
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Review appointment details before approving or rejecting.',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await _handleApprove(context, doc, data);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await _handleReject(context, doc, data);
                      },
                    ),
                  ),
                ],
              ),
            ],

            // Show rejection reason if denied
            if (status == 'denied' && data['denialReason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejection Reason:',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['denialReason'],
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Simplified card for approved appointments - shows only name, age, and View button
  Widget _buildApprovedAppointmentCard(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    int displayIndex,
  ) {
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final dateOfBirth = data['dateOfBirth'] ?? data['patientDateOfBirth'];

    // Calculate age from date of birth
    String ageStr = 'N/A';
    if (dateOfBirth != null) {
      DateTime? birthDate;
      if (dateOfBirth is Timestamp) {
        birthDate = dateOfBirth.toDate();
      } else if (dateOfBirth is String) {
        try {
          birthDate = DateTime.parse(dateOfBirth);
        } catch (e) {
          // If parsing fails, leave as N/A
        }
      }

      if (birthDate != null) {
        final age = DateTime.now().year - birthDate.year;
        final hasHadBirthdayThisYear =
            DateTime.now().month > birthDate.month ||
            (DateTime.now().month == birthDate.month &&
                DateTime.now().day >= birthDate.day);
        ageStr = '${hasHadBirthdayThisYear ? age : age - 1} years';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Index Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$displayIndex',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),

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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: $ageStr',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // View Button
            ElevatedButton.icon(
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _showAppointmentDetailsDialog(context, data);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Show detailed appointment information in a dialog
  void _showAppointmentDetailsDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final doctorName = data['doctorName'] ?? 'Unknown Doctor';
    final appointmentDate = data['appointmentDate'];
    final appointmentTime = data['appointmentTime'] ?? '';
    final reasonForVisit =
        data['reason'] ?? data['reasonForVisit'] ?? 'No reason specified';
    final dateOfBirth = data['dateOfBirth'] ?? data['patientDateOfBirth'];
    final patientPhone = data['patientPhone'] ?? data['phone'] ?? 'N/A';

    // Format appointment date
    String dateStr = 'Not specified';
    if (appointmentDate != null) {
      if (appointmentDate is Timestamp) {
        dateStr = DateFormat('MMM dd, yyyy').format(appointmentDate.toDate());
      } else if (appointmentDate is String) {
        try {
          final parsedDate = DateTime.parse(appointmentDate);
          dateStr = DateFormat('MMM dd, yyyy').format(parsedDate);
        } catch (e) {
          dateStr = appointmentDate;
        }
      }
    }

    // Calculate age
    String ageStr = 'N/A';
    if (dateOfBirth != null) {
      DateTime? birthDate;
      if (dateOfBirth is Timestamp) {
        birthDate = dateOfBirth.toDate();
      } else if (dateOfBirth is String) {
        try {
          birthDate = DateTime.parse(dateOfBirth);
        } catch (e) {
          // If parsing fails, leave as N/A
        }
      }

      if (birthDate != null) {
        final age = DateTime.now().year - birthDate.year;
        final hasHadBirthdayThisYear =
            DateTime.now().month > birthDate.month ||
            (DateTime.now().month == birthDate.month &&
                DateTime.now().day >= birthDate.day);
        ageStr = '${hasHadBirthdayThisYear ? age : age - 1} years';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Patient Name', patientName),
              _buildDetailRow('Age', ageStr),
              _buildDetailRow('Phone', patientPhone),
              const Divider(height: 24),
              _buildDetailRow('Doctor', doctorName),
              _buildDetailRow('Appointment Date', dateStr),
              _buildDetailRow(
                'Time',
                appointmentTime.isNotEmpty ? appointmentTime : 'Not specified',
              ),
              const Divider(height: 24),
              _buildDetailRow('Reason for Visit', reasonForVisit),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appointment Approved',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: Text(
          'Are you sure you want to approve this appointment for ${data['patientName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Update appointment status
      await doc.reference.update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'OPD Staff',
      });

      // Try to send notification to patient (don't fail if this errors)
      try {
        final patientId = data['patientId'] ?? data['patientUid'];
        if (patientId != null) {
          await _sendPatientMessage(
            patientId: patientId,
            patientName: data['patientName'] ?? 'Patient',
            content:
                'Your OPD appointment request has been approved. Please arrive on time for your scheduled appointment.',
          );
        }
      } catch (messageError) {
        // Continue anyway - approval is more important than notification
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) async {
    String? reason = await _showRejectReasonDialog(context);

    if (reason == null || reason.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rejection reason is required'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Update appointment status
      await doc.reference.update({
        'status': 'denied',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'OPD Staff',
        'denialReason': reason.trim(),
      });

      // Try to send notifications (don't fail if these error)
      try {
        await _sendMedicalRecordsMessage(
          facilityId: facilityId,
          patientName: data['patientName'] ?? 'Unknown Patient',
          appointmentId: doc.id,
          reason: reason.trim(),
        );
      } catch (messageError) {}

      try {
        final patientId = data['patientId'] ?? data['patientUid'];
        if (patientId != null) {
          await _sendPatientMessage(
            patientId: patientId,
            patientName: data['patientName'] ?? 'Patient',
            content:
                'Your OPD appointment request was rejected. Reason: ${reason.trim()}',
          );
        }
      } catch (messageError) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectReasonDialog(BuildContext context) async {
    final reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reason for Rejection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please provide a reason for rejecting this appointment:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter reason for rejection...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Medical Records will be notified',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                Navigator.of(context).pop(reason);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject Appointment'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendMedicalRecordsMessage({
    required String facilityId,
    required String patientName,
    required String appointmentId,
    required String reason,
  }) async {
    try {
      // Send message to Medical Records department
      await FirebaseFirestore.instance.collection('facility_messages').add({
        'facilityId': facilityId,
        'department': 'Medical Records',
        'fromDepartment': 'OPD',
        'subject': 'Appointment Rejected: $patientName',
        'message':
            'An OPD appointment for $patientName has been rejected.\n\nReason: $reason\n\nAppointment ID: $appointmentId',
        'appointmentId': appointmentId,
        'patientName': patientName,
        'type': 'appointment_rejection',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  Future<void> _sendPatientMessage({
    required String patientId,
    required String patientName,
    required String content,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('patient_notifications').add({
        'patientId': patientId,
        'patientName': patientName,
        'title': 'OPD Appointment Update',
        'message': content,
        'type': 'appointment',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }
}
