// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../utils/web_open_call_page_stub.dart'
    if (dart.library.js_interop) '../../../../utils/web_open_call_page_web.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/presentation/screens/messages_screen.dart';
import '../../../consultation/presentation/screens/consultation_screen.dart';

class DoctorCHWConsultationsScreen extends StatelessWidget {
  const DoctorCHWConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CHW Consultations'),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
              Tab(icon: Icon(Icons.check_circle), text: 'Completed'),
              Tab(icon: Icon(Icons.folder_open), text: 'Records'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingConsultationsTab(),
            _CompletedConsultationsTab(),
            _ConsultationRecordsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PENDING CONSULTATIONS TAB (CHW Appointments)
// ============================================================================
class _PendingConsultationsTab extends StatelessWidget {
  const _PendingConsultationsTab();

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: doctorUid)
          .where('status', isEqualTo: 'approved')
          .where('providerType', isEqualTo: 'doctor')
          .orderBy('appointmentDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final appointments = snapshot.data?.docs ?? [];

        // Filter for CHW appointments (appointments referred by CHW or booked by CHW)
        final chwAppointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Check if it's a CHW booking - identified by:
          // 1. referredBy field (CHW-registered patient referrals)
          // 2. bookedByRole == 'chw' (CHW booking for their patient)
          // 3. referredByType == 'chw' (additional referral marker)
          return data['referredBy'] != null ||
              data['bookedByRole'] == 'chw' ||
              data['referredByType'] == 'chw';
        }).toList();

