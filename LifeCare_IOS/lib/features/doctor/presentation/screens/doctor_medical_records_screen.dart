import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DoctorMedicalRecordsScreen extends StatefulWidget {
  const DoctorMedicalRecordsScreen({super.key});

  @override
  State<DoctorMedicalRecordsScreen> createState() =>
      _DoctorMedicalRecordsScreenState();
}

class _DoctorMedicalRecordsScreenState
    extends State<DoctorMedicalRecordsScreen> {
  final String doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Only show completed consultation records by this doctor
        stream: FirebaseFirestore.instance
            .collection('health_records')
            .where('providerId', isEqualTo: doctorId)
            .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
            .where('status', isEqualTo: 'completed')
            .orderBy('date', descending: true)
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
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No completed consultation records found'),
                  SizedBox(height: 8),
                  Text(
                    'Only patients with completed consultations and saved consultation notes will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final allRecords = snapshot.data!.docs;

          // Filter by search query if provided
          final filteredRecords = _searchQuery.isEmpty
              ? allRecords
              : allRecords.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName = (data['patientName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return patientName.contains(_searchQuery);
                }).toList();

          if (filteredRecords.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No results found for "$_searchQuery"'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRecords.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = filteredRecords[index];
              final record = doc.data() as Map<String, dynamic>;
              record['id'] = doc.id;

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
                          Icon(
                            Icons.medical_information,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              record['patientName'] ?? 'Unknown Patient',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'COMPLETED',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Consultation summary
                      if (record['diagnosis'] != null &&
                          record['diagnosis'].toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diagnosis:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record['diagnosis'],
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                      // Date and basic info
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
                                : 'Date not specified',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Dr. ${record['providerName'] ?? 'Doctor'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Full Record'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text(
                                      'Complete Medical Record',
                                    ),
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
                                            'Date',
                                            record['date']?.toString().split(
                                                  ' ',
                                                )[0] ??
                                                'Not specified',
                                          ),
                                          _buildInfoRow(
                                            'Doctor',
                                            record['providerName'] ?? 'Unknown',
                                          ),

                                          const Divider(height: 20),

                                          if (record['clinicalNotes'] != null &&
                                              record['clinicalNotes']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Clinical Notes:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(record['clinicalNotes']),
                                            const SizedBox(height: 12),
                                          ],

                                          if (record['diagnosis'] != null &&
                                              record['diagnosis']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Diagnosis:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(record['diagnosis']),
                                            const SizedBox(height: 12),
                                          ],

                                          if (record['prescriptions'] != null &&
                                              (record['prescriptions'] as List)
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Prescriptions:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ...List<String>.from(
                                              record['prescriptions'],
                                            ).map(
                                              (med) => Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8.0,
                                                  top: 2.0,
                                                ),
                                                child: Text('• $med'),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],

                                          if (record['labRequests'] != null &&
                                              (record['labRequests'] as List)
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Lab Requests:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ...List<String>.from(
                                              record['labRequests'],
                                            ).map(
                                              (lab) => Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8.0,
                                                  top: 2.0,
                                                ),
                                                child: Text('• $lab'),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],

                                          if (record['radiologyRequests'] !=
                                                  null &&
                                              (record['radiologyRequests']
                                                      as List)
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Radiology Requests:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ...List<String>.from(
                                              record['radiologyRequests'],
                                            ).map(
                                              (rad) => Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8.0,
                                                  top: 2.0,
                                                ),
                                                child: Text('• $rad'),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                          ],

                                          if (record['followUp'] != null &&
                                              record['followUp']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Follow-up:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(record['followUp']),
                                            const SizedBox(height: 12),
                                          ],

                                          if (record['notes'] != null &&
                                              record['notes']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const Text(
                                              'Additional Notes:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(record['notes']),
                                          ],
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
