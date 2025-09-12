



import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../consultation/presentation/screens/consultation_screen.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/presentation/screens/messages_screen.dart';
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
  State<DoctorConsultationScreen> createState() => _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen> with SingleTickerProviderStateMixin {
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
        final docs = snapshot.data!.docs;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            label: const Text('Start Consultation'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.chat, color: Colors.indigo),
                                        title: const Text('Text Chat'),
                                        subtitle: const Text('Open messaging system'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
                                          final doctorName = FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
                                          final conversationId = await MessageService.createOrGetConversation(
                                            user1Id: doctorId,
                                            user1Name: doctorName,
                                            user1Role: 'doctor',
                                            user2Id: appointment['patientId'],
                                            user2Name: appointment['patientName'] ?? 'Unknown Patient',
                                            user2Role: 'patient',
                                          );
                                          // ...existing code...
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
                                      ListTile(
                                        leading: Icon(Icons.videocam, color: Colors.indigo),
                                        title: Text('Video Call'),
                                        subtitle: Text('Start video consultation'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => ConsultationScreen(
                                                channelName: appointment['id'] ?? appointment['appointmentId'] ?? '',
                                                isVideo: true,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.call, color: Colors.indigo),
                                        title: Text('Audio Call'),
                                        subtitle: Text('Start audio consultation'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => ConsultationScreen(
                                                channelName: appointment['id'] ?? appointment['appointmentId'] ?? '',
                                                isVideo: false,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.local_hospital, color: Colors.teal),
                                        title: const Text('Physical'),
                                        subtitle: const Text('Clinic-based consultation'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => DoctorConsultationDetailScreen(appointment: appointment),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.note_add, color: Colors.white),
                                        label: const Text('Add Consultation Note'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => DoctorConsultationDetailScreen(appointment: appointment),
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
                            icon: const Icon(Icons.note_add, color: Colors.indigo, size: 22),
                            tooltip: 'Add Clinical Note',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DoctorConsultationDetailScreen(appointment: appointment),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 0),
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.indigo, size: 22),
                            tooltip: 'Chat with Patient',
                            onPressed: () async {
                              final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
                              final doctorName = FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
                              final conversationId = await MessageService.createOrGetConversation(
                                user1Id: doctorId,
                                user1Name: doctorName,
                                user1Role: 'doctor',
                                user2Id: appointment['patientId'],
                                user2Name: appointment['patientName'] ?? 'Unknown Patient',
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
                            icon: const Icon(Icons.info, color: Colors.indigo, size: 28),
                            tooltip: 'View Details',
                            onPressed: () async {
                              final patientId = appointment['patientId'];
                              if (patientId == null) {
                                showDialog(
                                  context: context,
                                  builder: (context) => const AlertDialog(
                                    title: Text('No Patient ID'),
                                    content: Text('No patient ID found for this appointment.'),
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
                                    content: Text('No health record found for this patient.'),
                                  ),
                                );
                                return;
                              }
                              final record = query.docs.first.data();
                              // Filter out system fields
                              final filteredDetails = <String, dynamic>{};
                              record.forEach((key, value) {
                                final k = key.toLowerCase();
                                if (k == 'timestamp' || k == 'createdat' || k == 'updatedat' || k == 'appointmentid' || k == 'patientid' || k == 'prescribedat' || k == 'requestedat' || k == 'userid' || k == 'recordid' || k == 'id' || k == 'source' || k == 'status' || k == 'fileurls' || k == 'filenames' || k == 'uploaddate' || k == 'submissiontimestamp' || k == 'requiresreview' || k == 'accessibleby' || k == 'iseditable' || k == 'isdeletable') {
                                  return;
                                }
                                filteredDetails[key] = value;
                              });
                              String formatLabel(String key) {
                                final k = key.toString().replaceAll('_', ' ');
                                return k.isNotEmpty ? (k[0].toUpperCase() + k.substring(1)) : k;
                              }
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Health Record Details'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ...filteredDetails.entries
                                              .where((entry) => entry.value != null && entry.value.toString().isNotEmpty)
                                              .map((entry) {
                                                final value = entry.value;
                                                String displayValue;
                                                if (entry.key.toLowerCase() == 'prescriptions' && value is List) {
                                                  displayValue = value.map((e) {
                                                    if (e is Map && e.containsKey('name')) return e['name'];
                                                    return e.toString();
                                                  }).join(', ');
                                                } else if (entry.key.toLowerCase() == 'laboratoryinvestigations' && value is List) {
                                                  displayValue = value.map((e) {
                                                    if (e is Map && e.containsKey('name')) return e['name'];
                                                    return e.toString();
                                                  }).join(', ');
                                                } else {
                                                  displayValue = value.toString();
                                                }
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('${formatLabel(entry.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                      Expanded(child: Text(displayValue, style: const TextStyle(fontSize: 15))),
                                                    ],
                                                  ),
                                                );
                                              })
                                        ],
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
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          appointment['appointmentDate'] != null
                              ? appointment['appointmentDate'].toString().split(' ')[0]
                              : '',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    if (appointment['reason'] != null && appointment['reason'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                appointment['reason'],
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('View Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Consultation Details'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow('Patient Name', record['patientName'] ?? 'Unknown'),
                                        _buildInfoRow('Age', record['age']?.toString() ?? 'Not provided'),
                                        _buildInfoRow('Sex', record['sex'] ?? 'Not provided'),
                                        _buildInfoRow('Phone', record['phone'] ?? 'Not provided'),
                                        _buildInfoRow('Address', record['address'] ?? 'Not provided'),
                                        _buildInfoRow('Appointment Date', record['appointmentDate']?.toString() ?? 'Not provided'),
                                        if (record['referralReason'] != null && record['referralReason'].toString().isNotEmpty)
                                          _buildInfoRow('Referral Reason', record['referralReason']),
                                        if (record['reason'] != null && record['reason'].toString().isNotEmpty)
                                          _buildInfoRow('Consultation Reason', record['reason']),
                                        const Divider(),
                                        _buildInfoRow('Clinical Notes', record['clinicalNotes'] ?? ''),
                                        _buildInfoRow('Diagnosis', record['diagnosis'] ?? ''),
                                        if (record['prescriptions'] != null && (record['prescriptions'] as List).isNotEmpty)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text('Prescriptions:', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ...List<String>.from(record['prescriptions']).map((med) => Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                                child: Text(med),
                                              )),
                                            ],
                                          ),
                                        if (record['labRequests'] != null && (record['labRequests'] as List).isNotEmpty)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text('Lab Requests:', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ...List<String>.from(record['labRequests']).map((lab) => Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                                child: Text(lab),
                                              )),
                                            ],
                                          ),
                                        if (record['radiologyRequests'] != null && (record['radiologyRequests'] as List).isNotEmpty)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 8),
                                              const Text('Radiology Requests:', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ...List<String>.from(record['radiologyRequests']).map((rad) => Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                                child: Text(rad),
                                              )),
                                            ],
                                          ),
                                        _buildInfoRow('Follow-up', record['followUp'] ?? ''),
                                        _buildInfoRow('Other Notes', record['notes'] ?? ''),
                                        const Divider(),
                                        _buildInfoRow('Signed by', record['providerName'] ?? ''),
                                        _buildInfoRow('Provider ID', record['providerId'] ?? ''),
                                        _buildInfoRow('Date', record['date']?.toString().split(' ')[0] ?? ''),
                                      ],
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
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.grey.shade600, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          record['date'] != null
                              ? record['date'].toString().split(' ')[0]
                              : '',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    if (record['reason'] != null && record['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              record['reason'],
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
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
  const DoctorConsultationDetailScreen({super.key, required this.appointment, this.readOnly = false});

  @override
  State<DoctorConsultationDetailScreen> createState() => _DoctorConsultationDetailScreenState();
}

class _DoctorConsultationDetailScreenState extends State<DoctorConsultationDetailScreen> {
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
  'Other'
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
    'Other'
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
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _clinicalNotesController = TextEditingController(text: widget.appointment['clinicalNotes'] ?? '');
    _diagnosisController = TextEditingController(text: widget.appointment['diagnosis'] ?? '');
    _followUpController = TextEditingController(text: widget.appointment['followUp'] ?? '');
    _otherPrescriptionController = TextEditingController();
    _otherLabController = TextEditingController();
    _otherRadiologyController = TextEditingController();
    selectedPrescriptions = List<String>.from(widget.appointment['prescriptions'] ?? []);
    selectedLabs = List<String>.from(widget.appointment['labRequests'] ?? []);
    selectedRadiology = List<String>.from(widget.appointment['radiologyRequests'] ?? []);
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

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final doctorName = FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
      final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final patientId = widget.appointment['patientId'] ?? '';
      final now = DateTime.now();
      final recordData = {
        'patientId': patientId,
        'patientUid': patientId,
        'patientName': widget.appointment['patientName'] ?? '',
        'providerId': doctorId,
        'providerName': doctorName,
        'type': 'DOCTOR_CONSULTATION',
        'date': now,
        'timestamp': now,
        'clinicalNotes': _clinicalNotesController.text,
        'diagnosis': _diagnosisController.text,
        'prescriptions': [
          ...selectedPrescriptions.where((p) => p != 'Other'),
          if (selectedPrescriptions.contains('Other') && _otherPrescriptionController.text.isNotEmpty)
            _otherPrescriptionController.text,
        ],
        'labRequests': [
          ...selectedLabs.where((l) => l != 'Other'),
          if (selectedLabs.contains('Other') && _otherLabController.text.isNotEmpty)
            _otherLabController.text,
        ],
        'radiologyRequests': [
          ...selectedRadiology.where((r) => r != 'Other'),
          if (selectedRadiology.contains('Other') && _otherRadiologyController.text.isNotEmpty)
            _otherRadiologyController.text,
        ],
        'followUp': _followUpController.text,
        'notes': widget.appointment['notes'] ?? '',
        'status': 'completed',
        'createdAt': now,
        'updatedAt': now,
      };
      try {
        await FirebaseFirestore.instance.collection('health_records').add(recordData);

        if (widget.appointment['id'] != null) {
          await FirebaseFirestore.instance.collection('appointments').doc(widget.appointment['id']).update({'status': 'completed'});
        } else if (widget.appointment['appointmentId'] != null) {
          await FirebaseFirestore.instance.collection('appointments').doc(widget.appointment['appointmentId']).update({'status': 'completed'});
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation note saved to health records!')),
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = FirebaseAuth.instance.currentUser?.displayName ?? 'Doctor';
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
                _buildInfoRow('Name', widget.appointment['patientName'] ?? 'Unknown'),
                _buildInfoRow('Age', widget.appointment['age']?.toString() ?? 'Not provided'),
                _buildInfoRow('Sex', widget.appointment['sex'] ?? 'Not provided'),
                _buildInfoRow('Phone', widget.appointment['phone'] ?? 'Not provided'),
                _buildInfoRow('Address', widget.appointment['address'] ?? 'Not provided'),
                _buildInfoRow('Appointment Date', widget.appointment['appointmentDate']?.toString() ?? 'Not provided'),
                _buildInfoRow('Appointment Type',
                  (widget.appointment['referralReason'] != null && widget.appointment['referralReason'].toString().isNotEmpty)
                    ? 'Referred'
                    : 'Regular'),
                if (widget.appointment['referralReason'] != null && widget.appointment['referralReason'].toString().isNotEmpty)
                  _buildInfoRow('Referral Reason', widget.appointment['referralReason']),
              ]),
              _buildSection('Clinical Notes', [
                TextFormField(
                  controller: _clinicalNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Enter clinical notes',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Clinical notes required' : null,
                  enabled: !readOnly,
                  readOnly: readOnly,
                ),
              ]),
              _buildSection('Diagnosis', [
                TextFormField(
                  controller: _diagnosisController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Enter diagnosis',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Diagnosis required' : null,
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
                            final customStrengthController = TextEditingController();
                            final customDosageController = TextEditingController();
                            final customFrequencyController = TextEditingController();
                            final customDurationController = TextEditingController();
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
                                        decoration: const InputDecoration(labelText: 'Medication name *'),
                                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                        autofocus: true,
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customStrengthController,
                                        decoration: const InputDecoration(labelText: 'Strength'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customDosageController,
                                        decoration: const InputDecoration(labelText: 'Dosage'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customFrequencyController,
                                        decoration: const InputDecoration(labelText: 'Frequency'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: customDurationController,
                                        decoration: const InputDecoration(labelText: 'Duration'),
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
                                    if (formKey.currentState?.validate() ?? false) {
                                      final med = customMedController.text.trim();
                                      final strength = customStrengthController.text.trim();
                                      final dosage = customDosageController.text.trim();
                                      final frequency = customFrequencyController.text.trim();
                                      final duration = customDurationController.text.trim();
                                      setState(() {
                                        selectedPrescriptions.add(
                                          [med, strength, dosage, frequency, duration]
                                            .where((e) => e.isNotEmpty)
                                            .join(' | ')
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
                      } else if (value != null && !selectedPrescriptions.any((p) => p.startsWith(value))) {
                        // Show dialog for default fields for standard medication
                        final strengthController = TextEditingController();
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
                                        controller: strengthController,
                                        decoration: const InputDecoration(labelText: 'Strength'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: dosageController,
                                        decoration: const InputDecoration(labelText: 'Dosage'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: frequencyController,
                                        decoration: const InputDecoration(labelText: 'Frequency'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: durationController,
                                        decoration: const InputDecoration(labelText: 'Duration'),
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
                                        [value, strengthController.text.trim(), dosageController.text.trim(), frequencyController.text.trim(), durationController.text.trim()]
                                          .where((e) => e.isNotEmpty)
                                          .join(' | ')
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
                    children: selectedPrescriptions
                        .map((med) {
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
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ),
                                          if (!readOnly)
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
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
                                decoration: const InputDecoration(labelText: 'Lab test name'),
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
                      } else if (value != null && !selectedLabs.contains(value)) {
                        setState(() {
                          selectedLabs.add(value);
                        });
                      }
                    },
                  ),
                if (selectedLabs.contains('Other'))
                  Padding(
                    padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, top: 8.0),
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
                    children: selectedLabs.map((lab) => Chip(
                      label: Text(lab),
                      onDeleted: !readOnly
                          ? () {
                              setState(() {
                                selectedLabs.remove(lab);
                              });
                            }
                          : null,
                    )).toList(),
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
                                decoration: const InputDecoration(labelText: 'Radiology test name'),
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
                      } else if (value != null && !selectedRadiology.contains(value)) {
                        setState(() {
                          selectedRadiology.add(value);
                        });
                      }
                    },
                  ),
                if (selectedRadiology.contains('Other'))
                  Padding(
                    padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, top: 8.0),
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
                    children: selectedRadiology.map((rad) => Chip(
                      label: Text(rad),
                      onDeleted: !readOnly
                          ? () {
                              setState(() {
                                selectedRadiology.remove(rad);
                              });
                            }
                          : null,
                    )).toList(),
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
                    Text('Signed by: $doctorName', style: const TextStyle(fontWeight: FontWeight.w500)),
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
                child: Text('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: const TextStyle(color: Colors.grey)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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