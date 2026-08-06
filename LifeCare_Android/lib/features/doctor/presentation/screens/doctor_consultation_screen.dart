import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../consultation/presentation/screens/consultation_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../utils/web_open_call_page_stub.dart'
    if (dart.library.js_interop) '../../../../utils/web_open_call_page_web.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/presentation/screens/messages_screen.dart';

// Confirmation dialog for mobile call - matches patient implementation
void _showCallConfirmationDialog(
  BuildContext parentContext,
  bool isVideo,
  String appointmentId,
  Map<String, dynamic> appointmentData,
) {
  final channelName =
      'appointment_${appointmentId.isNotEmpty ? appointmentId : 'unknown'}';
  debugPrint('🎯 Showing call confirmation dialog - isVideo: $isVideo');
  debugPrint('🎯 Channel: $channelName');

  // Capture the navigator BEFORE showing dialog
  final navigator = Navigator.of(parentContext);

  showDialog(
    context: parentContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Join Consultation'),
      content: Text(
        'Do you want to continue to the ${isVideo ? 'video' : 'audio'} call?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            debugPrint('❌ Call cancelled');
            Navigator.pop(dialogContext);
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            debugPrint('✅ Continue pressed - navigating to consultation');
            Navigator.pop(dialogContext);
            // Use the captured navigator instead of trying to get it from context
            navigator.push(
              MaterialPageRoute(
                builder: (context) => ConsultationScreen(
                  channelName: channelName,
                  isVideo: isVideo,
                  appointmentId: appointmentId,
                  otherParticipantId: appointmentData['patientId'],
                  otherParticipantName:
                      appointmentData['patientName'] ?? 'Patient',
                  otherParticipantRole: 'patient',
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
// ...existing code...

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.black87),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({super.key});

  @override
  State<DoctorConsultationScreen> createState() =>
      _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String doctorId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
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
        title: const Text('Doctor Consultations'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Consultation'),
            Tab(text: 'Completed Consultation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingConsultationTab(doctorId: doctorId),
          _CompletedConsultationTab(doctorId: doctorId),
        ],
      ),
    );
  }
}

class _PendingConsultationTab extends StatelessWidget {
  final String doctorId;
  const _PendingConsultationTab({required this.doctorId});

  Stream<QuerySnapshot> _buildPendingQuery(String doctorId) {
    final appointmentsQuery = FirebaseFirestore.instance
        .collection('appointments')
        .where('providerId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved');
    return appointmentsQuery.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildPendingQuery(doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pending consultations'));
        }

        // Filter out CHW appointments - only show patient appointments
        final allDocs = snapshot.data!.docs;
        final docs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Exclude appointments booked by CHW (check bookedByRole field or patientName contains CHW)
          final bookedByRole = data['bookedByRole'] ?? '';
          final patientName = (data['patientName'] ?? '')
              .toString()
              .toLowerCase();
          // If bookedByRole is 'chw' OR patientName contains 'chw', it's a CHW appointment
          return bookedByRole != 'chw' && !patientName.contains('chw');
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No pending patient consultations'),
                SizedBox(height: 8),
                Text(
                  'CHW consultations are in the "CHW Consultations" tab',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final appointment = doc.data() as Map<String, dynamic>;
            appointment['id'] = doc.id;
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(Icons.person, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Text(
                          appointment['patientName'] ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            label: const Text('Start Consultation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (context) => Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                          Icons.chat,
                                          color: Colors.indigo,
                                        ),
                                        title: const Text('Text Chat'),
                                        subtitle: const Text(
                                          'Open messaging system',
                                        ),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final doctorId =
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid ??
                                              '';
                                          final doctorName =
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.displayName ??
                                              'Doctor';
                                          final conversationId =
                                              await MessageService.createOrGetConversation(
                                                user1Id: doctorId,
                                                user1Name: doctorName,
                                                user1Role: 'doctor',
                                                user2Id:
                                                    appointment['patientId'],
                                                user2Name:
                                                    appointment['patientName'] ??
                                                    'Unknown Patient',
                                                user2Role: 'patient',
                                              );
                                          // ...existing code...
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MessagesScreen(),
                                              settings: RouteSettings(
                                                arguments: {
                                                  'conversationId':
                                                      conversationId,
                                                  'patientName':
                                                      appointment['patientName'],
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.videocam,
                                          color: Colors.indigo,
                                        ),
                                        title: const Text('Video Call'),
                                        subtitle: const Text(
                                          'Start video consultation',
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          if (kIsWeb) {
                                            openWebCallPage(
                                              channelName:
                                                  'appointment_${appointment['id'] ?? appointment['appointmentId'] ?? 'unknown'}',
                                              isVideo: true,
                                              userName:
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.displayName ??
                                                  'Doctor',
                                              userRole: 'doctor',
                                              uid: FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid,
                                            );
                                          } else {
                                            debugPrint(
                                              '📱 Video call clicked - mobile platform',
                                            );
                                            _showCallConfirmationDialog(
                                              context,
                                              true,
                                              appointment['id'] ??
                                                  appointment['appointmentId'] ??
                                                  '',
                                              appointment,
                                            );
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.call,
                                          color: Colors.indigo,
                                        ),
                                        title: const Text('Audio Call'),
                                        subtitle: const Text(
                                          'Start audio consultation',
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          if (kIsWeb) {
                                            openWebCallPage(
                                              channelName:
                                                  'appointment_${appointment['id'] ?? appointment['appointmentId'] ?? 'unknown'}',
                                              isVideo: false,
                                              userName:
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.displayName ??
                                                  'Doctor',
                                              userRole: 'doctor',
                                              uid: FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.uid,
                                            );
                                          } else {
                                            _showCallConfirmationDialog(
                                              context,
                                              false,
                                              appointment['id'] ??
                                                  appointment['appointmentId'] ??
                                                  '',
                                              appointment,
                                            );
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.local_hospital,
                                          color: Colors.teal,
                                        ),
                                        title: const Text('Physical'),
                                        subtitle: const Text(
                                          'Clinic-based consultation',
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DoctorConsultationDetailScreen(
                                                    appointment: appointment,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(
                                          Icons.note_add,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Add Consultation Note',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DoctorConsultationDetailScreen(
                                                    appointment: appointment,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 0),
                          IconButton(
                            icon: const Icon(
                              Icons.note_add,
                              color: Colors.indigo,
                              size: 22,
                            ),
                            tooltip: 'Add Clinical Note',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DoctorConsultationDetailScreen(
                                        appointment: appointment,
                                      ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 0),
                          IconButton(
                            icon: const Icon(
                              Icons.chat,
                              color: Colors.indigo,
                              size: 22,
                            ),
                            tooltip: 'Chat with Patient',
                            onPressed: () async {
                              final doctorId =
                                  FirebaseAuth.instance.currentUser?.uid ?? '';
                              final doctorName =
                                  FirebaseAuth
                                      .instance
                                      .currentUser
                                      ?.displayName ??
                                  'Doctor';
                              final conversationId =
                                  await MessageService.createOrGetConversation(
                                    user1Id: doctorId,
                                    user1Name: doctorName,
                                    user1Role: 'doctor',
                                    user2Id: appointment['patientId'],
                                    user2Name:
                                        appointment['patientName'] ??
                                        'Unknown Patient',
                                    user2Role: 'patient',
                                  );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const MessagesScreen(),
                                  settings: RouteSettings(
                                    arguments: {
                                      'conversationId': conversationId,
                                      'patientName': appointment['patientName'],
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 0),
                          IconButton(
                            icon: const Icon(
                              Icons.info,
                              color: Colors.indigo,
                              size: 28,
                            ),
                            tooltip: 'View Details',
                            onPressed: () async {
                              final patientId = appointment['patientId'];
                              if (patientId == null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => const AlertDialog(
                                    title: Text('No Patient ID'),
                                    content: Text(
                                      'No patient ID found for this appointment.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              // Fetch latest health record for this patient (any type)
                              final query = await FirebaseFirestore.instance
                                  .collection('health_records')
                                  .where('patientId', isEqualTo: patientId)
                                  .orderBy('timestamp', descending: true)
                                  .limit(1)
                                  .get();
                              if (query.docs.isEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (context) => const AlertDialog(
                                    title: Text('No Health Record Found'),
                                    content: Text(
                                      'No health record found for this patient.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final record = query.docs.first.data();

                              // Helper function to format dates
                              String formatDate(dynamic dateValue) {
                                if (dateValue == null) return 'N/A';
                                try {
                                  DateTime date;
                                  if (dateValue is Timestamp) {
                                    date = dateValue.toDate();
                                  } else if (dateValue is String) {
                                    date = DateTime.parse(dateValue);
                                  } else {
                                    return dateValue.toString();
                                  }
                                  return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                } catch (e) {
                                  return dateValue.toString();
                                }
                              }

                              // Helper to extract data from nested maps
                              Map<String, dynamic> extractData(
                                Map<String, dynamic> record,
                              ) {
                                final extracted = <String, dynamic>{};

                                record.forEach((key, value) {
                                  final k = key.toLowerCase();

                                  // Skip system fields
                                  if (k == 'timestamp' ||
                                      k == 'createdat' ||
                                      k == 'updatedat' ||
                                      k == 'appointmentid' ||
                                      k == 'patientid' ||
                                      k == 'prescribedat' ||
                                      k == 'requestedat' ||
                                      k == 'userid' ||
                                      k == 'recordid' ||
                                      k == 'id' ||
                                      k == 'source' ||
                                      k == 'status' ||
                                      k == 'fileurls' ||
                                      k == 'filenames' ||
                                      k == 'uploaddate' ||
                                      k == 'submissiontimestamp' ||
                                      k == 'requiresreview' ||
                                      k == 'accessibleby' ||
                                      k == 'iseditable' ||
                                      k == 'isdeletable' ||
                                      k == 'data') {
                                    // Skip the 'data' wrapper
                                    return;
                                  }

                                  extracted[key] = value;
                                });

                                // If there's a nested 'data' field, extract its contents
                                if (record['data'] is Map) {
                                  final nestedData =
                                      record['data'] as Map<String, dynamic>;
                                  nestedData.forEach((key, value) {
                                    if (value != null &&
                                        value.toString().isNotEmpty) {
                                      extracted[key] = value;
                                    }
                                  });
                                }

                                return extracted;
                              }

                              // Extract all data (including nested)
                              final allData = extractData(record);

                              // Organize data into sections
                              final patientInfo = <String, dynamic>{};
                              final medicalInfo = <String, dynamic>{};
                              final treatmentInfo = <String, dynamic>{};
                              final otherInfo = <String, dynamic>{};

                              allData.forEach((key, value) {
                                final k = key.toLowerCase();
                                if (k.contains('patient') ||
                                    k == 'name' ||
                                    k == 'age' ||
                                    k == 'sex' ||
                                    k == 'phone' ||
                                    k == 'address') {
                                  patientInfo[key] = value;
                                } else if (k.contains('vital') ||
                                    k == 'bloodpressure' ||
                                    k == 'temperature' ||
                                    k == 'pulse' ||
                                    k == 'weight' ||
                                    k == 'height') {
                                  medicalInfo[key] = value;
                                } else if (k.contains('prescription') ||
                                    k.contains('laboratory') ||
                                    k.contains('radiology') ||
                                    k == 'diagnosis' ||
                                    k == 'notes') {
                                  treatmentInfo[key] = value;
                                } else {
                                  otherInfo[key] = value;
                                }
                              });

                              String formatLabel(String key) {
                                final k = key.toString().replaceAll('_', ' ');
                                return k.isNotEmpty
                                    ? (k[0].toUpperCase() + k.substring(1))
                                    : k;
                              }

                              Widget buildSection(
                                String title,
                                Map<String, dynamic> data,
                                IconData icon,
                                Color color,
                              ) {
                                if (data.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(icon, size: 20, color: color),
                                        const SizedBox(width: 8),
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...data.entries
                                        .where(
                                          (entry) =>
                                              entry.value != null &&
                                              entry.value.toString().isNotEmpty,
                                        )
                                        .map((entry) {
                                          final value = entry.value;
                                          String displayValue;

                                          if (entry.key.toLowerCase() ==
                                                  'prescriptions' &&
                                              value is List) {
                                            displayValue = value
                                                .map((e) {
                                                  if (e is Map &&
                                                      e.containsKey('name')) {
                                                    return e['name'];
                                                  }
                                                  return e.toString();
                                                })
                                                .join(', ');
                                          } else if (entry.key.toLowerCase() ==
                                                  'laboratoryinvestigations' &&
                                              value is List) {
                                            displayValue = value
                                                .map((e) {
                                                  if (e is Map &&
                                                      e.containsKey('name')) {
                                                    return e['name'];
                                                  }
                                                  return e.toString();
                                                })
                                                .join(', ');
                                          } else if (value is Timestamp) {
                                            displayValue = formatDate(value);
                                          } else {
                                            displayValue = value.toString();
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    formatLabel(entry.key),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    displayValue,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                    const Divider(height: 24),
                                  ],
                                );
                              }

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Row(
                                      children: [
                                        const Icon(
                                          Icons.medical_services,
                                          color: Colors.indigo,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('Health Record'),
                                      ],
                                    ),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Record Date
                                            if (record['timestamp'] != null)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Colors
                                                          .indigo
                                                          .shade700,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Record Date: ${formatDate(record['timestamp'])}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .indigo
                                                            .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 16),

                                            buildSection(
                                              'Patient Information',
                                              patientInfo,
                                              Icons.person,
                                              Colors.blue.shade700,
                                            ),
                                            buildSection(
                                              'Vital Signs',
                                              medicalInfo,
                                              Icons.favorite,
                                              Colors.red.shade700,
                                            ),
                                            buildSection(
                                              'Treatment & Diagnosis',
                                              treatmentInfo,
                                              Icons.medication,
                                              Colors.green.shade700,
                                            ),
                                            buildSection(
                                              'Additional Information',
                                              otherInfo,
                                              Icons.info,
                                              Colors.orange.shade700,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.indigo,
                                        ),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          appointment['appointmentDate'] != null
                              ? appointment['appointmentDate'].toString().split(
                                  ' ',
                                )[0]
                              : '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (appointment['reason'] != null &&
                        appointment['reason'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appointment['reason'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _CompletedConsultationTab extends StatelessWidget {
  final String doctorId;
  const _CompletedConsultationTab({required this.doctorId});

  Stream<QuerySnapshot> _buildCompletedQuery(String doctorId) {
    return FirebaseFirestore.instance
        .collection('health_records')
        .where('providerId', isEqualTo: doctorId)
        .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
        .where('status', isEqualTo: 'completed')
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildCompletedQuery(doctorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No completed consultations'));
        }
        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final record = docs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.indigo.shade700),
                        const SizedBox(width: 8),
                        Text(
                          record['patientName'] ?? 'Unknown Patient',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Consultation Details'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow(
                                          'Patient Name',
                                          record['patientName'] ?? 'Unknown',
                                        ),
                                        _buildInfoRow(
                                          'Age',
                                          record['age']?.toString() ??
                                              'Not provided',
                                        ),
                                        _buildInfoRow(
                                          'Sex',
                                          record['sex'] ?? 'Not provided',
                                        ),
                                        _buildInfoRow(
                                          'Phone',
                                          record['phone'] ?? 'Not provided',
                                        ),
                                        _buildInfoRow(
                                          'Address',
                                          record['address'] ?? 'Not provided',
                                        ),
                                        _buildInfoRow(
                                          'Appointment Date',
                                          record['appointmentDate']
                                                  ?.toString() ??
                                              'Not provided',
                                        ),
                                        if (record['referralReason'] != null &&
                                            record['referralReason']
                                                .toString()
                                                .isNotEmpty)
                                          _buildInfoRow(
                                            'Referral Reason',
                                            record['referralReason'],
                                          ),
                                        if (record['reason'] != null &&
                                            record['reason']
                                                .toString()
                                                .isNotEmpty)
                                          _buildInfoRow(
                                            'Consultation Reason',
                                            record['reason'],
                                          ),
                                        const Divider(),
                                        _buildInfoRow(
                                          'Clinical Notes',
                                          record['clinicalNotes'] ?? '',
                                        ),
                                        _buildInfoRow(
                                          'Diagnosis',
                                          record['diagnosis'] ?? '',
                                        ),
                                        if (record['prescriptions'] != null &&
                                            (record['prescriptions'] as List)
                                                .isNotEmpty)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Prescriptions:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              ...List<String>.from(
                                                record['prescriptions'],
                                              ).map(
                                                (med) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8.0,
                                                        top: 2.0,
                                                      ),
                                                  child: Text(med),
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (record['labRequests'] != null &&
                                            (record['labRequests'] as List)
                                                .isNotEmpty)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Lab Requests:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              ...List<String>.from(
                                                record['labRequests'],
                                              ).map(
                                                (lab) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8.0,
                                                        top: 2.0,
                                                      ),
                                                  child: Text(lab),
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (record['radiologyRequests'] !=
                                                null &&
                                            (record['radiologyRequests']
                                                    as List)
                                                .isNotEmpty)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text(
                                                'Radiology Requests:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              ...List<String>.from(
                                                record['radiologyRequests'],
                                              ).map(
                                                (rad) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8.0,
                                                        top: 2.0,
                                                      ),
                                                  child: Text(rad),
                                                ),
                                              ),
                                            ],
                                          ),
                                        _buildInfoRow(
                                          'Follow-up',
                                          record['followUp'] ?? '',
                                        ),
                                        _buildInfoRow(
                                          'Other Notes',
                                          record['notes'] ?? '',
                                        ),
                                        const Divider(),
                                        _buildInfoRow(
                                          'Signed by',
                                          record['providerName'] ?? '',
                                        ),
                                        _buildInfoRow(
                                          'Provider ID',
                                          record['providerId'] ?? '',
                                        ),
                                        _buildInfoRow(
                                          'Date',
                                          record['date']?.toString().split(
                                                ' ',
                                              )[0] ??
                                              '',
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          record['date'] != null
                              ? record['date'].toString().split(' ')[0]
                              : '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (record['reason'] != null &&
                        record['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              record['reason'],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class DoctorConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final bool readOnly;
  const DoctorConsultationDetailScreen({
    super.key,
    required this.appointment,
    this.readOnly = false,
  });

  @override
  State<DoctorConsultationDetailScreen> createState() =>
      _DoctorConsultationDetailScreenState();
}

class _DoctorConsultationDetailScreenState
    extends State<DoctorConsultationDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _clinicalNotesController;
  late TextEditingController _diagnosisController;
  late TextEditingController _followUpController;
  late TextEditingController _otherPrescriptionController;
  late TextEditingController _otherLabController;
  late TextEditingController _otherRadiologyController;
  List<String> selectedPrescriptions = [];
  List<String> selectedLabs = [];
  List<String> selectedRadiology = [];

  // AI Analysis State
  String _aiSymptomInterpretation = '';
  String _aiDiagnosticSuggestions = '';
  List<String> _aiRecommendedTests = [];
  bool _showAIAlert = false;
  String _aiAlertMessage = '';
  Color _aiAlertColor = Colors.orange;
  bool _isAnalyzingSymptoms = false;

  final List<String> prescriptionOptions = [
    'Paracetamol',
    'Amoxicillin',
    'Ibuprofen',
    'Metformin',
    'Lisinopril',
    'Ciprofloxacin',
    'Azithromycin',
    'Omeprazole',
    'Amlodipine',
    'Losartan',
    'Atorvastatin',
    'Cetirizine',
    'Salbutamol',
    'Hydrochlorothiazide',
    // Antimalarial medications (sub-Saharan Africa)
    'Artemether-Lumefantrine',
    'Artesunate',
    'Quinine',
    'Dihydroartemisinin-Piperaquine',
    'Sulfadoxine-Pyrimethamine',
    'Chloroquine',
    'Primaquine',
    'Mefloquine',
    'Other',
  ];
  final List<String> labOptions = [
    'CBC',
    'Blood Sugar',
    'Lipid Profile',
    'Malaria Test',
    'Urinalysis',
    'Electrolytes',
    'Liver Function Test',
    'Renal Function Test',
    'HIV Test',
    'Pregnancy Test',
    'Thyroid Function Test',
    'Other',
  ];
  final List<String> radiologyOptions = [
    'Chest X-ray',
    'Abdominal Ultrasound',
    'CT Scan',
    'MRI',
    'Pelvic Ultrasound',
    'Mammography',
    'Echocardiogram',
    'Bone X-ray',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _clinicalNotesController = TextEditingController(
      text: widget.appointment['clinicalNotes'] ?? '',
    );
    _diagnosisController = TextEditingController(
      text: widget.appointment['diagnosis'] ?? '',
    );
    _followUpController = TextEditingController(
      text: widget.appointment['followUp'] ?? '',
    );
    _otherPrescriptionController = TextEditingController();
    _otherLabController = TextEditingController();
    _otherRadiologyController = TextEditingController();
    selectedPrescriptions = List<String>.from(
      widget.appointment['prescriptions'] ?? [],
    );
    selectedLabs = List<String>.from(widget.appointment['labRequests'] ?? []);
    selectedRadiology = List<String>.from(
      widget.appointment['radiologyRequests'] ?? [],
    );
  }

  @override
  void dispose() {
    _clinicalNotesController.dispose();
    _diagnosisController.dispose();
    _followUpController.dispose();
    _otherPrescriptionController.dispose();
    _otherLabController.dispose();
    _otherRadiologyController.dispose();
    super.dispose();
  }

  /// AI-powered symptom analysis for clinical decision support
  Future<void> _analyzeSymptoms() async {
    final symptoms = _clinicalNotesController.text.trim();

    if (symptoms.isEmpty || symptoms.length < 10) {
      setState(() {
        _aiSymptomInterpretation = '';
        _aiDiagnosticSuggestions = '';
        _aiRecommendedTests = [];
        _showAIAlert = false;
      });
      return;
    }

    setState(() => _isAnalyzingSymptoms = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final symptomsLower = symptoms.toLowerCase();
      final interpretations = <String>[];
      final suggestions = <String>[];
      final tests = <String>[];
      bool isUrgent = false;
      String alertMessage = '';
      Color alertColor = Colors.orange;

      // Critical symptoms requiring immediate attention
      if (symptomsLower.contains('chest pain') ||
          symptomsLower.contains('heart attack')) {
        interpretations.add(
          '⚠️ CARDIAC EVENT SUSPECTED - Immediate evaluation required',
        );
        suggestions.add('Rule out acute coronary syndrome');
        tests.addAll(['ECG', 'Cardiac Enzymes', 'Chest X-ray']);
        isUrgent = true;
        alertMessage =
            'URGENT: Possible cardiac event - Immediate intervention required';
        alertColor = Colors.red.shade700;
      }

      if (symptomsLower.contains('difficulty breathing') ||
          symptomsLower.contains('shortness of breath')) {
        interpretations.add(
          '🫁 RESPIRATORY DISTRESS - Urgent assessment needed',
        );
        suggestions.add(
          'Evaluate for pneumonia, asthma, or pulmonary embolism',
        );
        tests.addAll(['Chest X-ray', 'Pulse Oximetry', 'ABG']);
        isUrgent = true;
        alertMessage = alertMessage.isEmpty
            ? 'URGENT: Respiratory distress requires immediate attention'
            : alertMessage;
        alertColor = Colors.red.shade700;
      }

      // Infectious diseases common in sub-Saharan Africa
      if (symptomsLower.contains('fever')) {
        interpretations.add('🌡️ Febrile illness detected');

        if (symptomsLower.contains('malaria') ||
            symptomsLower.contains('chills')) {
          suggestions.add('Malaria screening recommended');
          tests.add('Malaria Test');
        }

        if (symptomsLower.contains('cough') || symptomsLower.contains('tb')) {
          suggestions.add('Consider tuberculosis screening');
          tests.addAll(['Chest X-ray', 'Sputum Test']);
        }

        tests.addAll(['CBC', 'Blood Sugar']);
      }

      // Gastrointestinal symptoms
      if (symptomsLower.contains('diarrhea') ||
          symptomsLower.contains('vomiting')) {
        interpretations.add(
          '💧 Gastrointestinal symptoms - Monitor hydration status',
        );
        suggestions.add('Assess for dehydration and electrolyte imbalance');
        tests.addAll(['Electrolytes', 'Stool Analysis']);

        if (symptomsLower.contains('blood')) {
          isUrgent = true;
          alertMessage =
              'WARNING: GI bleeding suspected - Urgent evaluation needed';
          alertColor = Colors.red.shade700;
        }
      }

      // Neurological symptoms
      if (symptomsLower.contains('headache') &&
          symptomsLower.contains('severe')) {
        interpretations.add('🧠 Severe headache - Rule out serious causes');
        suggestions.add(
          'Evaluate for meningitis, hypertension, or intracranial pathology',
        );
        tests.addAll(['Blood Pressure', 'CT Scan']);
      }

      // Metabolic conditions
      if (symptomsLower.contains('diabetes') ||
          symptomsLower.contains('sugar')) {
        interpretations.add('🩸 Diabetes-related symptoms');
        suggestions.add('Monitor blood glucose and assess for complications');
        tests.addAll(['Blood Sugar', 'HbA1c']);
      }

      // Pregnancy-related
      if (symptomsLower.contains('pregnant') ||
          symptomsLower.contains('pregnancy')) {
        interpretations.add('🤰 Pregnancy-related consultation');
        suggestions.add('Ensure appropriate antenatal care');
        tests.add('Pregnancy Test');
      }

      // Set AI analysis results
      setState(() {
        _aiSymptomInterpretation = interpretations.join('\n');
        _aiDiagnosticSuggestions = suggestions.join('\n• ');
        _aiRecommendedTests = tests;
        _showAIAlert = isUrgent;
        _aiAlertMessage = alertMessage;
        _aiAlertColor = alertColor;
      });
    } finally {
      setState(() => _isAnalyzingSymptoms = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final doctorName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
      final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final patientId = widget.appointment['patientId'] ?? '';
      final now = DateTime.now();
      // Get the appointment ID for linking health record
      final appointmentId =
          widget.appointment['id'] ?? widget.appointment['appointmentId'];

      final recordData = {
        'appointmentId': appointmentId, // CRITICAL: Link to appointment
        'patientId': patientId,
        'patientUid': patientId,
        'patientName': widget.appointment['patientName'] ?? '',
        'providerId': doctorId,
        'providerName': doctorName,
        'providerType': 'Doctor',
        'type': 'DOCTOR_CONSULTATION',
        'department':
            'Out-Patient Department (OPD)', // REQUIRED for firestore rules
        'facilityId': widget.appointment['facilityId'], // Add facility context
        'date': now,
        'timestamp': now,
        'clinicalNotes': _clinicalNotesController.text,
        'diagnosis': _diagnosisController.text,
        'prescriptions': [
          ...selectedPrescriptions.where((p) => p != 'Other'),
          if (selectedPrescriptions.contains('Other') &&
              _otherPrescriptionController.text.isNotEmpty)
            _otherPrescriptionController.text,
        ],
        'labRequests': [
          ...selectedLabs.where((l) => l != 'Other'),
          if (selectedLabs.contains('Other') &&
              _otherLabController.text.isNotEmpty)
            _otherLabController.text,
        ],
        'radiologyRequests': [
          ...selectedRadiology.where((r) => r != 'Other'),
          if (selectedRadiology.contains('Other') &&
              _otherRadiologyController.text.isNotEmpty)
            _otherRadiologyController.text,
        ],
        'followUp': _followUpController.text,
        'notes': widget.appointment['notes'] ?? '',
        'status': 'completed',
        'createdAt': now,
        'updatedAt': now,
      };
      try {
        await FirebaseFirestore.instance
            .collection('health_records')
            .add(recordData);

        // Update appointment status
        String? appointmentId =
            widget.appointment['id'] ?? widget.appointment['appointmentId'];

        if (widget.appointment['id'] != null) {
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(widget.appointment['id'])
              .update({
                'status': 'completed',
                'completedAt': FieldValue.serverTimestamp(),
                'consultationCompletedDate': now,
              });
        } else if (widget.appointment['appointmentId'] != null) {
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(widget.appointment['appointmentId'])
              .update({
                'status': 'completed',
                'completedAt': FieldValue.serverTimestamp(),
                'consultationCompletedDate': now,
              });
        }

        // Process payment for referral consultations (70/30 split)
        if (widget.appointment['referralId'] != null &&
            widget.appointment['paymentStatus'] == 'paid') {
          try {
            final consultationFee =
                (widget.appointment['consultationFee'] ?? 3000.0) as num;
            final doctorShare = consultationFee * 0.70; // 70%
            final platformShare = consultationFee * 0.30; // 30%
            final doctorId =
                widget.appointment['doctorId'] ??
                widget.appointment['providerId'];
            final doctorName =
                widget.appointment['doctorName'] ??
                widget.appointment['providerName'];

            if (doctorId != null) {
              // Credit doctor wallet
              await FirebaseFirestore.instance
                  .collection('doctor_wallets')
                  .doc(doctorId)
                  .set({
                    'balance': FieldValue.increment(doctorShare),
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'transactions': FieldValue.arrayUnion([
                      {
                        'type': 'credit',
                        'amount': doctorShare,
                        'description': 'Referral consultation payment (70%)',
                        'timestamp': Timestamp.fromDate(now),
                        'appointmentId': appointmentId,
                        'referralId': widget.appointment['referralId'],
                        'patientId': widget.appointment['patientId'],
                        'patientName': widget.appointment['patientName'],
                      },
                    ]),
                  }, SetOptions(merge: true));

              // Credit platform wallet
              await FirebaseFirestore.instance
                  .collection('platform_wallet')
                  .doc('main')
                  .set({
                    'balance': FieldValue.increment(platformShare),
                    'lastUpdated': FieldValue.serverTimestamp(),
                    'transactions': FieldValue.arrayUnion([
                      {
                        'type': 'credit',
                        'amount': platformShare,
                        'description':
                            'Referral consultation platform fee (30%)',
                        'timestamp': Timestamp.fromDate(now),
                        'appointmentId': appointmentId,
                        'referralId': widget.appointment['referralId'],
                        'doctorId': doctorId,
                        'doctorName': doctorName,
                      },
                    ]),
                  }, SetOptions(merge: true));

              print(
                '💰 Payment processed: Doctor ₦${doctorShare.toStringAsFixed(2)}, Platform ₦${platformShare.toStringAsFixed(2)}',
              );

              // Mark payment as processed in appointment
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .update({
                    'paymentStatus': 'processed',
                    'paymentProcessedAt': FieldValue.serverTimestamp(),
                    'doctorPaid': doctorShare,
                    'platformFee': platformShare,
                  });
            }
          } catch (paymentError) {
            print('⚠️ Payment processing error: $paymentError');
            // Don't fail the consultation save if payment processing fails
          }
        }

        // Process payment for facility-booked remote doctor appointments (70% doctor, 30% facility)
        if (widget.appointment['doctorType'] == 'remote' &&
            widget.appointment['bookedBy'] == 'medical_records' &&
            widget.appointment['paymentStatus'] == 'pending' &&
            widget.appointment['appointmentFee'] != null) {
          try {
            final appointmentFee = (widget.appointment['appointmentFee'] as num)
                .toDouble();
            final doctorShare = appointmentFee * 0.70; // 70% to remote doctor
            final facilityShare = appointmentFee * 0.30; // 30% to facility
            final doctorId =
                widget.appointment['doctorId'] ??
                widget.appointment['providerId'];
            final facilityId = widget.appointment['facilityId'];
            final patientId = widget.appointment['patientId'];
            final patientName =
                widget.appointment['patientName'] ?? 'Unknown Patient';

            print(
              '💰 [FacilityRemotePayment] Processing payment for facility-booked remote appointment',
            );
            print(
              '💰 [FacilityRemotePayment] Total fee: ₦${appointmentFee.toStringAsFixed(2)}',
            );
            print(
              '💰 [FacilityRemotePayment] Doctor share (70%): ₦${doctorShare.toStringAsFixed(2)}',
            );
            print(
              '💰 [FacilityRemotePayment] Facility share (30%): ₦${facilityShare.toStringAsFixed(2)}',
            );

            if (doctorId != null && facilityId != null && patientId != null) {
              // Get patient wallet info to determine which wallet to deduct from
              final appointmentDoc = await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .get();

              final appointmentData = appointmentDoc.data();
              final walletType = appointmentData?['walletType'] ?? 'individual';
              final walletId = appointmentData?['walletId'];

              if (walletId == null) {
                throw Exception('Wallet ID not found in appointment');
              }

              // Deduct from patient wallet (household or individual)
              if (walletType == 'household') {
                final walletRef = FirebaseFirestore.instance
                    .collection('household_wallets')
                    .doc(walletId);

                final walletDoc = await walletRef.get();
                final currentBalance =
                    (walletDoc.data()?['balance'] ?? 0.0) as num;

                if (currentBalance < appointmentFee) {
                  throw Exception('Insufficient wallet balance');
                }

                await walletRef.collection('transactions').add({
                  'type': 'debit',
                  'amount': appointmentFee,
                  'description':
                      'Remote doctor consultation fee for $patientName',
                  'patientId': patientId,
                  'patientName': patientName,
                  'doctorId': doctorId,
                  'facilityId': facilityId,
                  'appointmentId': appointmentId,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'completed',
                });

                await walletRef.update({
                  'balance': FieldValue.increment(-appointmentFee),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
              } else {
                // Individual wallet
                final walletRef = FirebaseFirestore.instance
                    .collection('wallets')
                    .doc(walletId);

                final walletDoc = await walletRef.get();
                final currentBalance =
                    (walletDoc.data()?['balance'] ?? 0.0) as num;

                if (currentBalance < appointmentFee) {
                  throw Exception('Insufficient wallet balance');
                }

                await walletRef.collection('transactions').add({
                  'type': 'debit',
                  'amount': appointmentFee,
                  'description': 'Remote doctor consultation fee',
                  'doctorId': doctorId,
                  'facilityId': facilityId,
                  'appointmentId': appointmentId,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'completed',
                });

                await walletRef.update({
                  'balance': FieldValue.increment(-appointmentFee),
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
              }

              // Credit remote doctor wallet (70%)
              await FirebaseFirestore.instance
                  .collection('wallets')
                  .doc(doctorId)
                  .set({
                    'balance': FieldValue.increment(doctorShare),
                    'lastUpdated': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

              await FirebaseFirestore.instance
                  .collection('wallets')
                  .doc(doctorId)
                  .collection('transactions')
                  .add({
                    'type': 'credit',
                    'amount': doctorShare,
                    'description':
                        'Remote consultation payment (70%) - $patientName',
                    'patientId': patientId,
                    'patientName': patientName,
                    'facilityId': facilityId,
                    'appointmentId': appointmentId,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'completed',
                  });

              // Credit facility wallet (30%)
              await FirebaseFirestore.instance
                  .collection('wallets')
                  .doc(facilityId)
                  .set({
                    'balance': FieldValue.increment(facilityShare),
                    'lastUpdated': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

              await FirebaseFirestore.instance
                  .collection('wallets')
                  .doc(facilityId)
                  .collection('transactions')
                  .add({
                    'type': 'credit',
                    'amount': facilityShare,
                    'description':
                        'Facility fee (30%) from remote consultation - $patientName',
                    'patientId': patientId,
                    'patientName': patientName,
                    'doctorId': doctorId,
                    'appointmentId': appointmentId,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'completed',
                  });

              print('✅ [FacilityRemotePayment] Payment processed successfully');
              print(
                '✅ [FacilityRemotePayment] Patient wallet debited: ₦${appointmentFee.toStringAsFixed(2)}',
              );
              print(
                '✅ [FacilityRemotePayment] Doctor credited: ₦${doctorShare.toStringAsFixed(2)}',
              );
              print(
                '✅ [FacilityRemotePayment] Facility credited: ₦${facilityShare.toStringAsFixed(2)}',
              );

              // Mark payment as processed in appointment
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .update({
                    'paymentStatus': 'paid',
                    'paymentProcessedAt': FieldValue.serverTimestamp(),
                    'doctorPaid': doctorShare,
                    'facilityFee': facilityShare,
                  });
            }
          } catch (paymentError) {
            print(
              '❌ [FacilityRemotePayment] Payment processing error: $paymentError',
            );
            // Don't fail the consultation save if payment processing fails
            // But show a warning to the doctor
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '⚠️ Consultation saved but payment processing failed: $paymentError',
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation note saved to health records!'),
          ),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving note: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
    final readOnly = widget.readOnly;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Details'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('Patient Information', [
                _buildInfoRow(
                  'Name',
                  widget.appointment['patientName'] ?? 'Unknown',
                ),
                _buildInfoRow(
                  'Age',
                  widget.appointment['age']?.toString() ?? 'Not provided',
                ),
                _buildInfoRow(
                  'Sex',
                  widget.appointment['sex'] ?? 'Not provided',
                ),
                _buildInfoRow(
                  'Phone',
                  widget.appointment['phone'] ?? 'Not provided',
                ),
                _buildInfoRow(
                  'Address',
                  widget.appointment['address'] ?? 'Not provided',
                ),
                _buildInfoRow(
                  'Appointment Date',
                  widget.appointment['appointmentDate']?.toString() ??
                      'Not provided',
                ),
                _buildInfoRow(
                  'Appointment Type',
                  (widget.appointment['referralReason'] != null &&
                          widget.appointment['referralReason']
                              .toString()
                              .isNotEmpty)
                      ? 'Referred'
                      : 'Regular',
                ),
                if (widget.appointment['referralReason'] != null &&
                    widget.appointment['referralReason'].toString().isNotEmpty)
                  _buildInfoRow(
                    'Referral Reason',
                    widget.appointment['referralReason'],
                  ),
              ]),
              _buildSection('Clinical Notes', [
                // AI Alert Banner
                if (_showAIAlert && !readOnly)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _aiAlertColor.withOpacity(0.1),
                      border: Border.all(color: _aiAlertColor, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: _aiAlertColor,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _aiAlertMessage,
                            style: TextStyle(
                              color: _aiAlertColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                TextFormField(
                  controller: _clinicalNotesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Enter clinical notes and symptoms',
                    border: const OutlineInputBorder(),
                    suffixIcon: !readOnly
                        ? IconButton(
                            icon: _isAnalyzingSymptoms
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.psychology,
                                    color: Colors.purple,
                                  ),
                            tooltip: 'AI Analysis',
                            onPressed: _isAnalyzingSymptoms
                                ? null
                                : _analyzeSymptoms,
                          )
                        : null,
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Clinical notes required'
                      : null,
                  enabled: !readOnly,
                  readOnly: readOnly,
                  onChanged: !readOnly ? (_) => _analyzeSymptoms() : null,
                ),

                // AI Analysis Results
                if (_aiSymptomInterpretation.isNotEmpty && !readOnly) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      border: Border.all(color: Colors.purple.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              color: Colors.purple.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Clinical Decision Support',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (_aiSymptomInterpretation.isNotEmpty) ...[
                          Text(
                            'Symptom Interpretation:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _aiSymptomInterpretation,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_aiDiagnosticSuggestions.isNotEmpty) ...[
                          Text(
                            'Diagnostic Considerations:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• $_aiDiagnosticSuggestions',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_aiRecommendedTests.isNotEmpty) ...[
                          Text(
                            'Recommended Tests:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade900,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _aiRecommendedTests.map((test) {
                              return Chip(
                                label: Text(
                                  test,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor: Colors.purple.shade100,
                                labelStyle: TextStyle(
                                  color: Colors.purple.shade900,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ]),
              _buildSection('Diagnosis', [
                TextFormField(
                  controller: _diagnosisController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Enter diagnosis',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Diagnosis required' : null,
                  enabled: !readOnly,
                  readOnly: readOnly,
                ),
              ]),
              _buildSection('Medical Prescriptions', [
                if (!readOnly)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select medication',
                      border: OutlineInputBorder(),
                    ),
                    value: null,
                    items: prescriptionOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == 'Other') {
                        showDialog(
                          context: context,
                          builder: (context) {
                            final customMedController = TextEditingController();
                            final customDosageController =
                                TextEditingController();
                            final customFrequencyController =
                                TextEditingController();
                            final customDurationController =
                                TextEditingController();
                            final formKey = GlobalKey<FormState>();
                            return AlertDialog(
                              title: const Text('Enter custom medication'),
                              content: Form(
                                key: formKey,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        controller: customMedController,
                                        decoration: const InputDecoration(
                                          labelText: 'Medication name *',
                                        ),
                                        validator: (val) =>
                                            val == null || val.trim().isEmpty
                                            ? 'Required'
                                            : null,
                                        autofocus: true,
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customDosageController,
                                        decoration: const InputDecoration(
                                          labelText: 'Dosage',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customFrequencyController,
                                        decoration: const InputDecoration(
                                          labelText: 'Frequency',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customDurationController,
                                        decoration: const InputDecoration(
                                          labelText: 'Duration',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (formKey.currentState?.validate() ??
                                        false) {
                                      final med = customMedController.text
                                          .trim();
                                      final dosage = customDosageController.text
                                          .trim();
                                      final frequency =
                                          customFrequencyController.text.trim();
                                      final duration = customDurationController
                                          .text
                                          .trim();
                                      setState(() {
                                        selectedPrescriptions.add(
                                          [med, dosage, frequency, duration]
                                              .where((e) => e.isNotEmpty)
                                              .join(' | '),
                                        );
                                      });
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                      } else if (value != null &&
                          !selectedPrescriptions.any(
                            (p) => p.startsWith(value),
                          )) {
                        // Show dialog for default fields for standard medication
                        final dosageController = TextEditingController();
                        final frequencyController = TextEditingController();
                        final durationController = TextEditingController();
                        final formKey = GlobalKey<FormState>();
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Enter details for $value'),
                              content: Form(
                                key: formKey,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextFormField(
                                        controller: dosageController,
                                        decoration: const InputDecoration(
                                          labelText: 'Dosage',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: frequencyController,
                                        decoration: const InputDecoration(
                                          labelText: 'Frequency',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: durationController,
                                        decoration: const InputDecoration(
                                          labelText: 'Duration',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedPrescriptions.add(
                                        [
                                              value,
                                              dosageController.text.trim(),
                                              frequencyController.text.trim(),
                                              durationController.text.trim(),
                                            ]
                                            .where((e) => e.isNotEmpty)
                                            .join(' | '),
                                      );
                                    });
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    },
                  ),
                if (selectedPrescriptions.isNotEmpty)
                  Column(
                    children: selectedPrescriptions.map((med) {
                      return StatefulBuilder(
                        builder: (context, setCardState) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          med,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      if (!readOnly)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Remove',
                                          onPressed: () {
                                            setState(() {
                                              selectedPrescriptions.remove(med);
                                            });
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
                    }).toList(),
                  ),
              ]),
              _buildSection('Laboratory Investigations', [
                if (!readOnly)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select laboratory test',
                      border: OutlineInputBorder(),
                    ),
                    value: null,
                    items: labOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == 'Other') {
                        showDialog(
                          context: context,
                          builder: (context) {
                            String customLab = '';
                            return AlertDialog(
                              title: const Text('Enter custom laboratory test'),
                              content: TextField(
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'Lab test name',
                                ),
                                onChanged: (val) => customLab = val,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (customLab.trim().isNotEmpty) {
                                      setState(() {
                                        selectedLabs.add(customLab.trim());
                                      });
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                      } else if (value != null &&
                          !selectedLabs.contains(value)) {
                        setState(() {
                          selectedLabs.add(value);
                        });
                      }
                    },
                  ),
                if (selectedLabs.contains('Other'))
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 0.0,
                      bottom: 8.0,
                      top: 8.0,
                    ),
                    child: TextFormField(
                      controller: _otherLabController,
                      decoration: const InputDecoration(
                        labelText: 'Specify other lab test',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !readOnly,
                      readOnly: readOnly,
                    ),
                  ),
                if (selectedLabs.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: selectedLabs
                        .map(
                          (lab) => Chip(
                            label: Text(lab),
                            onDeleted: !readOnly
                                ? () {
                                    setState(() {
                                      selectedLabs.remove(lab);
                                    });
                                  }
                                : null,
                          ),
                        )
                        .toList(),
                  ),
              ]),
              _buildSection('Radiological Investigations', [
                if (!readOnly)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select radiology test',
                      border: OutlineInputBorder(),
                    ),
                    value: null,
                    items: radiologyOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == 'Other') {
                        showDialog(
                          context: context,
                          builder: (context) {
                            String customRad = '';
                            return AlertDialog(
                              title: const Text('Enter custom radiology test'),
                              content: TextField(
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'Radiology test name',
                                ),
                                onChanged: (val) => customRad = val,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    if (customRad.trim().isNotEmpty) {
                                      setState(() {
                                        selectedRadiology.add(customRad.trim());
                                      });
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                      } else if (value != null &&
                          !selectedRadiology.contains(value)) {
                        setState(() {
                          selectedRadiology.add(value);
                        });
                      }
                    },
                  ),
                if (selectedRadiology.contains('Other'))
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 0.0,
                      bottom: 8.0,
                      top: 8.0,
                    ),
                    child: TextFormField(
                      controller: _otherRadiologyController,
                      decoration: const InputDecoration(
                        labelText: 'Specify other radiology test',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !readOnly,
                      readOnly: readOnly,
                    ),
                  ),
                if (selectedRadiology.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: selectedRadiology
                        .map(
                          (rad) => Chip(
                            label: Text(rad),
                            onDeleted: !readOnly
                                ? () {
                                    setState(() {
                                      selectedRadiology.remove(rad);
                                    });
                                  }
                                : null,
                          ),
                        )
                        .toList(),
                  ),
              ]),
              _buildSection('Follow-up & Recommendations', [
                TextFormField(
                  controller: _followUpController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Enter follow-up or recommendations',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !readOnly,
                  readOnly: readOnly,
                ),
              ]),
              _buildSection('Other Notes', [
                TextFormField(
                  initialValue: widget.appointment['notes'] ?? '',
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Other notes',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !readOnly,
                  readOnly: readOnly,
                ),
              ]),
              const SizedBox(height: 24),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Text(
                      'Signed by: $doctorName',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        'Dr. $doctorName',
                        style: const TextStyle(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Date: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              if (!readOnly) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Consultation Note'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _submitForm,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
