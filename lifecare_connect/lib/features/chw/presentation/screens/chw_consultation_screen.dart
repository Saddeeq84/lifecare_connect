import '../../../consultation/presentation/screens/consultation_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../utils/web_open_call_page_stub.dart'
  if (dart.library.html) '../../../../utils/web_open_call_page_web.dart';
// ignore_for_file: prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'chw_anc_pnc_consultation_screen.dart';
import './chw_create_referral_screen.dart';
import 'chw_consultation_details_screen.dart';

import 'package:lifecare_connect/features/shared/data/services/message_service.dart';

// Confirmation dialog for mobile call
void _showCallConfirmationDialog(BuildContext context, VoidCallback onContinue, {required bool isVideo}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Join Consultation'),
      content: Text('Do you want to continue to the ${isVideo ? 'video' : 'audio'} call?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onContinue();
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

class CHWConsultationScreen extends StatelessWidget {
  // Use dynamic channel names for production (e.g., based on patient or appointment)
  const CHWConsultationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chwUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CHW Consultations'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending Consultations'),
              Tab(text: 'Completed Consultations'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pending Consultations Tab
            _buildPendingConsultations(context, chwUid),
            // Completed Consultations Tab
            _buildCompletedConsultations(context, chwUid),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingConsultations(BuildContext context, String chwUid) {
    // Show consultations with status 'pending' and all approved appointments
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: chwUid)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        final appointments = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final doc = appointments[index];
            final data = doc.data() as Map<String, dynamic>;
            final appointmentType = data['appointmentType'] ?? '';
            final patientId = data['patientId'] ?? '';
            final patientName = data['patientName'] ?? 'Unknown Patient';
            final appointmentId = doc.id;
            final preConsultationData = data['preConsultationData'] as Map<String, dynamic>?;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patientName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 4),
                    Text('Appointment Type: ${appointmentType?.toUpperCase() ?? 'Unknown'}', style: TextStyle(fontSize: 15)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Icon(Icons.visibility, color: Colors.teal),
                          tooltip: 'View Detail',
                          onPressed: () {
                            if (preConsultationData != null && preConsultationData.isNotEmpty) {
                              // Use same logic as doctor to extract fields from nested structures
                              Map<String, dynamic> data = preConsultationData;
                              if (data.containsKey('healthAssessment') && data['healthAssessment'] is Map<String, dynamic>) {
                                data = {...data, ...data['healthAssessment']};
                              } else if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
                                data = {...data, ...data['data']};
                                if (data.containsKey('healthAssessment') && data['healthAssessment'] is Map<String, dynamic>) {
                                  data = {...data, ...data['healthAssessment']};
                                }
                              }

                              final fields = <String, String?>{
                                'Appointment Type': data['appointmentType'] ?? data['type'],
                                'Appointment Date': data['appointmentDate'] != null
                                    ? (data['appointmentDate'] is String
                                        ? data['appointmentDate']
                                        : (data['appointmentDate'] is DateTime
                                            ? (data['appointmentDate'] as DateTime).toLocal().toString()
                                            : data['appointmentDate'].toString()))
                                    : null,
                                'Consultation Method': data['consultationChannel'] ?? data['channel'],
                                'Main Complaint': data['mainComplaint'] ?? data['reason'],
                                'Symptoms': data['symptoms'],
                                'Duration': data['duration'],
                                'Severity': data['severity'],
                                'Current Medications': data['medications'] ?? data['currentMedications'] ?? data['medicationsTaken'],
                                'Allergies': data['allergies'],
                                'Medical History': data['medicalHistory'],
                                'Additional Notes': data['additionalNotes'] ?? data['notes'],
                              };

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('Pre-Consultation Checklist'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: fields.entries
                                            .where((entry) => entry.value != null && entry.value.toString().trim().isNotEmpty)
                                            .map((entry) => Padding(
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
                                                      Expanded(
                                                        child: Text(entry.value!),
                                                      ),
                                                    ],
                                                  ),
                                                ))
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
                            } else {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Pre-Consultation Checklist'),
                                  content: Text('No checklist data available.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.note_add, color: Colors.orange),
                          tooltip: 'Add Note',
                          onPressed: () {
                            String preType = '';
                            if (preConsultationData != null && preConsultationData['appointmentType'] != null) {
                              preType = preConsultationData['appointmentType'].toString().toLowerCase();
                            } else {
                              preType = appointmentType.toString().toLowerCase();
                            }
                            if (preType.contains('anc') || preType.contains('pnc')) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CHWAncPncConsultationScreen(
                                    appointmentId: appointmentId,
                                    patientId: patientId,
                                    patientName: patientName,
                                    appointmentType: preType,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CHWConsultationDetailsScreen(
                                    appointmentId: appointmentId,
                                    patientId: patientId,
                                    patientName: patientName,
                                    appointmentData: data,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.chat, color: Colors.blue),
                          tooltip: 'Chat',
                          onPressed: () async {
                            final chwUid = FirebaseAuth.instance.currentUser?.uid;
                            if (chwUid == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('User not authenticated.')),
                              );
                              return;
                            }
                            // Import MessageService at the top if not already
                            final conversation = await MessageService.findOrCreateConversation(
                              userId: chwUid,
                              otherUserId: patientId,
                              otherUserName: patientName,
                            );
                            if (conversation == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not start conversation.')),
                              );
                              return;
                            }
                            GoRouter.of(context).go('/chw_dashboard/messages/chat/${conversation.id}', extra: {
                              'otherParticipantName': patientName,
                              'otherParticipantRole': 'PATIENT',
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.videocam, color: Colors.indigo),
                          tooltip: 'Video Call',
                          onPressed: () {
              final channelName = appointmentId.isNotEmpty
                ? appointmentId
                : patientId.isNotEmpty
                  ? patientId
                  : chwUid;
                            if (kIsWeb) {
                              openWebCallPage();
                            } else {
                              _showCallConfirmationDialog(
                                context,
                                () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ConsultationScreen(
                                        channelName: channelName,
                                        isVideo: true,
                                      ),
                                    ),
                                  );
                                },
                                isVideo: true,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.call, color: Colors.indigo),
                          tooltip: 'Audio Call',
                          onPressed: () {
              final channelName = appointmentId.isNotEmpty
                ? appointmentId
                : patientId.isNotEmpty
                  ? patientId
                  : chwUid;
                            if (kIsWeb) {
                              openWebCallPage();
                            } else {
                              _showCallConfirmationDialog(
                                context,
                                () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ConsultationScreen(
                                        channelName: channelName,
                                        isVideo: false,
                                      ),
                                    ),
                                  );
                                },
                                isVideo: false,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.assignment, color: Colors.purple),
                          tooltip: 'Make Referral',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CHWCreateReferralScreen(),
                              ),
                            );
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

  Widget _buildCompletedConsultations(BuildContext context, String chwUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('chwId', isEqualTo: chwUid)
          .where('statusFlag', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        final consultations = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: consultations.length,
          itemBuilder: (context, index) {
            final doc = consultations[index];
            final data = doc.data() as Map<String, dynamic>;
            final type = (data['type'] ?? '').toString().toUpperCase();
            final patientName = data['patientName'] ?? 'Unknown Patient';
            final date = data['date'] ?? data['createdAt'] ?? '';
            final provider = data['chwName'] ?? data['providerName'] ?? '';
            final notes = data['notes'] ?? 'No notes available.';
            final summaryWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Patient: $patientName', style: TextStyle(fontSize: 16)),
                SizedBox(height: 4),
                Text('Type: $type', style: TextStyle(fontSize: 16)),
                SizedBox(height: 4),
                Text('Date: ${date.toString()}', style: TextStyle(fontSize: 16)),
                if (provider.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text('Provider: $provider', style: TextStyle(fontSize: 16)),
                ],
                SizedBox(height: 8),
                Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(notes, style: TextStyle(fontSize: 15)),
              ],
            );
            return Card(
              color: Colors.blue.shade50,
              child: ListTile(
                title: Text(patientName),
                subtitle: Text(type.isNotEmpty ? '$type Consultation' : 'Completed Consultation'),
                trailing: ElevatedButton(
                  child: Text('View Details'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Consultation Summary'),
                        content: SingleChildScrollView(child: summaryWidget),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
