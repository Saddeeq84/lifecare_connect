// Lab Patients Screen
// Shows all patients who have had lab tests

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LabPatientsScreen extends StatefulWidget {
  final String facilityId;
  final String staffId;
  final String staffName;

  const LabPatientsScreen({
    super.key,
    required this.facilityId,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<LabPatientsScreen> createState() => _LabPatientsScreenState();
}

class _LabPatientsScreenState extends State<LabPatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Patients'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by patient name or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lab_results')
                  .where('facilityId', isEqualTo: widget.facilityId)
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
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No lab patients found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Patients who have had lab tests will appear here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Get unique patients who have had lab tests
                final Map<String, Map<String, dynamic>> uniquePatients = {};
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientId = data['patientId'] as String?;
                  if (patientId != null) {
                    uniquePatients[patientId] = {
                      'patientId': patientId,
                      'patientName': data['patientName'] ?? 'Unknown',
                      'lastTestDate': data['testDate'] ?? data['createdAt'],
                      'testType': data['testType'] ?? 'Lab Test',
                    };
                  }
                }

                // Filter patients based on search
                final filteredPatients = uniquePatients.values.where((patient) {
                  if (_searchQuery.isEmpty) return true;
                  final name = patient['patientName'].toString().toLowerCase();
                  final id = patient['patientId'].toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      id.contains(_searchQuery);
                }).toList();

                // Sort by last test date
                filteredPatients.sort((a, b) {
                  final dateA = a['lastTestDate'] as Timestamp?;
                  final dateB = b['lastTestDate'] as Timestamp?;
                  if (dateA == null && dateB == null) return 0;
                  if (dateA == null) return 1;
                  if (dateB == null) return -1;
                  return dateB.compareTo(dateA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patient = filteredPatients[index];
                    final lastTestDate = patient['lastTestDate'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () => _viewPatientLabHistory(
                          patient['patientId'],
                          patient['patientName'],
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple.shade100,
                          child: Icon(
                            Icons.person,
                            color: Colors.purple.shade800,
                          ),
                        ),
                        title: Text(
                          patient['patientName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${patient['patientId']}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            if (lastTestDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Last Test: ${_formatDate(lastTestDate)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.science,
                                color: Colors.purple.shade600,
                              ),
                              onPressed: () => _viewPatientLabHistory(
                                patient['patientId'],
                                patient['patientName'],
                              ),
                              tooltip: 'View Lab History',
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _viewPatientLabHistory(String patientId, String patientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientLabHistoryScreen(
          facilityId: widget.facilityId,
          patientId: patientId,
          patientName: patientName,
          staffId: widget.staffId,
          staffName: widget.staffName,
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Patient Lab History Screen
class PatientLabHistoryScreen extends StatelessWidget {
  final String facilityId;
  final String patientId;
  final String patientName;
  final String staffId;
  final String staffName;

  const PatientLabHistoryScreen({
    super.key,
    required this.facilityId,
    required this.patientId,
    required this.patientName,
    required this.staffId,
    required this.staffName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$patientName - Lab History'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lab_results')
            .where('facilityId', isEqualTo: facilityId)
            .where('patientId', isEqualTo: patientId)
            .orderBy('testDate', descending: true)
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
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No lab results found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final testDate = data['testDate'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Icon(Icons.science, color: Colors.purple.shade800),
                  ),
                  title: Text(
                    data['testType'] ?? 'Lab Test',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: testDate != null
                      ? Text('Date: ${_formatDateTime(testDate)}')
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (data['results'] != null) ...[
                            const Text(
                              'Results:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(data['results']),
                            const SizedBox(height: 16),
                          ],
                          if (data['notes'] != null) ...[
                            const Text(
                              'Notes:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(data['notes']),
                            const SizedBox(height: 16),
                          ],
                          if (data['performedBy'] != null) ...[
                            Text(
                              'Performed by: ${data['performedBy']}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
