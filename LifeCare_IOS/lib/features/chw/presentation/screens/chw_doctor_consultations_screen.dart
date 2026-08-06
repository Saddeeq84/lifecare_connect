// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../utils/web_open_call_page_stub.dart'
    if (dart.library.js_interop) '../../../../utils/web_open_call_page_web.dart';
import '../../../consultation/presentation/screens/consultation_screen.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/presentation/screens/messages_screen.dart';

class CHWDoctorConsultationsScreen extends StatelessWidget {
  const CHWDoctorConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doctor Consultations'),
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
// PENDING CONSULTATIONS TAB
// ============================================================================
class _PendingConsultationsTab extends StatelessWidget {
  const _PendingConsultationsTab();

  @override
  Widget build(BuildContext context) {
    final chwUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('referredBy', isEqualTo: chwUid)
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final appointments = snapshot.data?.docs ?? [];

        if (appointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending consultations',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Referrals approved by doctors will appear here',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
    final providerName = data['providerName'] ?? 'Unknown Doctor';
    final reason = data['reason'] ?? 'No reason provided';

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
                const Icon(Icons.medical_services, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    providerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
            if (reason.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reason,
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

  void _startVideoCall(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    if (kIsWeb) {
      openWebCallPage(
        channelName: 'appointment_$appointmentId',
        isVideo: true,
        userName: FirebaseAuth.instance.currentUser?.displayName ?? 'CHW',
        userRole: 'chw',
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
    } else {
      // Mobile implementation
      _showCallConfirmationDialog(
        context,
        'appointment_$appointmentId',
        isVideo: true,
        appointmentId: appointmentId,
        otherParticipantId: data['providerId'],
        otherParticipantName: data['providerName'] ?? 'Doctor',
        otherParticipantRole: 'doctor',
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
        userName: FirebaseAuth.instance.currentUser?.displayName ?? 'CHW',
        userRole: 'chw',
        uid: FirebaseAuth.instance.currentUser?.uid,
      );
    } else {
      // Mobile implementation
      _showCallConfirmationDialog(
        context,
        'appointment_$appointmentId',
        isVideo: false,
        appointmentId: appointmentId,
        otherParticipantId: data['providerId'],
        otherParticipantName: data['providerName'] ?? 'Doctor',
        otherParticipantRole: 'doctor',
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
        FirebaseAuth.instance.currentUser?.displayName ?? 'CHW';
    final providerId = data['providerId'] ?? '';
    final providerName = data['providerName'] ?? 'Doctor';

    if (providerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor information not found')),
      );
      return;
    }

    try {
      // Use MessageService to create or get conversation
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: currentUserId,
        user1Name: currentUserName,
        user1Role: 'chw',
        user2Id: providerId,
        user2Name: providerName,
        user2Role: 'doctor',
        title: 'CHW-Doctor Consultation',
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
                'patientName': providerName,
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
    // This will be used by doctors to add consultation notes
    // For CHW, show info that doctor needs to add the note
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Consultation Note'),
        content: const Text(
          'Consultation notes are added by the doctor during or after the consultation. '
          'You can view completed consultation records in the "Records" tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
// COMPLETED CONSULTATIONS TAB
// ============================================================================
class _CompletedConsultationsTab extends StatelessWidget {
  const _CompletedConsultationsTab();

  @override
  Widget build(BuildContext context) {
    final chwUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('referredBy', isEqualTo: chwUid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final appointments = snapshot.data?.docs ?? [];

        // Sort by completedAt client-side
        appointments.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCompleted = (aData['completedAt'] as Timestamp?)?.toDate();
          final bCompleted = (bData['completedAt'] as Timestamp?)?.toDate();
          if (aCompleted == null && bCompleted == null) return 0;
          if (aCompleted == null) return 1;
          if (bCompleted == null) return -1;
          return bCompleted.compareTo(aCompleted);
        });

        if (appointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No completed consultations',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
            final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

            // Get patient name - check multiple possible fields
            final patientName =
                data['relatedPatientName'] ??
                data['patientName'] ??
                'Unknown Patient';

            final providerName = data['providerName'] ?? 'Unknown Doctor';

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, color: Colors.white),
                ),
                title: Text(patientName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Doctor: $providerName',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (completedAt != null)
                      Text(
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(completedAt),
                        style: const TextStyle(fontSize: 12),
                      )
                    else
                      const Text('Completed', style: TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Show completion details
                  _showCompletionDetails(context, data);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showCompletionDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Consultation Completed'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Doctor', data['providerName'] ?? 'N/A'),
              _buildDetailRow(
                'Date',
                data['completedAt'] != null
                    ? DateFormat(
                        'MMM dd, yyyy',
                      ).format((data['completedAt'] as Timestamp).toDate())
                    : 'N/A',
              ),
              _buildDetailRow('Status', 'Completed'),
              if (data['amount'] != null && data['amount'] > 0)
                _buildDetailRow('Fee', '₦${data['amount']}'),
              if (data['paymentStatus'] != null)
                _buildDetailRow('Payment', data['paymentStatus']),
              const SizedBox(height: 16),
              const Text(
                'View detailed consultation records in the "Records" tab.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ============================================================================
// CONSULTATION RECORDS TAB
// ============================================================================
class _ConsultationRecordsTab extends StatelessWidget {
  const _ConsultationRecordsTab();

  @override
  Widget build(BuildContext context) {
    final chwUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chw_consultation_records')
          .where('chwId', isEqualTo: chwUid)
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
                SizedBox(height: 8),
                Text(
                  'Records will appear here after doctors complete consultations',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
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
            return _ConsultationRecordCard(recordId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _ConsultationRecordCard extends StatelessWidget {
  final String recordId;
  final Map<String, dynamic> data;

  const _ConsultationRecordCard({required this.recordId, required this.data});

  @override
  Widget build(BuildContext context) {
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final patientAge = data['patientAge']?.toString() ?? 'N/A';
    final patientSex = data['patientSex'] ?? 'N/A';
    final doctorName = data['doctorName'] ?? 'Unknown Doctor';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

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
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Text(
                    patientName.isNotEmpty ? patientName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
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
                        '$patientAge years • $patientSex',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Doctor: $doctorName',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                  onPressed: () => _viewDetails(context),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () => _printRecord(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _ConsultationRecordDetailsScreen(recordId: recordId, data: data),
      ),
    );
  }

  Future<void> _printRecord(BuildContext context) async {
    try {
      final pdf = await _generatePrintablePDF();
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<pw.Document> _generatePrintablePDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Load logo
    final logoImage = await rootBundle.load('assets/images/logo.png');
    final logoImageBytes = logoImage.buffer.asUint8List();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Company Header with Logo
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
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Connecting you to quality healthcare services',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.Image(
                      pw.MemoryImage(logoImageBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 2, color: PdfColors.teal),
              pw.SizedBox(height: 12),
              // Document Title
              pw.Center(
                child: pw.Text(
                  'CONSULTATION RECORD',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Print Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(now)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.SizedBox(height: 16),

              // Patient Information
              pw.Text(
                'PATIENT INFORMATION',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPDFRow('Name', data['patientName'] ?? 'N/A'),
              _buildPDFRow('Age', data['patientAge']?.toString() ?? 'N/A'),
              _buildPDFRow('Sex', data['patientSex'] ?? 'N/A'),
              pw.SizedBox(height: 16),

              // Consultation Details
              pw.Text(
                'CONSULTATION DETAILS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPDFRow('Doctor', data['doctorName'] ?? 'N/A'),
              if (data['createdAt'] != null)
                _buildPDFRow(
                  'Date',
                  DateFormat(
                    'MMM dd, yyyy - hh:mm a',
                  ).format((data['createdAt'] as Timestamp).toDate()),
                ),
              pw.SizedBox(height: 16),

              // Medications
              if (data['medications'] != null &&
                  (data['medications'] as List).isNotEmpty) ...[
                pw.Text(
                  'MEDICATIONS PRESCRIBED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...((data['medications'] as List).map((med) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      '• ${med['name']} - ${med['dosage']} - ${med['frequency']}',
                    ),
                  );
                })),
                pw.SizedBox(height: 16),
              ],

              // Laboratory Tests
              if (data['laboratoryTests'] != null &&
                  (data['laboratoryTests'] as List).isNotEmpty) ...[
                pw.Text(
                  'LABORATORY TESTS REQUESTED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...((data['laboratoryTests'] as List).map((test) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text('• $test'),
                  );
                })),
                pw.SizedBox(height: 16),
              ],

              // Radiological Tests
              if (data['radiologicalTests'] != null &&
                  (data['radiologicalTests'] as List).isNotEmpty) ...[
                pw.Text(
                  'RADIOLOGICAL TESTS REQUESTED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...((data['radiologicalTests'] as List).map((test) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text('• $test'),
                  );
                })),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Footer with Company Contact Info
              pw.Divider(thickness: 1, color: PdfColors.teal),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'LifeCare Connect',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '🌐 www.lifecare.rhemn.org.ng',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text(
                      '📧 info@lifecare.rhemn.org.ng',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'This document contains only prescribed medications and requested tests.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'For complete consultation details, please refer to the original medical records.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
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
}

// ============================================================================
// CONSULTATION RECORD DETAILS SCREEN
// ============================================================================
class _ConsultationRecordDetailsScreen extends StatelessWidget {
  final String recordId;
  final Map<String, dynamic> data;

  const _ConsultationRecordDetailsScreen({
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
            onPressed: () => _printRecord(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', data['patientName'] ?? 'N/A'),
                    _buildDetailRow(
                      'Age',
                      data['patientAge']?.toString() ?? 'N/A',
                    ),
                    _buildDetailRow('Sex', data['patientSex'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Consultation Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consultation Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Doctor', data['doctorName'] ?? 'N/A'),
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

            // Medications (READ-ONLY)
            if (data['medications'] != null &&
                (data['medications'] as List).isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medication, color: Colors.teal),
                          SizedBox(width: 8),
                          Text(
                            'Medications Prescribed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...((data['medications'] as List).map((med) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      med['name'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text('Dosage: ${med['dosage'] ?? 'N/A'}'),
                                    Text(
                                      'Frequency: ${med['frequency'] ?? 'N/A'}',
                                    ),
                                    if (med['duration'] != null)
                                      Text('Duration: ${med['duration']}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Laboratory Tests (READ-ONLY)
            if (data['laboratoryTests'] != null &&
                (data['laboratoryTests'] as List).isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.science, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Laboratory Tests Requested',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...((data['laboratoryTests'] as List).map((test) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $test'),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Radiological Tests (READ-ONLY)
            if (data['radiologicalTests'] != null &&
                (data['radiologicalTests'] as List).isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_hospital, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Radiological Tests Requested',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...((data['radiologicalTests'] as List).map((test) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $test'),
                        );
                      })),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Note about hidden fields
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Diagnosis, clinical details, and other medical information are kept confidential and not displayed here.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
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
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Future<void> _printRecord(BuildContext context) async {
    try {
      final pdf = await _generatePrintablePDF();
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<pw.Document> _generatePrintablePDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CONSULTATION RECORD',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Print Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(now)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              pw.Text(
                'PATIENT INFORMATION',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPDFRow('Name', data['patientName'] ?? 'N/A'),
              _buildPDFRow('Age', data['patientAge']?.toString() ?? 'N/A'),
              _buildPDFRow('Sex', data['patientSex'] ?? 'N/A'),
              pw.SizedBox(height: 16),

              pw.Text(
                'CONSULTATION DETAILS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildPDFRow('Doctor', data['doctorName'] ?? 'N/A'),
              if (data['createdAt'] != null)
                _buildPDFRow(
                  'Date',
                  DateFormat(
                    'MMM dd, yyyy - hh:mm a',
                  ).format((data['createdAt'] as Timestamp).toDate()),
                ),
              pw.SizedBox(height: 16),

              if (data['medications'] != null &&
                  (data['medications'] as List).isNotEmpty) ...[
                pw.Text(
                  'MEDICATIONS PRESCRIBED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...((data['medications'] as List).map((med) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      '• ${med['name']} - ${med['dosage']} - ${med['frequency']}',
                    ),
                  );
                })),
                pw.SizedBox(height: 16),
              ],

              if (data['laboratoryTests'] != null &&
                  (data['laboratoryTests'] as List).isNotEmpty) ...[
                pw.Text(
                  'LABORATORY TESTS REQUESTED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...((data['laboratoryTests'] as List).map((test) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text('• $test'),
                  );
                })),
                pw.SizedBox(height: 16),
              ],

              if (data['radiologicalTests'] != null &&
                  (data['radiologicalTests'] as List).isNotEmpty) ...[
                pw.Text(
                  'RADIOLOGICAL TESTS REQUESTED',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                ...((data['radiologicalTests'] as List).map((test) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text('• $test'),
                  );
                })),
              ],

              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'This document contains only prescribed medications and requested tests.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
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
}
