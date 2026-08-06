import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/fee_config_service.dart';
import '../../../consultation/presentation/screens/consultation_screen.dart';
import '../../../shared/presentation/screens/chat_screen.dart';
import '../../../shared/data/services/message_service.dart';

class MedicalRecordsRemoteConsultationsScreen extends StatefulWidget {
  const MedicalRecordsRemoteConsultationsScreen({super.key});

  @override
  State<MedicalRecordsRemoteConsultationsScreen> createState() =>
      _MedicalRecordsRemoteConsultationsScreenState();
}

class _MedicalRecordsRemoteConsultationsScreenState
    extends State<MedicalRecordsRemoteConsultationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _facilityId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        _facilityId = userDoc.data()?['facilityId'];
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_facilityId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Remote Consultations'),
          backgroundColor: Colors.teal,
        ),
        body: const Center(
          child: Text('No facility associated with this account'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Consultations'),
        backgroundColor: Colors.teal,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Completed', icon: Icon(Icons.done_all)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingConsultationsTab(facilityId: _facilityId!),
          _CompletedConsultationsTab(facilityId: _facilityId!),
        ],
      ),
    );
  }
}

// Pending Consultations Tab (Awaiting Remote Doctor or Pending Consultation)
class _PendingConsultationsTab extends StatelessWidget {
  final String facilityId;

