// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../consultation/presentation/screens/consultation_screen.dart';
import '../../../shared/presentation/screens/chat_screen.dart';
import '../../../shared/data/services/message_service.dart';

class FacilityRemoteConsultationsScreen extends StatefulWidget {
  final String? facilityId;
  final String? facilityName;

  const FacilityRemoteConsultationsScreen({
    super.key,
    this.facilityId,
    this.facilityName,
  });

  @override
  State<FacilityRemoteConsultationsScreen> createState() =>
      _FacilityRemoteConsultationsScreenState();
}

class _FacilityRemoteConsultationsScreenState
    extends State<FacilityRemoteConsultationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? facilityId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFacilityId();
  }

  Future<void> _loadFacilityId() async {
    // First check if facility data was passed as parameters
    if (widget.facilityId != null) {
      setState(() {
        facilityId = widget.facilityId;
        _isLoading = false;
      });
      print(
        '🏥 [FacilityRemoteConsultations] Using passed facilityId: $facilityId',
      );
      return;
    }

    // Fallback: Try to get from Firebase Auth user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        // Check if user is staff - get facilityId from staff data
        if (data?['userType'] == 'staff' || data?['role'] == 'staff') {
          setState(() {
            facilityId = data?['facilityId'] as String?;
            _isLoading = false;
          });
          print(
            '🏥 [FacilityRemoteConsultations] Staff facilityId: $facilityId',
          );
        } else {
          // Facility admin
          setState(() {
            facilityId = currentUser.uid;
            _isLoading = false;
          });
          print(
            '🏥 [FacilityRemoteConsultations] Facility admin facilityId: $facilityId',
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Consultations'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: _isLoading || facilityId == null
            ? null
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
                  Tab(text: 'Completed', icon: Icon(Icons.done_all)),
                ],
              ),
      ),
      body: _isLoading || facilityId == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _PendingConsultationsTab(facilityId: facilityId!),
                _CompletedConsultationsTab(facilityId: facilityId!),
              ],
            ),
    );
  }
}

// Pending Consultations Tab (Awaiting Remote Doctor Approval)
class _PendingConsultationsTab extends StatelessWidget {
  final String facilityId;

  const _PendingConsultationsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    print(
      '🔍 [FacilityRemoteConsultations-Pending] Querying for facilityId: $facilityId',
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: facilityId)
          .where('doctorType', isEqualTo: 'remote')
          .where('status', isEqualTo: 'approved')
          .orderBy('appointmentDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print(
            '❌ [FacilityRemoteConsultations-Pending] Error: ${snapshot.error}',
          );
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final appointments = snapshot.data?.docs ?? [];

        print(
          '📊 [FacilityRemoteConsultations-Pending] Found ${appointments.length} approved remote appointments',
        );
        print(
          '📊 [FacilityRemoteConsultations-Pending] Query: facilityId=$facilityId, doctorType=remote, status=approved',
        );

        // Debug: Check if there are ANY appointments for this facility with status=approved
        FirebaseFirestore.instance
            .collection('appointments')
            .where('facilityId', isEqualTo: facilityId)
            .where('status', isEqualTo: 'approved')
            .get()
            .then((allApproved) {
              print(
                '🔍 [Debug] Total approved appointments for facility: ${allApproved.docs.length}',
              );
              if (allApproved.docs.isNotEmpty) {
                final sample = allApproved.docs.first.data();
                print(
                  '🔍 [Debug] Sample approved appointment doctorType: "${sample['doctorType']}"',
                );
                print(
                  '🔍 [Debug] Sample approved appointment data: ${sample.keys.join(", ")}',
                );
              }
            });

