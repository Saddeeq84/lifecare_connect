import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'patient_medical_records_viewer.dart';

class MedicalRecordsPatientRecordsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const MedicalRecordsPatientRecordsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<MedicalRecordsPatientRecordsScreen> createState() =>
      _MedicalRecordsPatientRecordsScreenState();
}

class _MedicalRecordsPatientRecordsScreenState
    extends State<MedicalRecordsPatientRecordsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Records'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient name or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Patients List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facility_patients')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.red.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allRecords = snapshot.data?.docs ?? [];

                // Sort by createdAt in memory to avoid composite index requirement
                allRecords.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // descending order
                });

                // Filter records based on search query
                final filteredRecords = allRecords.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final patientName =
                      (data['patientName'] as String? ??
                              data['name'] as String? ??
                              '')
                          .toLowerCase();
                  final patientId = (data['patientId'] as String? ?? doc.id)
                      .toLowerCase();
                  return patientName.contains(_searchQuery) ||
                      patientId.contains(_searchQuery);
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
                          _searchQuery.isEmpty
                              ? 'No Patients'
                              : 'No patients found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Registered patients will appear here'
                              : 'Try a different search term',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredRecords.length,
                  itemBuilder: (context, index) {
                    final record =
                        filteredRecords[index].data() as Map<String, dynamic>;
                    final recordId = filteredRecords[index].id;
                    return _buildRecordCard(
                      context,
                      record,
                      recordId,
                      index + 1,
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

  Widget _buildRecordCard(
    BuildContext context,
    Map<String, dynamic> record,
    String recordId,
    int displayIndex,
  ) {
    final patientName =
        record['patientName'] as String? ??
        record['name'] as String? ??
        'Unknown';
    final patientId = record['patientId'] as String? ?? recordId;
    final phone =
        record['phone'] as String? ?? record['phoneNumber'] as String? ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Patient Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Patient Info
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // View Button
            ElevatedButton.icon(
              onPressed: () =>
                  _viewPatientRecords(context, patientId, patientName),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('View Records'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewPatientRecords(
    BuildContext context,
    String patientId,
    String patientName,
  ) async {
    // Get all admissions for this patient (active AND discharged) to show complete history
    final admissionSnapshot = await FirebaseFirestore.instance
        .collection('admissions')
        .where('patientId', isEqualTo: patientId)
        .limit(10)
        .get();

    // Show as inpatient if there's ANY admission history (current or past)
    final bool hasAdmissionHistory = admissionSnapshot.docs.isNotEmpty;

    // Get the most recent admission by sorting in memory
    Map<String, dynamic>? admissionData;
    if (hasAdmissionHistory) {
      final admissions = admissionSnapshot.docs;
      admissions.sort((a, b) {
        final aDate = (a.data()['admissionDate'] as Timestamp?);
        final bDate = (b.data()['admissionDate'] as Timestamp?);
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });
      admissionData = admissions.first.data();
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PatientMedicalRecordsViewer(
            patientId: patientId,
            patientName: patientName,
            facilityId: widget.facilityId,
            isInpatient:
                false, // They're not currently admitted if viewing from Patient Records
            hasAdmissionHistory: hasAdmissionHistory,
            admissionData: admissionData,
          ),
        ),
      );
    }
  }
}
