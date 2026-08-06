import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'patient_medical_records_viewer.dart';

class InpatientDashboardScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const InpatientDashboardScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<InpatientDashboardScreen> createState() =>
      _InpatientDashboardScreenState();
}

class _InpatientDashboardScreenState extends State<InpatientDashboardScreen> {
  String _selectedFilter = 'all';

  String _calculateLengthOfStay(Timestamp? admissionDate) {
    if (admissionDate == null) return 'N/A';
    final admission = admissionDate.toDate();
    final now = DateTime.now();
    final difference = now.difference(admission);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'}';
    } else {
      return '< 1 hour';
    }
  }

  Future<Map<String, dynamic>?> _getWardInfo(String wardId) async {
    try {
      final wardDoc = await FirebaseFirestore.instance
          .collection('wards')
          .doc(wardId)
          .get();
      return wardDoc.data();
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getBedInfo(String bedId, String wardId) async {
    try {
      final bedDoc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('wards')
          .doc(wardId)
          .collection('beds')
          .doc(bedId)
          .get();
      return bedDoc.data();
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.facilityName} - Inpatients'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _selectedFilter == 'all',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Critical'),
                    selected: _selectedFilter == 'critical',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'critical');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Serious'),
                    selected: _selectedFilter == 'serious',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'serious');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Stable'),
                    selected: _selectedFilter == 'stable',
                    onSelected: (selected) {
                      setState(() => _selectedFilter = 'stable');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Admissions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedFilter == 'all'
                  ? FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .where('isActive', isEqualTo: true)
                        .orderBy('admissionDate', descending: true)
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .where('isActive', isEqualTo: true)
                        .where('patientStatus', isEqualTo: _selectedFilter)
                        .orderBy('admissionDate', descending: true)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final admissions = snapshot.data!.docs;

                if (admissions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hotel, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No admitted patients',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: admissions.length,
                  itemBuilder: (context, index) {
                    final admission =
                        admissions[index].data() as Map<String, dynamic>;
                    final admissionDate =
                        admission['admissionDate'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          // Navigate to patient medical records viewer
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientMedicalRecordsViewer(
                                patientId: admission['patientId'] ?? '',
                                patientName:
                                    admission['patientName'] ?? 'Unknown',
                                facilityId: widget.facilityId,
                                isInpatient: true,
                                admissionData: admission,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          admission['patientName'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FutureBuilder<Map<String, dynamic>?>(
                                          future: _getWardInfo(
                                            admission['wardId'],
                                          ),
                                          builder: (context, wardSnapshot) {
                                            return FutureBuilder<
                                              Map<String, dynamic>?
                                            >(
                                              future: _getBedInfo(
                                                admission['bedId'],
                                                admission['wardId'],
                                              ),
                                              builder: (context, bedSnapshot) {
                                                String location = 'Loading...';
                                                if (wardSnapshot.hasData &&
                                                    bedSnapshot.hasData) {
                                                  final wardName =
                                                      wardSnapshot
                                                          .data?['wardName'] ??
                                                      'Unknown Ward';
                                                  final bedNumber =
                                                      bedSnapshot
                                                          .data?['bedNumber'] ??
                                                      'Unknown Bed';
                                                  location =
                                                      '$wardName - Bed $bedNumber';
                                                }
                                                return Text(
                                                  location,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Condition badge removed for Patient Management
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Diagnosis',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          admission['admissionDiagnosis'] ??
                                              'N/A',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Length of Stay: ${_calculateLengthOfStay(admissionDate)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Admitted: ${admissionDate != null ? DateFormat('MMM dd, yyyy').format(admissionDate.toDate()) : 'N/A'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Dr. ${admission['admittingDoctorName'] ?? 'Unknown'}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
}
