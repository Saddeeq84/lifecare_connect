import 'package:lifecare_connect/features/chw/presentation/screens/patient_health_records_screen.dart';




import 'package:flutter/material.dart';
import 'package:lifecare_connect/features/doctor/presentation/screens/doctor_consultation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorPatientListScreen extends StatefulWidget {
  const DoctorPatientListScreen({super.key});

  @override
  State<DoctorPatientListScreen> createState() => _DoctorPatientListScreenState();
}

class _DoctorPatientListScreenState extends State<DoctorPatientListScreen> {
  static const int batchSize = 10;
  List<String> _allPatientIds = [];
  int _currentBatch = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatientIds();
  }

  Future<void> _loadPatientIds() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Not logged in.';
          _loading = false;
        });
        return;
      }
      final ids = await _getUniquePatientIds(currentUser.uid);
      setState(() {
        _allPatientIds = ids;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading patients';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _allPatientIds.isEmpty
                  ? const Center(child: Text('No patients found.'))
                  : _buildPatientList(context),
    );
  }

  Widget _buildPatientList(BuildContext context) {
    final batchIds = _allPatientIds.take(_currentBatch * batchSize).toList();
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Center(child: Text('Error loading patient details'));
        }
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = userSnapshot.data?.docs ?? [];
        if (patients.isEmpty) {
          return const Center(child: Text('No patients found.'));
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  final data = patient.data() as Map<String, dynamic>;
                  final name = data['name'] ?? data['fullName'] ?? 'Unknown Patient';
                  final email = data['email'] ?? 'No email';
                  final phone = data['phone'] ?? data['phoneNumber'] ?? 'No phone';
                  final lastSeen = data['lastSeen'] as Timestamp?;
                  final isOnline = data['isOnline'] ?? false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.teal[100],
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[700],
                              ),
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.email, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (!isOnline && lastSeen != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Last seen: ${_formatTimestamp(lastSeen)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_right,
                            color: Colors.teal[300],
                          ),
                          if (isOnline)
                            Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _showPatientActions(context, patient),
                    ),
                  );
                },
              ),
            ),
            if (_allPatientIds.length > _currentBatch * batchSize)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentBatch++;
                    });
                  },
                  child: const Text('View More'),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showPatientActions(BuildContext context, DocumentSnapshot patient) {
    final patientData = patient.data() as Map<String, dynamic>;
    final patientName = patientData['name'] ?? patientData['fullName'] ?? 'Unknown Patient';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patientName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Patient ID: ${patient.id}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.medical_services, color: Colors.teal),
              title: const Text('Health Records'),
              subtitle: const Text('View comprehensive health history'),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientHealthRecordsScreen(
                      patientId: patient.id,
                      patientName: patientName,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add, color: Colors.teal),
              title: const Text('Add Clinical Notes'),
              subtitle: const Text('Document consultation findings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorConsultationDetailScreen(
                      appointment: {
                        'patientId': patient.id,
                        'patientName': patientName,
                        'email': patientData['email'] ?? 'No email',
                        'phone': patientData['phone'] ?? patientData['phoneNumber'] ?? 'No phone',
                        'lastSeen': patientData['lastSeen'],
                        'isOnline': patientData['isOnline'] ?? false,
                      },
                      readOnly: false,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Colors.teal),
              title: const Text('Prescriptions'),
              subtitle: const Text('Manage medications and prescriptions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorConsultationDetailScreen(
                      appointment: {
                        'patientId': patient.id,
                        'patientName': patientName,
                        'email': patientData['email'] ?? 'No email',
                        'phone': patientData['phone'] ?? patientData['phoneNumber'] ?? 'No phone',
                        'lastSeen': patientData['lastSeen'],
                        'isOnline': patientData['isOnline'] ?? false,
                      },
                      readOnly: false,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>> _getUniquePatientIds(String doctorId) async {
    final appointmentSnaps = await FirebaseFirestore.instance
        .collection('appointments')
        .where('providerId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .get();
    final consultationSnaps = await FirebaseFirestore.instance
        .collection('consultations')
        .where('providerId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .get();
    final patientIds = <String>{};
    for (var doc in appointmentSnaps.docs) {
      final data = doc.data();
      final patientId = data['patientUid'] ?? data['patientId'];
      if (patientId != null) patientIds.add(patientId);
    }
    for (var doc in consultationSnaps.docs) {
      final data = doc.data();
      final patientId = data['patientUid'] ?? data['patientId'];
      if (patientId != null) patientIds.add(patientId);
    }
    return patientIds.toList();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _DoctorPatientBatchList extends StatefulWidget {
  final String doctorId;
  final Function(DocumentSnapshot) onPatientTap;
  const _DoctorPatientBatchList(this.doctorId, this.onPatientTap);

  @override
  State<_DoctorPatientBatchList> createState() => _DoctorPatientBatchListState();
}

class _DoctorPatientBatchListState extends State<_DoctorPatientBatchList> {
  static const int batchSize = 10;
  List<String> _allPatientIds = [];
  int _currentBatch = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatientIds();
  }

  Future<void> _loadPatientIds() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = await _getUniquePatientIds(widget.doctorId);
      setState(() {
        _allPatientIds = ids;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading patients';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_allPatientIds.isEmpty) {
      return const Center(child: Text('No patients found.'));
    }
    final batchIds = _allPatientIds.take(_currentBatch * batchSize).toList();
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batchIds)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return const Center(child: Text('Error loading patient details'));
        }
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final patients = userSnapshot.data?.docs ?? [];
        if (patients.isEmpty) {
          return const Center(child: Text('No patients found.'));
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  final data = patient.data() as Map<String, dynamic>;
                  final name = data['name'] ?? data['fullName'] ?? 'Unknown Patient';
                  final email = data['email'] ?? 'No email';
                  final phone = data['phone'] ?? data['phoneNumber'] ?? 'No phone';
                  final lastSeen = data['lastSeen'] as Timestamp?;
                  final isOnline = data['isOnline'] ?? false;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.teal[100],
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'P',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal[700],
                              ),
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.email, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (!isOnline && lastSeen != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Last seen: ${_formatTimestamp(lastSeen)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_right,
                            color: Colors.teal[300],
                          ),
                          if (isOnline)
                            Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => widget.onPatientTap(patient),
                    ),
                  );
                },
              ),
            ),
            if (_allPatientIds.length > _currentBatch * batchSize)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentBatch++;
                    });
                  },
                  child: const Text('View More'),
                ),
              ),
          ],
        );
      },
    );
  }

// ...existing code...

  Future<List<String>> _getUniquePatientIds(String doctorId) async {
    final appointmentSnaps = await FirebaseFirestore.instance
        .collection('appointments')
        .where('providerId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .get();
    final consultationSnaps = await FirebaseFirestore.instance
        .collection('consultations')
        .where('providerId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .get();
    final patientIds = <String>{};
    for (var doc in appointmentSnaps.docs) {
      final data = doc.data();
      final patientId = data['patientUid'] ?? data['patientId'];
      if (patientId != null) patientIds.add(patientId);
    }
    for (var doc in consultationSnaps.docs) {
      final data = doc.data();
      final patientId = data['patientUid'] ?? data['patientId'];
      if (patientId != null) patientIds.add(patientId);
    }
    return patientIds.toList();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}