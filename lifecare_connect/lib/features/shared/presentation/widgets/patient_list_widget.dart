import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Custom QuerySnapshot for combining multiple query results
class _CombinedQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  _CombinedQuerySnapshot(this._docs);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];

  @override
  SnapshotMetadata get metadata => _CombinedSnapshotMetadata();

  @override
  int get size => _docs.length;
}

// Custom SnapshotMetadata implementation
class _CombinedSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;

  @override
  bool get isFromCache => false;
}

class PatientListWidget extends StatefulWidget {
  final String userRole;
  final Function(DocumentSnapshot) onPatientTap;
  final bool showOnlyOwnPatients;

  const PatientListWidget({
    super.key,
    required this.userRole,
    required this.onPatientTap,
    this.showOnlyOwnPatients = false,
  });

  @override
  State<PatientListWidget> createState() => _PatientListWidgetState();
}

class _PatientListWidgetState extends State<PatientListWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _filteredPatients = [];
  List<DocumentSnapshot> _allPatients = [];
  final int _batchSize = 10;
  int _currentBatch = 1;
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _currentBatch = 1;
        _filterPatients();
      });
    });
  }

  void _filterPatients() {
    List<DocumentSnapshot> filtered;
    if (_searchQuery.isEmpty) {
      filtered = List.from(_allPatients);
    } else {
      filtered = _allPatients.where((patient) {
        final data = patient.data() as Map<String, dynamic>;
        final name = (data['name'] ?? data['fullName'] ?? '')
            .toString()
            .toLowerCase();
        final phone = (data['phone'] ?? '').toString().toLowerCase();
        final nationalId = (data['nationalId'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            nationalId.contains(_searchQuery);
      }).toList();
    }
    int end = _currentBatch * _batchSize;
    if (end > filtered.length) end = filtered.length;
    _filteredPatients = filtered.sublist(0, end);
  }

  Widget _buildEmptyState(BuildContext context) {
    String message;
    String description;

    switch (widget.userRole) {
      case 'chw':
        message = widget.showOnlyOwnPatients
            ? 'No patients registered by you'
            : 'No patients found';
        description = widget.showOnlyOwnPatients
            ? 'Register a patient to get started'
            : 'There are currently no patients in the system';
        break;
      case 'admin':
        message = 'No patients in system';
        description = 'No patients have been registered yet';
        break;
      case 'doctor':
        message = 'No patients to consult';
        description = 'No patients have been assigned for consultation';
        break;
      case 'facility':
        message = 'No patients in facility';
        description = 'No patients have been registered at this facility';
        break;
      default:
        message = 'No patients found';
        description = 'There are currently no patients available';
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.teal[200]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Icon(Icons.medical_services, size: 48, color: Colors.teal[200]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search patients by name, phone, or ID...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ),
        // Patient List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildPatientQuery(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading patients',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading patients...'),
                    ],
                  ),
                );
              }

              _allPatients = snapshot.data?.docs ?? [];
              _filterPatients();
              final patients = _filteredPatients;

              if (patients.isEmpty) {
                if (_searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No patients found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching with different keywords',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                return _buildEmptyState(context);
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: patients.length,
                      itemBuilder: (context, index) {
                        final patient = patients[index];
                        final patientData =
                            patient.data() as Map<String, dynamic>;
                        final patientName =
                            patientData['name'] ??
                            patientData['fullName'] ??
                            'Unknown Patient';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              patientName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (patientData['gender'] != null)
                                  Text('Gender: ${patientData['gender']}'),
                                if (patientData['phone'] != null)
                                  Text('Phone: ${patientData['phone']}'),
                                if (patientData['email'] != null)
                                  Text('Email: ${patientData['email']}'),
                                if (patientData['address'] != null)
                                  Text('Address: ${patientData['address']}'),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => widget.onPatientTap(patient),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_filteredPatients.length <
                      (_allPatients.where((patient) {
                        final data = patient.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? data['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final phone = (data['phone'] ?? '')
                            .toString()
                            .toLowerCase();
                        final nationalId = (data['nationalId'] ?? '')
                            .toString()
                            .toLowerCase();
                        return _searchQuery.isEmpty ||
                            name.contains(_searchQuery) ||
                            phone.contains(_searchQuery) ||
                            nationalId.contains(_searchQuery);
                      }).length))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _currentBatch++;
                            _filterPatients();
                          });
                        },
                        child: const Text('View More'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _buildPatientQuery() {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Return empty stream if no user
      return const Stream.empty();
    }

    // Admin sees all patients - simple query
    if (widget.userRole == 'admin') {
      return FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    // For CHW, doctor, facility - show only patients they've interacted with
    if (widget.showOnlyOwnPatients ||
        widget.userRole == 'chw' ||
        widget.userRole == 'doctor' ||
        widget.userRole == 'facility') {
      return _buildInteractedPatientsQuery(currentUser.uid);
    }

    // Default fallback query
    Query query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient');

    try {
      return query.orderBy('createdAt', descending: true).snapshots();
    } catch (e) {
      return query.orderBy('name').snapshots();
    }
  }

  Stream<QuerySnapshot> _buildInteractedPatientsQuery(String userId) async* {
    try {
      final Set<String> patientIds = <String>{};

      // 1. Patients registered by this user (CHW registration)
      final registeredPatients = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where('createdBy', isEqualTo: userId)
          .get();

      for (final doc in registeredPatients.docs) {
        patientIds.add(doc.id);
      }

      // 2. Patients from health records (consultations, ANC visits, etc.)
      final healthRecords = await FirebaseFirestore.instance
          .collection('health_records')
          .where('providerId', isEqualTo: userId)
          .get();

      for (final doc in healthRecords.docs) {
        final data = doc.data();
        if (data['patientUid'] != null) {
          patientIds.add(data['patientUid']);
        }
      }

      // 3. Skip nested health records query for CHWs to avoid permission errors
      // CHWs already get patient interactions from the main health_records collection above
      if (widget.userRole != 'chw') {
        final allPatients = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .get();

        for (final patientDoc in allPatients.docs) {
          try {
            final nestedRecords = await FirebaseFirestore.instance
                .collection('users')
                .doc(patientDoc.id)
                .collection('health_records')
                .where('providerId', isEqualTo: userId)
                .limit(1)
                .get();

            if (nestedRecords.docs.isNotEmpty) {
              patientIds.add(patientDoc.id);
            }
          } catch (e) {
            // Skip if nested collection doesn't exist, access denied, or permission issues
            debugPrint(
              'Skipping nested health records for patient ${patientDoc.id}: Permission denied or collection not accessible',
            );
          }
        }
      }

      // 4. Patients from appointments (if appointments collection exists)
      try {
        final appointments = await FirebaseFirestore.instance
            .collection('appointments')
            .where('providerId', isEqualTo: userId)
            .where('status', whereIn: ['completed', 'attended'])
            .get();

        for (final doc in appointments.docs) {
          final data = doc.data();
          if (data['patientId'] != null) {
            patientIds.add(data['patientId']);
          }
        }
      } catch (e) {
        // Appointments collection might not exist yet
      }

      // 5. Patients from referrals (if user referred or received patients)
      try {
        final referrals = await FirebaseFirestore.instance
            .collection('referrals')
            .where('referredById', isEqualTo: userId)
            .get();

        for (final doc in referrals.docs) {
          final data = doc.data();
          if (data['patientId'] != null) {
            patientIds.add(data['patientId']);
          }
        }

        final receivedReferrals = await FirebaseFirestore.instance
            .collection('referrals')
            .where('referredToId', isEqualTo: userId)
            .get();

        for (final doc in receivedReferrals.docs) {
          final data = doc.data();
          if (data['patientId'] != null) {
            patientIds.add(data['patientId']);
          }
        }
      } catch (e) {
        // Referrals collection might not exist yet
      }

      // If no interactions found, return empty result
      if (patientIds.isEmpty) {
        yield _CombinedQuerySnapshot([]);
        return;
      }

      // Get all patients that match these IDs (handle Firestore 'in' limitation)
      final List<QueryDocumentSnapshot> allDocs = [];
      final List<String> patientIdsList = patientIds.toList();
      const int batchSize = 10; // Firestore 'in' query limit

      for (int i = 0; i < patientIdsList.length; i += batchSize) {
        final batch = patientIdsList.sublist(
          i,
          i + batchSize > patientIdsList.length
              ? patientIdsList.length
              : i + batchSize,
        );

        final batchQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        allDocs.addAll(batchQuery.docs);
      }

      // Sort by name or creation date
      allDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = aData['name'] ?? aData['fullName'] ?? '';
        final bName = bData['name'] ?? bData['fullName'] ?? '';
        return aName.compareTo(bName);
      });

      yield _CombinedQuerySnapshot(
        allDocs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>(),
      );
    } catch (e) {
      throw Exception('Failed to load patients: $e');
    }
  }
}