        if (chwAppointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending CHW consultations',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chwAppointments.length,
          itemBuilder: (context, index) {
            final doc = chwAppointments[index];
            final data = doc.data() as Map<String, dynamic>;
            return _PendingConsultationCard(appointmentId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _PendingConsultationCard extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;

  const _PendingConsultationCard({
    required this.appointmentId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final appointmentDate = (data['appointmentDate'] as Timestamp?)?.toDate();
    final chwName = data['patientName'] ?? 'Unknown CHW';
    final reason = data['reason'] ?? 'No reason provided';

    // Extract patient information if available
    final walkInData = data['walkInPatientData'] as Map<String, dynamic>?;
    final relatedPatientName = data['relatedPatientName'];
    final patientInfo = walkInData != null
        ? '${walkInData['name']} (${walkInData['age']}y, ${walkInData['sex']})'
        : relatedPatientName ?? 'Patient info in pre-consultation data';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chwName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Patient: $patientInfo',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (appointmentDate != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(
                      'MMM dd, yyyy - hh:mm a',
                    ).format(appointmentDate),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            // Pre-consultation data summary
            if (data['preConsultationData'] != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_information,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pre-Consultation Info',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Main Complaint: ${(data['preConsultationData'] as Map)['mainComplaint'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () => _showPreConsultationData(
                        context,
                        data['preConsultationData'],
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'View full details →',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (reason.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Notes: $reason',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Start Consultation:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ConsultationButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: Colors.blue,
                  onTap: () => _startVideoCall(context, appointmentId, data),
                ),
                _ConsultationButton(
                  icon: Icons.phone,
                  label: 'Audio',
                  color: Colors.green,
                  onTap: () => _startAudioCall(context, appointmentId, data),
                ),
                _ConsultationButton(
                  icon: Icons.chat,
                  label: 'Chat',
                  color: Colors.orange,
                  onTap: () => _startChat(context, appointmentId, data),
                ),
                _ConsultationButton(
                  icon: Icons.note_add,
                  label: 'Add Note',
                  color: Colors.purple,
                  onTap: () =>
                      _addConsultationNote(context, appointmentId, data),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPreConsultationData(
    BuildContext context,
    Map<String, dynamic> preConsultData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pre-Consultation Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Main Complaint',
                preConsultData['mainComplaint'] ?? 'N/A',
              ),
              if (preConsultData['symptoms'] != null)
                _buildDetailRow('Symptoms', preConsultData['symptoms']),
              if (preConsultData['duration'] != null)
                _buildDetailRow('Duration', preConsultData['duration']),
              if (preConsultData['severity'] != null)
                _buildDetailRow('Severity', preConsultData['severity']),
              if (preConsultData['medicationsTaken'] != null)
                _buildDetailRow(
                  'Medications Taken',
                  preConsultData['medicationsTaken'],
                ),
              if (preConsultData['allergies'] != null)
                _buildDetailRow('Known Allergies', preConsultData['allergies']),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(value, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _startVideoCall(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    if (kIsWeb) {
      openWebCallPage(
        channelName: 'appointment_$appointmentId',
        isVideo: true,
        userName: FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor',
        userRole: 'doctor',
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
    } else {
      // Mobile implementation
      _showCallConfirmationDialog(
        context,
        'appointment_$appointmentId',
        isVideo: true,
        appointmentId: appointmentId,
        otherParticipantId: data['patientId'],
        otherParticipantName: data['patientName'] ?? 'CHW',
        otherParticipantRole: 'chw',
      );
    }
  }

  void _startAudioCall(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    if (kIsWeb) {
      openWebCallPage(
        channelName: 'appointment_$appointmentId',
        isVideo: false,
        userName: FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor',
        userRole: 'doctor',
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
    } else {
      // Mobile implementation
      _showCallConfirmationDialog(
        context,
        'appointment_$appointmentId',
        isVideo: false,
        appointmentId: appointmentId,
        otherParticipantId: data['patientId'],
        otherParticipantName: data['patientName'] ?? 'CHW',
        otherParticipantRole: 'chw',
      );
    }
  }

  void _startChat(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUserName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
    final chwId = data['patientId'] ?? '';
    final chwName = data['patientName'] ?? 'CHW';

    if (chwId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CHW information not found')),
      );
      return;
    }

    try {
      // Use MessageService to create or get conversation
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: currentUserId,
        user1Name: currentUserName,
        user1Role: 'doctor',
        user2Id: chwId,
        user2Name: chwName,
        user2Role: 'chw',
        title: 'Doctor-CHW Consultation',
        type: 'consultation',
        relatedId: appointmentId,
      );

      if (context.mounted) {
        // Navigate to main messaging screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const MessagesScreen(),
            settings: RouteSettings(
              arguments: {
                'conversationId': conversationId,
                'patientName': chwName,
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening chat: $e')));
      }
    }
  }

  void _addConsultationNote(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    // Navigate to consultation form specifically for CHW patients
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CHWConsultationNoteForm(
          appointmentId: appointmentId,
          appointmentData: data,
        ),
      ),
    );
  }

  void _showCallConfirmationDialog(
    BuildContext parentContext,
    String channelName, {
    required bool isVideo,
    String? appointmentId,
    String? otherParticipantId,
    String? otherParticipantName,
    String? otherParticipantRole,
  }) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Join Consultation'),
        content: Text(
          'Do you want to continue to the ${isVideo ? 'video' : 'audio'} call?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(parentContext).push(
                MaterialPageRoute(
                  builder: (context) => ConsultationScreen(
                    channelName: channelName,
                    isVideo: isVideo,
                    appointmentId: appointmentId,
                    otherParticipantId: otherParticipantId,
                    otherParticipantName: otherParticipantName,
                    otherParticipantRole: otherParticipantRole,
                  ),
                ),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _ConsultationButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ConsultationButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CHW CONSULTATION NOTE FORM (for doctors to fill)
// ============================================================================
class _CHWConsultationNoteForm extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const _CHWConsultationNoteForm({
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<_CHWConsultationNoteForm> createState() =>
      _CHWConsultationNoteFormState();
}

class _CHWConsultationNoteFormState extends State<_CHWConsultationNoteForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Controllers
  final _chiefComplaintController = TextEditingController();
  final _presentingComplaintController = TextEditingController();
  final _historyController = TextEditingController();
  final _pastMedicalHistoryController = TextEditingController();

  // Vital Signs
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _pulseController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _oxygenSaturationController = TextEditingController();

  // Examination
  final _physicalExamController = TextEditingController();
  final _systemicExamController = TextEditingController();

  // Diagnosis
  final _provisionalDiagnosisController = TextEditingController();
  final _differentialDiagnosisController = TextEditingController();
  final _finalDiagnosisController = TextEditingController();

  // Treatment
  final List<Map<String, String>> _medications = [];
  final List<String> _laboratoryTests = [];
  final List<String> _radiologicalTests = [];

  final _treatmentPlanController = TextEditingController();
  final _followUpController = TextEditingController();
  final _doctorNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreConsultationData();
  }

  void _loadPreConsultationData() {
    // Pre-fill from appointment data
    final preConsult =
        widget.appointmentData['preConsultationData'] as Map<String, dynamic>?;
    if (preConsult != null) {
      _chiefComplaintController.text = preConsult['mainComplaint'] ?? '';
      if (preConsult['symptoms'] != null) {
        _presentingComplaintController.text = preConsult['symptoms'];
      }
      if (preConsult['duration'] != null) {
        _historyController.text = 'Duration: ${preConsult['duration']}\n';
      }
      if (preConsult['medicationsTaken'] != null) {
        _pastMedicalHistoryController.text =
            'Medications taken: ${preConsult['medicationsTaken']}\n';
      }
      if (preConsult['allergies'] != null) {
        _pastMedicalHistoryController.text +=
            'Allergies: ${preConsult['allergies']}';
      }
    }
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _presentingComplaintController.dispose();
    _historyController.dispose();
    _pastMedicalHistoryController.dispose();
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    _pulseController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _physicalExamController.dispose();
    _systemicExamController.dispose();
    _provisionalDiagnosisController.dispose();
    _differentialDiagnosisController.dispose();
    _finalDiagnosisController.dispose();
    _treatmentPlanController.dispose();
    _followUpController.dispose();
    _doctorNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitConsultationNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final doctorUid = FirebaseAuth.instance.currentUser?.uid;
      final doctorName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';

      // Extract patient information
      final walkInData =
          widget.appointmentData['walkInPatientData'] as Map<String, dynamic>?;
      final relatedPatientId = widget.appointmentData['relatedPatientId'];
      final relatedPatientName = widget.appointmentData['relatedPatientName'];

      String patientName = 'Unknown';
      String patientAge = 'N/A';
      String patientSex = 'N/A';

      if (walkInData != null) {
        patientName = walkInData['name'] ?? 'Unknown';
        patientAge = walkInData['age']?.toString() ?? 'N/A';
        patientSex = walkInData['sex'] ?? 'N/A';
      } else if (relatedPatientName != null) {
        patientName = relatedPatientName;
        // Try to fetch patient details from users collection
        if (relatedPatientId != null) {
          final patientDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(relatedPatientId)
              .get();
          if (patientDoc.exists) {
            final patientData = patientDoc.data();
            patientAge = patientData?['age']?.toString() ?? 'N/A';
            patientSex = patientData?['sex'] ?? 'N/A';
          }
        }
      }

      // Create consultation record
      final recordData = {
        'chwId': widget.appointmentData['patientId'],
        'chwName': widget.appointmentData['patientName'],
        'doctorId': doctorUid,
        'doctorName': doctorName,
        'appointmentId': widget.appointmentId,

        // Patient information
        'patientName': patientName,
        'patientAge': patientAge,
        'patientSex': patientSex,

        // Link to patient if exists
        'relatedPatientId': ?relatedPatientId,
        'relatedPatientName': ?relatedPatientName,
        'walkInPatientData': ?walkInData,

        // Clinical information
        'chiefComplaint': _chiefComplaintController.text.trim(),
        'presentingComplaint': _presentingComplaintController.text.trim(),
        'historyOfPresentIllness': _historyController.text.trim(),
        'pastMedicalHistory': _pastMedicalHistoryController.text.trim(),

        // Vital signs
        'vitalSigns': {
          'temperature': _temperatureController.text.trim(),
          'bloodPressure': _bloodPressureController.text.trim(),
          'pulse': _pulseController.text.trim(),
          'respiratoryRate': _respiratoryRateController.text.trim(),
          'oxygenSaturation': _oxygenSaturationController.text.trim(),
        },

        // Examination
        'physicalExamination': _physicalExamController.text.trim(),
        'systemicExamination': _systemicExamController.text.trim(),

        // Diagnosis
        'provisionalDiagnosis': _provisionalDiagnosisController.text.trim(),
        'differentialDiagnosis': _differentialDiagnosisController.text.trim(),
        'finalDiagnosis': _finalDiagnosisController.text.trim(),

        // Investigations and treatment
        'laboratoryTests': _laboratoryTests,
        'radiologicalTests': _radiologicalTests,
        'medications': _medications,

        // Management
        'treatmentPlan': _treatmentPlanController.text.trim(),
        'followUpInstructions': _followUpController.text.trim(),
        'doctorNotes': _doctorNotesController.text.trim(),

        // Metadata
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'consultationType': 'chw_consultation',
        'status': 'completed',
      };

      // Save to chw_consultation_records
      await FirebaseFirestore.instance
          .collection('chw_consultation_records')
          .add(recordData);

      // Update appointment status to completed
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation note saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Go back
        Navigator.of(context).pop(); // Go back to consultations screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving consultation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHW Consultation Note'),
        backgroundColor: Colors.teal,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHW: ${widget.appointmentData['patientName']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.appointmentData['walkInPatientData'] != null)
                      Text(
                        'Patient: ${widget.appointmentData['walkInPatientData']['name']}',
                      )
                    else if (widget.appointmentData['relatedPatientName'] !=
                        null)
                      Text(
                        'Patient: ${widget.appointmentData['relatedPatientName']}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Chief Complaint (Read-only - from CHW)
              _buildSectionHeader('Chief Complaint (Submitted by CHW)'),
              TextFormField(
                controller: _chiefComplaintController,
                decoration: InputDecoration(
                  hintText: 'Enter chief complaint',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                maxLines: 2,
                readOnly: true,
                enabled: false,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 4),
              Text(
                'This information was submitted by the CHW and cannot be edited',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Presenting Complaint (Read-only - from CHW)
              _buildSectionHeader('Presenting Complaint (Submitted by CHW)'),
              TextFormField(
                controller: _presentingComplaintController,
                decoration: InputDecoration(
                  hintText: 'Detailed description',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                maxLines: 3,
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 4),
              Text(
                'This information was submitted by the CHW and cannot be edited',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // History (Read-only - from CHW)
              _buildSectionHeader(
                'History of Present Illness (Submitted by CHW)',
              ),
              TextFormField(
                controller: _historyController,
                decoration: InputDecoration(
                  hintText: 'History details',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                maxLines: 3,
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 4),
              Text(
                'This information was submitted by the CHW and cannot be edited',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Past Medical History (Read-only - from CHW)
              _buildSectionHeader('Past Medical History (Submitted by CHW)'),
              TextFormField(
                controller: _pastMedicalHistoryController,
                decoration: InputDecoration(
                  hintText: 'Previous conditions, medications, allergies',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
                maxLines: 3,
                readOnly: true,
                enabled: false,
              ),
              const SizedBox(height: 4),
              Text(
                'This information was submitted by the CHW and cannot be edited',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),

              // Vital Signs (Optional)
              _buildSectionHeader('Vital Signs (Optional)'),
              Text(
                'Fill in vital signs if available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _temperatureController,
                      decoration: const InputDecoration(
                        labelText: 'Temp (°C)',
                        border: OutlineInputBorder(),
                        hintText: 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _bloodPressureController,
                      decoration: const InputDecoration(
                        labelText: 'BP (mmHg)',
                        border: OutlineInputBorder(),
                        hintText: 'Optional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pulseController,
                      decoration: const InputDecoration(
                        labelText: 'Pulse (bpm)',
                        border: OutlineInputBorder(),
                        hintText: 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _respiratoryRateController,
                      decoration: const InputDecoration(
                        labelText: 'RR (brpm)',
                        border: OutlineInputBorder(),
                        hintText: 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _oxygenSaturationController,
                      decoration: const InputDecoration(
                        labelText: 'O2 Sat (%)',
                        border: OutlineInputBorder(),
                        hintText: 'Optional',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Physical Examination
              _buildSectionHeader('Physical Examination'),
              TextFormField(
                controller: _physicalExamController,
                decoration: const InputDecoration(
                  hintText: 'General examination findings',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Systemic Examination
              _buildSectionHeader('Systemic Examination'),
              TextFormField(
                controller: _systemicExamController,
                decoration: const InputDecoration(
                  hintText: 'System-specific findings',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Diagnosis
              _buildSectionHeader('Diagnosis'),
              TextFormField(
                controller: _provisionalDiagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Provisional Diagnosis',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _differentialDiagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Differential Diagnosis (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _finalDiagnosisController,
                decoration: const InputDecoration(
                  labelText: 'Final Diagnosis',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Investigations
              _buildSectionHeader('Laboratory Tests'),
              _buildListManager(
                items: _laboratoryTests,
                hintText: 'Add laboratory test',
                onAdd: (value) => setState(() => _laboratoryTests.add(value)),
                onRemove: (index) =>
                    setState(() => _laboratoryTests.removeAt(index)),
              ),
              const SizedBox(height: 16),

              _buildSectionHeader('Radiological Tests'),
              _buildListManager(
                items: _radiologicalTests,
                hintText: 'Add radiological test',
                onAdd: (value) => setState(() => _radiologicalTests.add(value)),
                onRemove: (index) =>
                    setState(() => _radiologicalTests.removeAt(index)),
              ),
              const SizedBox(height: 20),

              // Medications
              _buildSectionHeader('Medications'),
              _buildMedicationManager(),
              const SizedBox(height: 20),

              // Treatment Plan
              _buildSectionHeader('Treatment Plan'),
              TextFormField(
                controller: _treatmentPlanController,
                decoration: const InputDecoration(
                  hintText: 'Overall treatment approach',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Follow-up
              _buildSectionHeader('Follow-up Instructions'),
              TextFormField(
                controller: _followUpController,
                decoration: const InputDecoration(
                  hintText: 'When to return, warning signs',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Doctor Notes
              _buildSectionHeader('Additional Notes'),
              TextFormField(
                controller: _doctorNotesController,
                decoration: const InputDecoration(
                  hintText: 'Any additional observations or notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitConsultationNote,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Consultation Note',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildListManager({
    required List<String> items,
    required String hintText,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    final controller = TextEditingController();

    return Column(
      children: [
        ...items.asMap().entries.map((entry) {
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.check_circle,
              color: Colors.teal,
              size: 20,
            ),
            title: Text(entry.value),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => onRemove(entry.key),
            ),
          );
        }),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.teal),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onAdd(controller.text.trim());
                  controller.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMedicationManager() {
    return Column(
      children: [
        ..._medications.asMap().entries.map((entry) {
          final med = entry.value;
          return Card(
            child: ListTile(
              title: Text(med['name'] ?? ''),
              subtitle: Text('${med['dosage']} - ${med['frequency']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () =>
                    setState(() => _medications.removeAt(entry.key)),
              ),
            ),
          );
        }),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Medication'),
          onPressed: () => _showAddMedicationDialog(),
        ),
      ],
    );
  }

  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();
    final durationController = TextEditingController();
    final instructionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Medication'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                ),
              ),
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage *'),
              ),
              TextField(
                controller: frequencyController,
                decoration: const InputDecoration(labelText: 'Frequency *'),
              ),
              TextField(
                controller: durationController,
                decoration: const InputDecoration(labelText: 'Duration'),
              ),
              TextField(
                controller: instructionsController,
                decoration: const InputDecoration(labelText: 'Instructions'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  dosageController.text.trim().isNotEmpty &&
                  frequencyController.text.trim().isNotEmpty) {
                setState(() {
                  _medications.add({
                    'name': nameController.text.trim(),
                    'dosage': dosageController.text.trim(),
                    'frequency': frequencyController.text.trim(),
                    'duration': durationController.text.trim(),
                    'instructions': instructionsController.text.trim(),
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPLETED CONSULTATIONS TAB
// ============================================================================
class _CompletedConsultationsTab extends StatelessWidget {
  const _CompletedConsultationsTab();

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: doctorUid)
          .where('status', isEqualTo: 'completed')
          .where('providerType', isEqualTo: 'doctor')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final appointments = snapshot.data?.docs ?? [];

        // Filter for CHW appointments (appointments referred by CHW or booked by CHW)
        final chwAppointments = appointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Check if it's a CHW booking - identified by:
          // 1. referredBy field (CHW-registered patient referrals)
          // 2. bookedByRole == 'chw' (CHW booking for their patient)
          // 3. referredByType == 'chw' (additional referral marker)
          return data['referredBy'] != null ||
              data['bookedByRole'] == 'chw' ||
              data['referredByType'] == 'chw';
        }).toList();

        if (chwAppointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed CHW consultations',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chwAppointments.length,
          itemBuilder: (context, index) {
            final doc = chwAppointments[index];
            final data = doc.data() as Map<String, dynamic>;
            final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
            final chwName = data['patientName'] ?? 'Unknown CHW';

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, color: Colors.white),
                ),
                title: Text(chwName),
                subtitle: completedAt != null
                    ? Text(
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(completedAt),
                      )
                    : const Text('Completed'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to records tab or show details
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('View in Records tab for details'),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// CONSULTATION RECORDS TAB (Doctor can view full details)
// ============================================================================
class _ConsultationRecordsTab extends StatelessWidget {
  const _ConsultationRecordsTab();

  @override
  Widget build(BuildContext context) {
    final doctorUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chw_consultation_records')
          .where('doctorId', isEqualTo: doctorUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final records = snapshot.data?.docs ?? [];

        if (records.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No consultation records',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final doc = records[index];
            final data = doc.data() as Map<String, dynamic>;
            final patientName = data['patientName'] ?? 'Unknown';
            final chwName = data['chwName'] ?? 'Unknown CHW';
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.folder, color: Colors.white),
                ),
                title: Text(patientName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CHW: $chwName'),
                    if (createdAt != null)
                      Text(
                        DateFormat('MMM dd, yyyy').format(createdAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Navigate to full record view
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _DoctorRecordDetailsScreen(
                        recordId: doc.id,
                        data: data,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// DOCTOR RECORD DETAILS SCREEN (Full access to all fields)
// ============================================================================
class _DoctorRecordDetailsScreen extends StatelessWidget {
  final String recordId;
  final Map<String, dynamic> data;

  const _DoctorRecordDetailsScreen({
    required this.recordId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Record'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printCompleteRecord(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient & CHW Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient & CHW Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Patient', data['patientName'] ?? 'N/A'),
                    _buildDetailRow(
                      'Age',
                      data['patientAge']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow('Sex', data['patientSex'] ?? 'N/A'),
                    _buildDetailRow('CHW', data['chwName'] ?? 'N/A'),
                    if (data['createdAt'] != null)
                      _buildDetailRow(
                        'Date',
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format((data['createdAt'] as Timestamp).toDate()),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Clinical Information (Full access for doctor)
            if (data['chiefComplaint'] != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Chief Complaint',
                        data['chiefComplaint'],
                      ),
                      if (data['presentingComplaint'] != null)
                        _buildDetailRow(
                          'Presenting Complaint',
                          data['presentingComplaint'],
                        ),
                      if (data['historyOfPresentIllness'] != null)
                        _buildDetailRow(
                          'History',
                          data['historyOfPresentIllness'],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Vital Signs
            if (data['vitalSigns'] != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vital Signs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...((data['vitalSigns'] as Map).entries.map((entry) {
                        if (entry.value.toString().isNotEmpty) {
                          return _buildDetailRow(
                            entry.key.toString().replaceAll(
                              RegExp(r'(?<!^)(?=[A-Z])'),
                              ' ',
                            ),
                            entry.value.toString(),
                          );
                        }
                        return const SizedBox.shrink();
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Diagnosis (Doctor full access)
            if (data['provisionalDiagnosis'] != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Diagnosis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'Provisional',
                        data['provisionalDiagnosis'],
                      ),
                      if (data['differentialDiagnosis'] != null)
                        _buildDetailRow(
                          'Differential',
                          data['differentialDiagnosis'],
                        ),
                      if (data['finalDiagnosis'] != null)
                        _buildDetailRow('Final', data['finalDiagnosis']),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Medications, Lab tests, etc. (same as CHW view but with edit option)
            // ... Add remaining sections similar to CHW screen but with full details
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  Future<void> _printCompleteRecord(BuildContext context) async {
    // Doctor gets FULL record with all clinical details
    try {
      final pdf = pw.Document();
      // Add complete PDF generation with all fields
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
