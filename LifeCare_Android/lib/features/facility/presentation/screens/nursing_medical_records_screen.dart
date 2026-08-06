import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NursingMedicalRecordsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const NursingMedicalRecordsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<NursingMedicalRecordsScreen> createState() =>
      _NursingMedicalRecordsScreenState();
}

class _NursingMedicalRecordsScreenState
    extends State<NursingMedicalRecordsScreen> {
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
        title: const Text('Medical Records'),
        backgroundColor: Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Only Medical Records',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All patient records with completed consultations, vital signs, prescriptions, and lab results are displayed here for viewing only.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by patient name...',
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
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Completed Medical Records List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('health_records')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('type', isEqualTo: 'CONSULTATION_NOTE')
                  .orderBy('timestamp', descending: true)
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

                final consultationRecords = snapshot.data?.docs ?? [];

                // Filter by search query
                final filteredRecords = consultationRecords.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName =
                      data['patientName']?.toString().toLowerCase() ?? '';
                  return _searchQuery.isEmpty ||
                      patientName.contains(_searchQuery);
                }).toList();

                if (filteredRecords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No records found matching "$_searchQuery"'
                              : 'No completed consultations found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patient medical records will appear here after consultations are completed.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record =
                        filteredRecords[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
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
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade700,
                                  child: Text(
                                    record['patientName']?[0]?.toUpperCase() ??
                                        'P',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record['patientName'] ??
                                            'Unknown Patient',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Patient ID: ${record['patientId'] ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        'Consultation: ${_formatDateTime(record['timestamp'])}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'COMPLETED',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Medical Records Info
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.medical_information,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Complete Medical Records Available',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Vital signs, consultation notes, prescriptions & lab results',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // View Records Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _showMedicalRecordsDetails(
                                  context,
                                  record['patientId'],
                                ),
                                icon: const Icon(Icons.visibility),
                                label: const Text('View Medical Records'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
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

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showMedicalRecordsDetails(BuildContext context, String patientId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.medical_information,
                      color: Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Complete Medical Records',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Medical records content
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('health_records')
                      .where('facilityId', isEqualTo: widget.facilityId)
                      .where('patientId', isEqualTo: patientId)
                      .orderBy('timestamp', descending: true)
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
                            Icon(
                              Icons.error,
                              size: 64,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text('Error loading records: ${snapshot.error}'),
                          ],
                        ),
                      );
                    }

                    final allRecords = snapshot.data?.docs ?? [];

                    if (allRecords.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No medical records found for this patient',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: allRecords.length,
                      itemBuilder: (context, index) {
                        final record =
                            allRecords[index].data() as Map<String, dynamic>;
                        final recordType = record['type'] ?? '';

                        return _buildMedicalRecordCard(record, recordType);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> record, String type) {
    IconData icon;
    Color color;
    String title;

    switch (type) {
      case 'VITAL_SIGNS':
        icon = Icons.monitor_heart;
        color = Colors.red;
        title = 'Vital Signs';
        break;
      case 'CONSULTATION_NOTE':
        icon = Icons.note_add;
        color = Colors.blue;
        title = 'Consultation Note';
        break;
      case 'PRESCRIPTION':
        icon = Icons.local_pharmacy;
        color = Colors.green;
        title = 'Prescription';
        break;
      case 'LAB_RESULTS':
        icon = Icons.biotech;
        color = Colors.purple;
        title = 'Lab Results';
        break;
      default:
        icon = Icons.description;
        color = Colors.grey;
        title = 'Medical Record';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        _formatDateTime(record['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Record content based on type
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildRecordContent(record, type),
            ),

            if (record['providerId'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, color: Colors.grey.shade600, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Provider: ${record['providerId']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordContent(Map<String, dynamic> record, String type) {
    switch (type) {
      case 'VITAL_SIGNS':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record['bloodPressure'] != null)
              Text('Blood Pressure: ${record['bloodPressure']}'),
            if (record['heartRate'] != null)
              Text('Heart Rate: ${record['heartRate']} bpm'),
            if (record['temperature'] != null)
              Text('Temperature: ${record['temperature']}°C'),
            if (record['oxygenSaturation'] != null)
              Text('Oxygen Saturation: ${record['oxygenSaturation']}%'),
            if (record['weight'] != null)
              Text('Weight: ${record['weight']} kg'),
            if (record['height'] != null)
              Text('Height: ${record['height']} cm'),
          ],
        );
      case 'CONSULTATION_NOTE':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record['chiefComplaint'] != null) ...[
              const Text(
                'Chief Complaint:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['chiefComplaint']),
              const SizedBox(height: 8),
            ],
            if (record['diagnosis'] != null) ...[
              const Text(
                'Diagnosis:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['diagnosis']),
              const SizedBox(height: 8),
            ],
            if (record['treatment'] != null) ...[
              const Text(
                'Treatment Plan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['treatment']),
            ],
          ],
        );
      case 'PRESCRIPTION':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record['medications'] is List) ...[
              const Text(
                'Medications:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...(record['medications'] as List).map(
                (med) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• $med'),
                ),
              ),
            ] else if (record['medication'] != null) ...[
              const Text(
                'Medication:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['medication']),
            ],
            if (record['dosage'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Dosage:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['dosage']),
            ],
            if (record['instructions'] != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Instructions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['instructions']),
            ],
          ],
        );
      case 'LAB_RESULTS':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record['testName'] != null) ...[
              const Text(
                'Test:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['testName']),
              const SizedBox(height: 8),
            ],
            if (record['results'] != null) ...[
              const Text(
                'Results:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['results']),
              const SizedBox(height: 8),
            ],
            if (record['normalRange'] != null) ...[
              const Text(
                'Normal Range:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(record['normalRange']),
            ],
          ],
        );
      default:
        return Text(record.toString());
    }
  }
}
