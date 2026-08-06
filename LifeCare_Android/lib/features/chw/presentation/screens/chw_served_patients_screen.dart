import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CHWServedPatientsScreen extends StatefulWidget {
  const CHWServedPatientsScreen({super.key});

  @override
  State<CHWServedPatientsScreen> createState() =>
      _CHWServedPatientsScreenState();
}

class _CHWServedPatientsScreenState extends State<CHWServedPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _servedPatients = [];

  @override
  void initState() {
    super.initState();
    _loadServedPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServedPatients() async {
    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) return;

      final Set<String> patientIds = {};
      final Map<String, Map<String, dynamic>> patientsData = {};

      // 1. Get patients from completed appointments
      final completedAppointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('chwId', isEqualTo: chwId)
          .where('status', isEqualTo: 'completed')
          .get();

      for (final doc in completedAppointments.docs) {
        final patientId = doc.data()['patientId'] as String?;
        if (patientId != null && patientId.isNotEmpty) {
          patientIds.add(patientId);
        }
      }

      // 2. Get patients from health records (consultations, ANC, PNC, etc.)
      final healthRecords = await FirebaseFirestore.instance
          .collection('health_records')
          .where('providerId', isEqualTo: chwId)
          .get();

      for (final doc in healthRecords.docs) {
        final patientId = doc.data()['patientUid'] as String?;
        if (patientId != null && patientId.isNotEmpty) {
          patientIds.add(patientId);
        }
      }

      // 3. Fetch patient details for all unique patient IDs
      if (patientIds.isNotEmpty) {
        // Process in batches of 10 (Firestore 'in' query limit)
        final patientIdsList = patientIds.toList();
        for (int i = 0; i < patientIdsList.length; i += 10) {
          final batch = patientIdsList.sublist(
            i,
            i + 10 > patientIdsList.length ? patientIdsList.length : i + 10,
          );

          final userDocs = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();

          for (final doc in userDocs.docs) {
            patientsData[doc.id] = {'id': doc.id, ...doc.data()};
          }
        }
      }

      setState(() {
        _servedPatients = patientsData.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading patients: $e')));
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPatients {
    if (_searchQuery.isEmpty) return _servedPatients;

    return _servedPatients.where((patient) {
      final name = (patient['name'] ?? patient['fullName'] ?? '')
          .toString()
          .toLowerCase();
      final phone = (patient['phoneNumber'] ?? '').toString().toLowerCase();
      final email = (patient['email'] ?? '').toString().toLowerCase();

      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients I\'ve Served'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients by name or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Patient list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No patients served yet'
                              : 'No patients found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Complete appointments to see patients here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadServedPatients,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patient = _filteredPatients[index];
                        final patientName =
                            patient['name'] ??
                            patient['fullName'] ??
                            'Unknown Patient';
                        final phoneNumber =
                            patient['phoneNumber'] ?? 'No phone';
                        final patientId = patient['id'] ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                patientName.isNotEmpty
                                    ? patientName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              patientName,
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
                                    const Icon(
                                      Icons.phone,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(phoneNumber),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onTap: () => _showPatientOptions(
                              context,
                              patientId,
                              patientName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showPatientOptions(
    BuildContext context,
    String patientId,
    String patientName,
  ) {
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
              'Patient ID: $patientId',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.history, color: Colors.teal),
              title: const Text('View Service History'),
              subtitle: const Text('See all consultations and visits'),
              onTap: () {
                Navigator.pop(context);
                _showServiceHistory(context, patientId, patientName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.teal),
              title: const Text('Patient Details'),
              subtitle: const Text('View patient information'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Patient details feature coming soon'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showServiceHistory(
    BuildContext context,
    String patientId,
    String patientName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Service History - $patientName'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('health_records')
                .where('patientUid', isEqualTo: patientId)
                .where(
                  'providerId',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No service history found'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final record =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final type = record['type'] ?? 'Consultation';
                  final date = (record['createdAt'] as Timestamp?)?.toDate();
                  final notes =
                      record['notes'] ?? record['chiefComplaint'] ?? 'No notes';

                  return ListTile(
                    leading: Icon(_getIconForType(type), color: Colors.teal),
                    title: Text(type),
                    subtitle: Text(
                      '${date != null ? '${date.day}/${date.month}/${date.year}' : 'Date unknown'}\n$notes',
                    ),
                    isThreeLine: true,
                  );
                },
              );
            },
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

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'anc':
        return Icons.pregnant_woman;
      case 'pnc':
        return Icons.child_care;
      case 'immunization':
        return Icons.vaccines;
      case 'home visit':
        return Icons.home;
      default:
        return Icons.medical_services;
    }
  }
}
