import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorAppointmentsTabView extends StatelessWidget {
  final String userId;
  const DoctorAppointmentsTabView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending Approval'),
              Tab(text: 'Approved Appointments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DoctorAppointmentsList(userId: userId, status: 'pending'),

            DoctorAppointmentsList(userId: userId, status: 'approved'),
          ],
        ),
      ),
    );
  }
}

class DoctorAppointmentsList extends StatelessWidget {
  final String userId;
  final String status;
  const DoctorAppointmentsList({
    super.key,
    required this.userId,
    required this.status,
  });

  void _showPreConsultationDetails(
    BuildContext context,
    Map<String, dynamic> checklistData,
  ) {
    // Support both top-level and nested (healthAssessment/data) structures
    Map<String, dynamic> data = checklistData;
    if (data.containsKey('healthAssessment') &&
        data['healthAssessment'] is Map<String, dynamic>) {
      data = {...data, ...data['healthAssessment']};
    } else if (data.containsKey('data') &&
        data['data'] is Map<String, dynamic>) {
      data = {...data, ...data['data']};
      if (data.containsKey('healthAssessment') &&
          data['healthAssessment'] is Map<String, dynamic>) {
        data = {...data, ...data['healthAssessment']};
      }
    }

    final fields = <String, String?>{
      'Appointment Type': data['appointmentType'] ?? data['type'],
      'Appointment Date': data['appointmentDate'] != null
          ? (data['appointmentDate'] is String
                ? data['appointmentDate']
                : (data['appointmentDate'] is DateTime
                      ? (data['appointmentDate'] as DateTime)
                            .toLocal()
                            .toString()
                      : data['appointmentDate'].toString()))
          : null,
      'Consultation Method': data['consultationChannel'] ?? data['channel'],
      'Main Complaint': data['mainComplaint'] ?? data['reason'],
      'Symptoms': data['symptoms'],
      'Duration': data['duration'],
      'Severity': data['severity'],
      'Current Medications':
          data['medications'] ??
          data['currentMedications'] ??
          data['medicationsTaken'],
      'Allergies': data['allergies'],
      'Medical History': data['medicalHistory'],
      'Additional Notes': data['additionalNotes'] ?? data['notes'],
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pre-Consultation Checklist'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: fields.entries
                  .where(
                    (entry) =>
                        entry.value != null &&
                        entry.value.toString().trim().isNotEmpty,
                  )
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              '${entry.key}:',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                          Expanded(child: Text(entry.value!)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    DocumentSnapshot appointmentDoc,
  ) async {
    final data = appointmentDoc.data() as Map<String, dynamic>;
    try {
      await appointmentDoc.reference.update(<String, dynamic>{
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': userId,
      });

      final consultationsCollection = FirebaseFirestore.instance.collection(
        'consultations',
      );
      await consultationsCollection.add({
        'appointmentId': appointmentDoc.id,
        'patientUid': data['patientUid'],
        'patientName': data['patientName'] ?? 'Patient',
        'providerId': userId,
        'providerName': data['providerName'] ?? 'Doctor',
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'type': data['type'] ?? 'general',
        'reason': data['reason'] ?? '',
      });

      await _sendPatientMessage(
        patientId: data['patientUid'],
        patientName: data['patientName'] ?? 'Patient',
        content:
            'Your appointment request has been approved by the doctor. Please check your app for details.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment approved and patient notified.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve appointment: $e')),
      );
    }
  }

  Future<void> _handleDeny(
    BuildContext context,
    DocumentSnapshot appointmentDoc,
  ) async {
    final data = appointmentDoc.data() as Map<String, dynamic>;
    String? reason = await _showDenyReasonDialog(context);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await appointmentDoc.reference.update(<String, dynamic>{
        'status': 'denied',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': userId,
        'denialReason': reason.trim(),
      });
      await _sendPatientMessage(
        patientId: data['patientUid'],
        patientName: data['patientName'] ?? 'Patient',
        content:
            'Your appointment request was denied by the doctor. Reason: $reason',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment denied and patient notified.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to deny appointment: $e')));
    }
  }

  Future<String?> _showDenyReasonDialog(BuildContext context) async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reason for Denial'),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            onChanged: (val) => reason = val,
            decoration: const InputDecoration(
              hintText: 'Enter reason for denial...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reason.trim().isNotEmpty) {
                  Navigator.of(context).pop(reason.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a reason for denial'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Deny'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendPatientMessage({
    required String patientId,
    required String patientName,
    required String content,
  }) async {
    final messagesCollection = FirebaseFirestore.instance.collection(
      'messages',
    );
    final docRef = messagesCollection.doc();
    await docRef.set({
      'conversationId': patientId,
      'senderId': userId,
      'senderName': 'Doctor',
      'senderRole': 'doctor',
      'receiverId': patientId,
      'receiverName': patientName,
      'receiverRole': 'patient',
      'content': content,
      'type': 'appointment_notification',
      'priority': 'high',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final appointmentStream = FirebaseFirestore.instance
        .collection('appointments')
        .where('providerId', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: appointmentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: \\${snapshot.error}"));
        }
        final appointments = snapshot.data?.docs ?? [];
        if (appointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No appointments found'),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final data = appointments[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['patientName'] ?? 'Unknown Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['reason'] != null &&
                        data['reason'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['reason'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('health_records')
                          .where('patientUid', isEqualTo: data['patientUid'])
                          .where('type', isEqualTo: 'pre_consultation')
                          .orderBy('date', descending: true)
                          .limit(1)
                          .snapshots(),
                      builder: (context, checklistSnapshot) {
                        if (checklistSnapshot.hasData &&
                            checklistSnapshot.data!.docs.isNotEmpty) {
                          final checklistDoc =
                              checklistSnapshot.data!.docs.first;
                          final checklistData =
                              checklistDoc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.assignment,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pre-Consultation Checklist Available',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Patient has submitted pre-consultation information. Review it before making a decision.',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text(
                                    'Review Checklist',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () => _showPreConsultationDetails(
                                    context,
                                    checklistData,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please review the patient\'s pre-consultation checklist (if submitted) before approving or declining this appointment.',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (status == 'pending')
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () async {
                              await _handleApprove(
                                context,
                                appointments[index],
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('Deny'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              await _handleDeny(context, appointments[index]);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