  const _PendingConsultationsTab({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: facilityId)
          .where('doctorType', isEqualTo: 'remote')
          .where(
            'status',
            whereIn: ['pending', 'approved'],
          ) // Show both pending approval and approved
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

        final allAppointments = snapshot.data?.docs ?? [];

        // Filter to show only:
        // 1. Appointments pending doctor approval (status = 'pending')
        // 2. Approved appointments awaiting consultation (status = 'approved' AND consultationStatus in ['pending', 'in-progress'])
        final appointments = allAppointments.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final consultationStatus = data['consultationStatus'] as String?;

          if (status == 'pending') {
            return true; // Show all pending appointments (waiting for doctor approval)
          }

          if (status == 'approved' &&
              (consultationStatus == 'pending' ||
                  consultationStatus == 'in-progress')) {
            return true; // Show approved appointments that haven't been completed yet
          }

          return false;
        }).toList();

        // Sort by createdAt descending (newest first)
        appointments.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // descending
        });

        if (appointments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_queue, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Pending Remote Consultations',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Appointments with remote doctors will appear here',
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

            return _buildConsultationCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildConsultationCard(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    final appointmentDate = data['appointmentDate'];
    final doctorName =
        data['assignedStaffName'] ?? data['doctorName'] ?? 'Unknown Doctor';
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final status = data['status'] ?? 'pending';
    final consultationStatus = data['consultationStatus'] ?? 'pending';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    // Determine status display based on appointment status
    if (status == 'pending') {
      // Waiting for doctor to approve
      statusColor = Colors.amber;
      statusIcon = Icons.hourglass_empty;
      statusText = 'AWAITING DOCTOR APPROVAL';
    } else if (consultationStatus == 'in-progress') {
      statusColor = Colors.blue;
      statusIcon = Icons.pending;
      statusText = 'IN PROGRESS';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusText = 'PENDING CONSULTATION';
    }

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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
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
            // Show waiting message for pending approval
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Container(
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
                        'Waiting for doctor to approve this appointment',
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
            const SizedBox(height: 16),
            // Action buttons - only show for approved appointments
            if (status == 'approved')
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
                  // Add Consultation Note Button
                  ElevatedButton.icon(
                    onPressed: () =>
                        _addConsultationNote(context, appointmentId, data),
                    icon: const Icon(Icons.note_add, size: 18),
                    label: const Text('Add Note'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                  // View Details Button
                  TextButton.icon(
                    onPressed: () => _viewDetails(context, appointmentId, data),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('Details'),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal),
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

  void _viewDetails(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
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
                  'Appointment Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 32),
                _buildDetailSection('Patient Information', [
                  _buildDetailRow('Name', data['patientName']),
                  _buildDetailRow('Patient ID', data['patientId']),
                  _buildDetailRow('Phone', data['patientPhone']),
                ]),
                const SizedBox(height: 24),
                _buildDetailSection('Consultation Information', [
                  _buildDetailRow('Doctor', data['assignedStaffName']),
                  _buildDetailRow('Department', data['department']),
                  _buildDetailRow('Doctor Type', 'Remote Doctor'),
                  _buildDetailRow(
                    'Status',
                    data['consultationStatus']?.toString().toUpperCase(),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildDetailSection('Appointment Details', [
                  _buildDetailRow(
                    'Scheduled Date',
                    data['appointmentDate'] != null
                        ? DateFormat('MMM dd, yyyy - hh:mm a').format(
                            (data['appointmentDate'] as Timestamp).toDate(),
                          )
                        : 'N/A',
                  ),
                  _buildDetailRow('Reason for Visit', data['reason']),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
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

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
        content: Text('Start video consultation with ${data['patientName']}?'),
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
                    otherParticipantId: data['patientId'],
                    otherParticipantName: data['patientName'] ?? 'Patient',
                    otherParticipantRole: 'patient',
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
        content: Text('Start audio consultation with ${data['patientName']}?'),
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
                    otherParticipantId: data['patientId'],
                    otherParticipantName: data['patientName'] ?? 'Patient',
                    otherParticipantRole: 'patient',
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

  Future<void> _openChat(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to start a chat'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final patientId = data['patientId'] as String;
      final patientName = data['patientName'] as String? ?? 'Patient';

      // Get current user's details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final currentUserName =
          userData?['fullName'] as String? ?? 'Medical Records Officer';
      final currentUserRole = userData?['role'] as String? ?? 'staff';

      // Get or create conversation
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: currentUser.uid,
        user1Name: currentUserName,
        user1Role: currentUserRole,
        user2Id: patientId,
        user2Name: patientName,
        user2Role: 'patient',
      );

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Navigate to chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherParticipantName: patientName,
              otherParticipantRole: 'patient',
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);
      }

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

  void _addConsultationNote(
    BuildContext context,
    String appointmentId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ConsultationNoteForm(
          appointmentId: appointmentId,
          appointmentData: data,
        ),
      ),
    );
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
          .where('consultationStatus', isEqualTo: 'completed')
          .orderBy('consultationDate', descending: true)
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
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.done_all,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Doctor: $doctorName',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.medical_services,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Department: ${data['department'] ?? 'N/A'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (consultationDate != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Completed: ${DateFormat('MMM dd, yyyy - hh:mm a').format(consultationDate.toDate())}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _viewConsultationNote(context, doc.id, data),
                          icon: const Icon(Icons.description),
                          label: const Text('View Notes'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _printConsultationNote(context, doc.id, data),
                          icon: const Icon(Icons.print),
                          label: const Text('Print'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple.shade700,
                          ),
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
                  _buildInfoRow('Name', data['patientName']),
                  _buildInfoRow('Patient ID', data['patientId']),
                ]),
                const SizedBox(height: 24),
                _buildSection('Doctor Information', [
                  _buildInfoRow('Doctor', data['assignedStaffName']),
                  _buildInfoRow('Department', data['department']),
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (noteData['symptoms'] != null &&
                            noteData['symptoms'].toString().isNotEmpty)
                          _buildNoteCard(
                            'Chief Complaint',
                            noteData['symptoms'],
                            Icons.sick,
                          ),
                        if (noteData['diagnosis'] != null &&
                            noteData['diagnosis'].toString().isNotEmpty)
                          _buildNoteCard(
                            'Diagnosis',
                            noteData['diagnosis'],
                            Icons.medical_services,
                          ),
                        if (noteData['treatment'] != null &&
                            noteData['treatment'].toString().isNotEmpty)
                          _buildNoteCard(
                            'Treatment Plan',
                            noteData['treatment'],
                            Icons.healing,
                          ),
                        if (noteData['prescription'] != null &&
                            noteData['prescription'].toString().isNotEmpty)
                          _buildNoteCard(
                            'Prescription',
                            noteData['prescription'],
                            Icons.medication,
                          ),
                        if (noteData['labTests'] != null &&
                            noteData['labTests'].toString().isNotEmpty)
                          _buildNoteCard(
                            'Lab Tests',
                            noteData['labTests'],
                            Icons.biotech,
                          ),
                        if (noteData['notes'] != null &&
                            noteData['notes'].toString().isNotEmpty)
                          _buildNoteCard(
                            'Additional Notes',
                            noteData['notes'],
                            Icons.note,
                          ),
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

  Widget _buildInfoRow(String label, String? value) {
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
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF printing feature will be implemented'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Consultation Note Form
class _ConsultationNoteForm extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;

  const _ConsultationNoteForm({
    required this.appointmentId,
    required this.appointmentData,
  });

  @override
  State<_ConsultationNoteForm> createState() => _ConsultationNoteFormState();
}

class _ConsultationNoteFormState extends State<_ConsultationNoteForm> {
  final _formKey = GlobalKey<FormState>();
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _prescriptionController = TextEditingController();
  final _labTestsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _prescriptionController.dispose();
    _labTestsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get user details
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();
      final staffName =
          userData?['fullName'] as String? ?? 'Medical Records Officer';
      final facilityId = userData?['facilityId'] as String?;

      // Get appointment fee and doctor details
      final appointmentDoc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .get();

      if (!appointmentDoc.exists) {
        throw Exception('Appointment not found');
      }

      final appointmentData = appointmentDoc.data()!;
      final consultationFee =
          (appointmentData['appointmentFee'] as num?)?.toDouble() ?? 5000.0;
      final patientId = appointmentData['patientId'] as String;
      final remoteDoctorId = appointmentData['doctorId'] as String;

      final consultationData = {
        'patientId': widget.appointmentData['patientId'],
        'patientName': widget.appointmentData['patientName'],
        'facilityId': facilityId,
        'staffId': currentUser.uid,
        'staffName': staffName,
        'appointmentId': widget.appointmentId,
        'symptoms': _symptomsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatment': _treatmentController.text.trim(),
        'prescription': _prescriptionController.text.trim(),
        'labTests': _labTestsController.text.trim(),
        'notes': _notesController.text.trim(),
        'consultationDate': Timestamp.now(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to health_records collection
      await FirebaseFirestore.instance
          .collection('health_records')
          .add(consultationData);

      // Process payment: Deduct from patient, credit remote doctor
      await _processRemoteConsultationPayment(
        patientId: patientId,
        remoteDoctorId: remoteDoctorId,
        consultationFee: consultationFee,
        appointmentData: appointmentData,
      );

      // Update appointment status to completed
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
            'consultationStatus': 'completed',
            'consultationDate': Timestamp.now(),
            'diagnosis': _diagnosisController.text.trim(),
            'completedAt': FieldValue.serverTimestamp(),
            'paymentStatus': 'paid',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consultation note saved successfully!\n₦${consultationFee.toStringAsFixed(2)} charged to patient',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processRemoteConsultationPayment({
    required String patientId,
    required String remoteDoctorId,
    required double consultationFee,
    required Map<String, dynamic> appointmentData,
  }) async {
    // Determine which wallet to use for the patient
    // Priority: household wallet > main wallet > facility_patients wallet
    String? householdId;
    bool useHouseholdWallet = false;
    bool useMainWallet = false;
    double walletBalance = 0;
    String actualWalletUserId = patientId;

    // Check if patient is part of a household
    final patientDoc = await FirebaseFirestore.instance
        .collection('facility_patients')
        .doc(patientId)
        .get();

    if (patientDoc.exists) {
      final patientData = patientDoc.data()!;
      householdId = patientData['householdId'] as String?;

      if (householdId != null && householdId.isNotEmpty) {
        // Check household wallet
        final householdWalletDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        if (householdWalletDoc.exists) {
          walletBalance =
              (householdWalletDoc.data()?['balance'] as num?)?.toDouble() ?? 0;
          useHouseholdWallet = true;
        }
      }
    }

    if (!useHouseholdWallet) {
      // Check main wallet (for remote/individual patients)
      // Try patient's userId first
      String? userId = patientDoc.data()?['userId'] as String?;

      if (userId != null && userId.isNotEmpty) {
        final mainWalletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(userId)
            .get();

        if (mainWalletDoc.exists) {
          walletBalance =
              (mainWalletDoc.data()?['balance'] as num?)?.toDouble() ?? 0;
          useMainWallet = true;
          actualWalletUserId = userId;
        }
      }

      // If not found, try with patientId directly
      if (!useMainWallet) {
        final mainWalletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(patientId)
            .get();

        if (mainWalletDoc.exists) {
          walletBalance =
              (mainWalletDoc.data()?['balance'] as num?)?.toDouble() ?? 0;
          useMainWallet = true;
          actualWalletUserId = patientId;
        }
      }
    }

    if (!useHouseholdWallet && !useMainWallet) {
      // Use facility_patients wallet as fallback
      walletBalance =
          (patientDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    }

    // Verify sufficient balance
    if (walletBalance < consultationFee) {
      throw Exception(
        'Insufficient wallet balance. Required: ₦${consultationFee.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
      );
    }

    // Deduct from patient wallet
    if (useHouseholdWallet && householdId != null) {
      await FirebaseFirestore.instance
          .collection('household_wallets')
          .doc(householdId)
          .update({'balance': FieldValue.increment(-consultationFee)});

      await FirebaseFirestore.instance
          .collection('household_wallets')
          .doc(householdId)
          .collection('transactions')
          .add({
            'type': 'debit',
            'amount': consultationFee,
            'description':
                'Remote consultation for ${appointmentData['patientName']} with Dr. ${appointmentData['doctorName']}',
            'patientId': patientId,
            'patientName': appointmentData['patientName'],
            'appointmentId': widget.appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } else if (useMainWallet) {
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(actualWalletUserId)
          .update({
            'balance': FieldValue.increment(-consultationFee),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(actualWalletUserId)
          .collection('transactions')
          .add({
            'type': 'debit',
            'amount': consultationFee,
            'description':
                'Remote consultation with Dr. ${appointmentData['doctorName']}',
            'appointmentId': widget.appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
            'balanceBefore': walletBalance,
            'balanceAfter': walletBalance - consultationFee,
            'status': 'completed',
          });
    } else {
      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .update({'walletBalance': FieldValue.increment(-consultationFee)});

      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .collection('transactions')
          .add({
            'type': 'debit',
            'amount': consultationFee,
            'description':
                'Remote consultation with Dr. ${appointmentData['doctorName']}',
            'appointmentId': widget.appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
          });
    }

    // Calculate revenue shares using dynamic config from Firestore
    // Get current percentages from fee configuration
    final remoteDoctorSharePercent =
        await FeeConfigService.getRemoteDoctorSharePercentage();
    final remoteFacilitySharePercent =
        await FeeConfigService.getRemoteFacilitySharePercentage();

    final doctorShare = consultationFee * (remoteDoctorSharePercent / 100);
    final facilityShare = consultationFee * (remoteFacilitySharePercent / 100);

    // Credit remote doctor's wallet
    await FirebaseFirestore.instance
        .collection('wallets')
        .doc(remoteDoctorId)
        .update({
          'balance': FieldValue.increment(doctorShare),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance
        .collection('wallets')
        .doc(remoteDoctorId)
        .collection('transactions')
        .add({
          'type': 'credit',
          'amount': doctorShare,
          'description':
              'Remote consultation fee from ${appointmentData['patientName']} (${remoteDoctorSharePercent.toStringAsFixed(0)}% share)',
          'patientId': patientId,
          'patientName': appointmentData['patientName'],
          'appointmentId': widget.appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });

    // Note: Admin share removed - facility already pays subscription fee
    // Credit facility wallet
    final facilityId = appointmentData['facilityId'];
    if (facilityId != null && facilityId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(facilityId)
          .update({
            'balance': FieldValue.increment(facilityShare),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(facilityId)
          .collection('transactions')
          .add({
            'type': 'credit',
            'amount': facilityShare,
            'description':
                'Remote consultation facility share from ${appointmentData['patientName']} (${remoteFacilitySharePercent.toStringAsFixed(0)}% share)',
            'patientId': patientId,
            'patientName': appointmentData['patientName'],
            'doctorId': remoteDoctorId,
            'doctorName': appointmentData['doctorName'],
            'appointmentId': widget.appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Consultation Note'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Info Card
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.teal.shade700),
                          const SizedBox(width: 8),
                          Text(
                            widget.appointmentData['patientName'] ??
                                'Unknown Patient',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (widget.appointmentData['appointmentDate'] != null)
                        Text(
                          'Appointment: ${DateFormat('MMM dd, yyyy - hh:mm a').format((widget.appointmentData['appointmentDate'] as Timestamp).toDate())}',
                        ),
                      if (widget.appointmentData['reason'] != null)
                        Text('Reason: ${widget.appointmentData['reason']}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Chief Complaint / Symptoms
              _buildTextField(
                controller: _symptomsController,
                label: 'Chief Complaint / Symptoms',
                icon: Icons.sick,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter symptoms';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Diagnosis
              _buildTextField(
                controller: _diagnosisController,
                label: 'Diagnosis',
                icon: Icons.medical_services,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter diagnosis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Treatment Plan
              _buildTextField(
                controller: _treatmentController,
                label: 'Treatment Plan',
                icon: Icons.healing,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Prescription
              _buildTextField(
                controller: _prescriptionController,
                label: 'Prescription',
                icon: Icons.medication,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Lab Tests
              _buildTextField(
                controller: _labTestsController,
                label: 'Lab Tests Recommended',
                icon: Icons.biotech,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Additional Notes
              _buildTextField(
                controller: _notesController,
                label: 'Additional Notes',
                icon: Icons.note,
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveConsultation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Save Consultation Note',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
}