        if (appointments.isNotEmpty) {
          print(
            '📋 [FacilityRemoteConsultations-Pending] First appointment data:',
          );
          final firstData = appointments[0].data() as Map<String, dynamic>;
          print('   - Patient: ${firstData['patientName']}');
          print('   - Doctor: ${firstData['doctorName']}');
          print('   - Status: ${firstData['status']}');
          print('   - DoctorType: ${firstData['doctorType']}');
          print('   - FacilityId: ${firstData['facilityId']}');
        }

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Pending Remote Consultations',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appointments awaiting remote doctor approval will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
            final doc = appointments[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildConsultationCard(context, doc.id, data, facilityId);
          },
        );
      },
    );
  }

  Widget _buildConsultationCard(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
    String facilityId,
  ) {
    final appointmentDate = data['appointmentDate'];
    final doctorName =
        data['assignedStaffName'] ?? data['doctorName'] ?? 'Unknown Doctor';
    final patientName = data['patientName'] ?? 'Unknown Patient';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PENDING',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.person, 'Doctor', doctorName),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.medical_services,
              'Department',
              data['department'] ?? 'N/A',
            ),
            const SizedBox(height: 8),
            if (appointmentDate != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Appointment Date',
                _formatAppointmentDate(appointmentDate),
              ),
            if (data['reason'] != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.note, 'Reason', data['reason']),
            ],
            const SizedBox(height: 16),
            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Video Call Button
                ElevatedButton.icon(
                  onPressed: () =>
                      _startVideoCall(context, appointmentId, data),
                  icon: const Icon(Icons.videocam, size: 18),
                  label: const Text('Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                // Audio Call Button
                ElevatedButton.icon(
                  onPressed: () =>
                      _startAudioCall(context, appointmentId, data),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Audio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
                // Chat Button
                ElevatedButton.icon(
                  onPressed: () => _openChat(context, appointmentId, data),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAppointmentDate(dynamic appointmentDate) {
    try {
      if (appointmentDate is Timestamp) {
        return DateFormat(
          'MMM dd, yyyy - hh:mm a',
        ).format(appointmentDate.toDate());
      } else if (appointmentDate is String) {
        final date = DateTime.parse(appointmentDate);
        return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _startVideoCall(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final channelName = 'appointment_$appointmentId';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start Video Consultation'),
        content: Text('Start video consultation with ${data['doctorName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsultationScreen(
                    channelName: channelName,
                    isVideo: true,
                    appointmentId: appointmentId,
                    otherParticipantId: data['doctorId'],
                    otherParticipantName: data['doctorName'] ?? 'Doctor',
                    otherParticipantRole: 'doctor',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Video Call'),
          ),
        ],
      ),
    );
  }

  void _startAudioCall(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final channelName = 'appointment_$appointmentId';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start Audio Consultation'),
        content: Text('Start audio consultation with ${data['doctorName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsultationScreen(
                    channelName: channelName,
                    isVideo: false,
                    appointmentId: appointmentId,
                    otherParticipantId: data['doctorId'],
                    otherParticipantName: data['doctorName'] ?? 'Doctor',
                    otherParticipantRole: 'doctor',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Audio Call'),
          ),
        ],
      ),
    );
  }

  void _openChat(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final currentUserName = userData['fullName'] ?? 'Facility Staff';
      final currentUserRole = userData['role'] ?? 'staff';

      // Create or get conversation
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: currentUser.uid,
        user1Name: currentUserName,
        user1Role: currentUserRole,
        user2Id: data['doctorId'],
        user2Name: data['doctorName'] ?? 'Doctor',
        user2Role: 'doctor',
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherParticipantName: data['doctorName'] ?? 'Doctor',
              otherParticipantRole: 'doctor',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Completed Consultations Tab (Consultation Note Saved)
class _CompletedConsultationsTab extends StatelessWidget {
  final String facilityId;

  const _CompletedConsultationsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: facilityId)
          .where('doctorType', isEqualTo: 'remote')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Completed Remote Consultations',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Completed consultations will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
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
            final doc = appointments[index];
            final data = doc.data() as Map<String, dynamic>;
            final consultationDate = data['consultationDate'] as Timestamp?;
            final doctorName = data['assignedStaffName'] ?? 'Unknown Doctor';
            final patientName = data['patientName'] ?? 'Unknown Patient';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.done_all, color: Colors.green.shade800),
                ),
                title: Text(
                  patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Doctor: $doctorName'),
                    Text('Department: ${data['department'] ?? 'N/A'}'),
                    if (consultationDate != null)
                      Text(
                        'Completed: ${DateFormat('MMM dd, yyyy - hh:mm a').format(consultationDate.toDate())}',
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.description,
                        color: Colors.blue.shade700,
                      ),
                      onPressed: () =>
                          _viewConsultationNote(context, doc.id, data),
                      tooltip: 'View Consultation Note',
                    ),
                    IconButton(
                      icon: Icon(Icons.print, color: Colors.purple.shade700),
                      onPressed: () =>
                          _printConsultationNote(context, doc.id, data),
                      tooltip: 'Print as PDF',
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

  void _viewConsultationNote(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Remote Consultation Notes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 32),
                _buildSection('Patient Information', [
                  _buildInfoRowForNote('Name', data['patientName']),
                  _buildInfoRowForNote('Patient ID', data['patientId']),
                ]),
                const SizedBox(height: 24),
                _buildSection('Doctor Information', [
                  _buildInfoRowForNote(
                    'Doctor',
                    data['assignedStaffName'] ?? data['doctorName'],
                  ),
                  _buildInfoRowForNote('Department', data['department']),
                ]),
                const SizedBox(height: 24),
                const Text(
                  'Consultation Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('health_records')
                      .where('appointmentId', isEqualTo: appointmentId)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No consultation notes found',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      );
                    }

                    final noteData =
                        snapshot.data!.docs.first.data()
                            as Map<String, dynamic>;

                    // Debug: Print all available fields
                    print(
                      '🔍 [ConsultationNote] Available fields: ${noteData.keys.join(", ")}',
                    );
                    print(
                      '🔍 [ConsultationNote] prescriptions (array): ${noteData['prescriptions']}',
                    );
                    print(
                      '🔍 [ConsultationNote] labRequests (array): ${noteData['labRequests']}',
                    );
                    print(
                      '🔍 [ConsultationNote] radiologyRequests (array): ${noteData['radiologyRequests']}',
                    );
                    print(
                      '🔍 [ConsultationNote] clinicalNotes: ${noteData['clinicalNotes']}',
                    );
                    print(
                      '🔍 [ConsultationNote] followUp: ${noteData['followUp']}',
                    );

                    // Map doctor's field names to display fields
                    final symptoms =
                        noteData['clinicalNotes']?.toString() ?? '';
                    final diagnosis = noteData['diagnosis']?.toString() ?? '';
                    final treatment = noteData['followUp']?.toString() ?? '';

                    // Convert arrays to strings
                    final prescriptionList =
                        (noteData['prescriptions'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [];
                    final prescription = prescriptionList.isNotEmpty
                        ? prescriptionList.join('\n• ')
                        : '';

                    final labTestsList =
                        (noteData['labRequests'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [];
                    final labTests = labTestsList.isNotEmpty
                        ? labTestsList.join('\n• ')
                        : '';

                    final radiologicalTestsList =
                        (noteData['radiologyRequests'] as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        [];
                    final radiologicalTests = radiologicalTestsList.isNotEmpty
                        ? radiologicalTestsList.join('\n• ')
                        : '';

                    final notes = noteData['notes']?.toString() ?? '';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vitals (not saved by doctor currently)
                        if (noteData['vitals'] != null &&
                            noteData['vitals'] is Map)
                          _buildVitalsCard(
                            noteData['vitals'] as Map<String, dynamic>,
                          ),
                        // Chief Complaint / Symptoms (clinicalNotes)
                        if (symptoms.isNotEmpty)
                          _buildNoteCard(
                            'Chief Complaint / Symptoms',
                            symptoms,
                            Icons.sick,
                          ),
                        // Diagnosis
                        if (diagnosis.isNotEmpty)
                          _buildNoteCard(
                            'Diagnosis',
                            diagnosis,
                            Icons.medical_services,
                          ),
                        // Treatment Plan (followUp)
                        if (treatment.isNotEmpty)
                          _buildNoteCard(
                            'Follow-up / Treatment Plan',
                            treatment,
                            Icons.healing,
                          ),
                        // Prescription (prescriptions array)
                        if (prescription.isNotEmpty)
                          _buildNoteCard(
                            'Prescription',
                            '• $prescription',
                            Icons.medication,
                          ),
                        // Lab Tests (labRequests array)
                        if (labTests.isNotEmpty)
                          _buildNoteCard(
                            'Lab Tests Requested',
                            '• $labTests',
                            Icons.biotech,
                          ),
                        // Radiological Tests (radiologyRequests array)
                        if (radiologicalTests.isNotEmpty)
                          _buildNoteCard(
                            'Radiology Requested',
                            '• $radiologicalTests',
                            Icons.scanner,
                          ),
                        // Additional Notes
                        if (notes.isNotEmpty)
                          _buildNoteCard('Additional Notes', notes, Icons.note),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRowForNote(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard(Map<String, dynamic> vitals) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.favorite, size: 20, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text(
                'Vital Signs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (vitals['bloodPressure'] != null)
                _buildVitalChip(
                  'BP',
                  '${vitals['bloodPressure']} mmHg',
                  Icons.bloodtype,
                ),
              if (vitals['temperature'] != null)
                _buildVitalChip(
                  'Temp',
                  '${vitals['temperature']}°C',
                  Icons.thermostat,
                ),
              if (vitals['pulse'] != null)
                _buildVitalChip(
                  'Pulse',
                  '${vitals['pulse']} bpm',
                  Icons.monitor_heart,
                ),
              if (vitals['respiratoryRate'] != null)
                _buildVitalChip(
                  'RR',
                  '${vitals['respiratoryRate']} /min',
                  Icons.air,
                ),
              if (vitals['weight'] != null)
                _buildVitalChip(
                  'Weight',
                  '${vitals['weight']} kg',
                  Icons.monitor_weight,
                ),
              if (vitals['height'] != null)
                _buildVitalChip(
                  'Height',
                  '${vitals['height']} cm',
                  Icons.height,
                ),
              if (vitals['oxygenSaturation'] != null)
                _buildVitalChip(
                  'SpO2',
                  '${vitals['oxygenSaturation']}%',
                  Icons.healing,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.teal),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(String title, String content, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.teal),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }

  void _printConsultationNote(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Fetch health record
      final healthRecordSnapshot = await FirebaseFirestore.instance
          .collection('health_records')
          .where('appointmentId', isEqualTo: appointmentId)
          .get();

      if (healthRecordSnapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No consultation details available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final healthRecordData = healthRecordSnapshot.docs.first.data();

      // Generate PDF
      final pdf = pw.Document();

      // Load logo image
      final logoImage = await rootBundle.load('assets/images/logo.png');
      final logoImageBytes = logoImage.buffer.asUint8List();

      final patientName = data['patientName'] ?? 'Patient';
      final doctorName =
          data['assignedStaffName'] ?? data['doctorName'] ?? 'Doctor';
      final facilityName = data['facilityName'] ?? 'Facility';
      final completedAtDate = data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : DateTime.now();
      final dateStr = DateFormat(
        'MMMM dd, yyyy • hh:mm a',
      ).format(completedAtDate);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header with Logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LifeCare Connect',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      facilityName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  width: 80,
                  height: 80,
                  child: pw.Image(
                    pw.MemoryImage(logoImageBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.teal, thickness: 2),
            pw.SizedBox(height: 15),

            // Document Title
            pw.Center(
              child: pw.Text(
                'REMOTE CONSULTATION NOTES',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Patient Information
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Patient Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfInfoRow('Patient Name', patientName),
                  _buildPdfInfoRow('Patient ID', data['patientId'] ?? 'N/A'),
                  _buildPdfInfoRow('Consultation Date', dateStr),
                  _buildPdfInfoRow('Doctor', doctorName),
                  _buildPdfInfoRow('Department', data['department'] ?? 'N/A'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Vitals (if available)
            if (healthRecordData['vitals'] != null &&
                healthRecordData['vitals'] is Map)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Vital Signs',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Wrap(
                        spacing: 15,
                        runSpacing: 8,
                        children: _buildVitalsPdfItems(
                          healthRecordData['vitals'] as Map<String, dynamic>,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Chief Complaint / Clinical Notes (doctor uses 'clinicalNotes')
            if (healthRecordData['clinicalNotes'] != null &&
                healthRecordData['clinicalNotes'].toString().isNotEmpty)
              _buildPdfSection(
                'Chief Complaint / Symptoms',
                healthRecordData['clinicalNotes'],
              ),

            // Diagnosis
            if (healthRecordData['diagnosis'] != null &&
                healthRecordData['diagnosis'].toString().isNotEmpty)
              _buildPdfSection('Diagnosis', healthRecordData['diagnosis']),

            // Follow-up / Treatment Plan (doctor uses 'followUp')
            if (healthRecordData['followUp'] != null &&
                healthRecordData['followUp'].toString().isNotEmpty)
              _buildPdfSection(
                'Follow-up / Treatment Plan',
                healthRecordData['followUp'],
              ),

            // Prescription (doctor uses 'prescriptions' as array)
            if (healthRecordData['prescriptions'] != null &&
                (healthRecordData['prescriptions'] as List).isNotEmpty)
              _buildPdfListSection(
                'Prescription',
                (healthRecordData['prescriptions'] as List)
                    .map((e) => e.toString())
                    .toList(),
              ),

            // Lab Tests (doctor uses 'labRequests' as array)
            if (healthRecordData['labRequests'] != null &&
                (healthRecordData['labRequests'] as List).isNotEmpty)
              _buildPdfListSection(
                'Laboratory Tests Requested',
                (healthRecordData['labRequests'] as List)
                    .map((e) => e.toString())
                    .toList(),
              ),

            // Radiological Tests (doctor uses 'radiologyRequests' as array)
            if (healthRecordData['radiologyRequests'] != null &&
                (healthRecordData['radiologyRequests'] as List).isNotEmpty)
              _buildPdfListSection(
                'Radiology Requested',
                (healthRecordData['radiologyRequests'] as List)
                    .map((e) => e.toString())
                    .toList(),
              ),

            // Additional Notes
            if (healthRecordData['notes'] != null &&
                healthRecordData['notes'].toString().isNotEmpty)
              _buildPdfSection('Additional Notes', healthRecordData['notes']),

            pw.SizedBox(height: 30),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'This is an electronically generated document',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );

      // Print or save PDF
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
            'consultation_${data['patientName']}_${DateFormat('yyyyMMdd').format(completedAtDate)}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  List<pw.Widget> _buildVitalsPdfItems(Map<String, dynamic> vitals) {
    final items = <pw.Widget>[];

    if (vitals['bloodPressure'] != null) {
      items.add(_buildVitalPdfItem('BP', '${vitals['bloodPressure']} mmHg'));
    }
    if (vitals['temperature'] != null) {
      items.add(_buildVitalPdfItem('Temp', '${vitals['temperature']}°C'));
    }
    if (vitals['pulse'] != null) {
      items.add(_buildVitalPdfItem('Pulse', '${vitals['pulse']} bpm'));
    }
    if (vitals['respiratoryRate'] != null) {
      items.add(_buildVitalPdfItem('RR', '${vitals['respiratoryRate']} /min'));
    }
    if (vitals['weight'] != null) {
      items.add(_buildVitalPdfItem('Weight', '${vitals['weight']} kg'));
    }
    if (vitals['height'] != null) {
      items.add(_buildVitalPdfItem('Height', '${vitals['height']} cm'));
    }
    if (vitals['oxygenSaturation'] != null) {
      items.add(_buildVitalPdfItem('SpO2', '${vitals['oxygenSaturation']}%'));
    }

    return items;
  }

  pw.Widget _buildVitalPdfItem(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSection(String title, String content) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              content,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfListSection(String title, List<String> items) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Text(
                        '• $item',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          lineSpacing: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
