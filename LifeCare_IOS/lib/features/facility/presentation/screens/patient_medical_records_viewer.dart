import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../utils/print_utils.dart';
import '../widgets/fluid_balance_chart.dart';

class PatientMedicalRecordsViewer extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String facilityId;
  final String? appointmentId; // Optional: to show specific appointment records
  final bool isInpatient; // True if currently admitted
  final bool
  hasAdmissionHistory; // True if patient was ever admitted (shows Ward Rounds tab)
  final Map<String, dynamic>? admissionData; // Admission details for inpatients

  const PatientMedicalRecordsViewer({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.facilityId,
    this.appointmentId,
    this.isInpatient = false,
    this.hasAdmissionHistory = false,
    this.admissionData,
  });

  @override
  State<PatientMedicalRecordsViewer> createState() =>
      _PatientMedicalRecordsViewerState();
}

class _PatientMedicalRecordsViewerState
    extends State<PatientMedicalRecordsViewer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    print('🔍 PatientMedicalRecordsViewer initialized:');
    print('   Patient: ${widget.patientName}');
    print('   isInpatient: ${widget.isInpatient}');
    print('   hasAdmissionHistory: ${widget.hasAdmissionHistory}');
    print('   admissionData: ${widget.admissionData != null ? "YES" : "NO"}');
    // Always show 7 tabs including Admission History and Fluid Balance for all patients
    _tabController = TabController(length: 7, vsync: this);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isInpatient ? 'Inpatient Records' : 'Medical Records',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              widget.patientName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: widget.isInpatient
            ? Colors.teal.shade700
            : Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.monitor_heart), text: 'Vitals'),
            Tab(icon: Icon(Icons.medical_services), text: 'Consultations'),
            Tab(icon: Icon(Icons.local_hospital), text: 'Admission History'),
            Tab(icon: Icon(Icons.science), text: 'Lab Tests'),
            Tab(icon: Icon(Icons.medication), text: 'Medications'),
            Tab(icon: Icon(Icons.healing), text: 'Procedures'),
            Tab(icon: Icon(Icons.water_drop), text: 'Fluid Balance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVitalsTab(),
          _buildConsultationsTab(),
          _buildAdmissionHistoryTab(),
          _buildLabTestsTab(),
          _buildMedicationsTab(),
          _buildProceduresTab(),
          FluidBalanceChart(
            patientId: widget.patientId,
            patientName: widget.patientName,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalsTab() {
    Query query = FirebaseFirestore.instance
        .collection('vitals_records')
        .where('patientId', isEqualTo: widget.patientId)
        .where('facilityId', isEqualTo: widget.facilityId)
        .orderBy('recordedAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.monitor_heart_outlined,
            title: 'No Vital Signs',
            message: 'No vital signs have been recorded yet',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final vital =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildVitalCard(vital);
          },
        );
      },
    );
  }

  Widget _buildConsultationsTab() {
    // Query consultations from facility_patients/{patientId}/consultations subcollection
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('consultations')
          .orderBy('consultedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.medical_services_outlined,
            title: 'No Consultations',
            message: 'No consultation records found',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final consultation =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildConsultationCard(consultation);
          },
        );
      },
    );
  }

  Widget _buildLabTestsTab() {
    // Query ALL lab tests from pending_lab_tests (both pending and completed),
    // health_records (new completed tests), and lab_results (laboratory dashboard completed)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, pendingLabsSnapshot) {
        // Also query completed tests from health_records
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: widget.patientId)
              .where('facilityId', isEqualTo: widget.facilityId)
              .where('recordType', isEqualTo: 'laboratory')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, healthRecordsSnapshot) {
            // Also query from lab_results collection (laboratory dashboard)
            // Note: lab_results might not have patientId indexed, so we filter in memory
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lab_results')
                  .where('facilityId', isEqualTo: widget.facilityId)
                  .orderBy('completedAt', descending: true)
                  .snapshots(),
              builder: (context, labResultsSnapshot) {
                if (pendingLabsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    healthRecordsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    labResultsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (pendingLabsSnapshot.hasError ||
                    healthRecordsSnapshot.hasError ||
                    labResultsSnapshot.hasError) {
                  return Center(child: Text('Error loading lab tests'));
                }

                // Combine all lab tests from all three collections
                final List<Map<String, dynamic>> allTests = [];

                // Add all tests from pending_lab_tests (pending + old completed)
                if (pendingLabsSnapshot.hasData) {
                  allTests.addAll(
                    pendingLabsSnapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList(),
                  );
                }

                // Add completed tests from health_records (new completed)
                if (healthRecordsSnapshot.hasData) {
                  allTests.addAll(
                    healthRecordsSnapshot.data!.docs
                        .map((doc) => doc.data() as Map<String, dynamic>)
                        .toList(),
                  );
                }

                // Add completed tests from lab_results (laboratory dashboard)
                // Filter by patientId in memory since it might not be indexed
                if (labResultsSnapshot.hasData) {
                  final filteredLabResults = labResultsSnapshot.data!.docs
                      .where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['patientId'] == widget.patientId;
                      })
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .toList();
                  allTests.addAll(filteredLabResults);
                }

                // Sort by createdAt or completedAt descending
                allTests.sort((a, b) {
                  final aTime =
                      (a['createdAt'] ?? a['completedAt']) as Timestamp?;
                  final bTime =
                      (b['createdAt'] ?? b['completedAt']) as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                if (allTests.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.science_outlined,
                    title: 'No Lab Tests',
                    message: 'No laboratory test results found',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: allTests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildLabTestCard(allTests[index]);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMedicationsTab() {
    // Query medications from pending_prescriptions collection
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_prescriptions')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.medication_outlined,
            title: 'No Medications',
            message: 'No medication records found',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final medication =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildMedicationCard(medication);
          },
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildOverviewTab() {
    if (widget.admissionData == null) {
      return _buildEmptyState(
        icon: Icons.info_outline,
        title: 'No Admission Data',
        message: 'Admission information not available',
      );
    }

    final admission = widget.admissionData!;
    final admissionDate = (admission['admissionDate'] as Timestamp?)?.toDate();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Status Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.teal.shade700, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Patient Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Patient Name',
                    admission['patientName'] ?? 'Unknown',
                  ),
                  _buildInfoRow(
                    'Admission Type',
                    (admission['admissionType'] ?? 'N/A')
                        .toString()
                        .toUpperCase(),
                  ),
                  _buildInfoRow(
                    'Status',
                    (admission['patientStatus'] ?? 'N/A')
                        .toString()
                        .toUpperCase(),
                  ),
                  _buildInfoRow(
                    'Expected Duration',
                    admission['expectedDuration'] ?? 'N/A',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Admission Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orange.shade100),
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
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Admission Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    'Diagnosis',
                    admission['admissionDiagnosis'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Admitting Doctor',
                    admission['admittingDoctorName'] ?? 'N/A',
                  ),
                  _buildInfoRow(
                    'Admission Date',
                    admissionDate != null
                        ? DateFormat('MMM dd, yyyy HH:mm').format(admissionDate)
                        : 'N/A',
                  ),
                  _buildInfoRow(
                    'Length of Stay',
                    admissionDate != null
                        ? _calculateLengthOfStay(
                            admission['admissionDate'] as Timestamp,
                          )
                        : 'N/A',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Ward & Bed Info Card
          FutureBuilder<Map<String, String>>(
            future: _getWardAndBedInfo(
              admission['wardId'],
              admission['bedId'],
              widget.facilityId,
            ),
            builder: (context, snapshot) {
              final wardBedInfo =
                  snapshot.data ?? {'ward': 'Loading...', 'bed': 'Loading...'};

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.hotel,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ward & Bed Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Ward', wardBedInfo['ward']!),
                      _buildInfoRow('Bed Number', wardBedInfo['bed']!),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Admission Notes Card
          if (admission['admissionNotes'] != null &&
              admission['admissionNotes'].toString().isNotEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.purple.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notes,
                          color: Colors.purple.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Admission Notes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      admission['admissionNotes'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdmissionHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllAdmissionRecords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allRecords = snapshot.data ?? [];

        if (allRecords.isEmpty) {
          return _buildEmptyState(
            icon: Icons.local_hospital_outlined,
            title: 'No Admission History',
            message: 'No ward rounds or discharge records found',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: allRecords.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final record = allRecords[index];
            if (record['_type'] == 'discharge') {
              return _buildDischargeNoteCard(record);
            } else if (record['_type'] == 'daily_report') {
              return _buildDailyReportCard(record);
            } else {
              return _buildWardRoundCard(record);
            }
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getAllAdmissionRecords() async {
    final allRecords = <Map<String, dynamic>>[];

    // Get all admissions for this patient
    final admissionsSnapshot = await FirebaseFirestore.instance
        .collection('admissions')
        .where('patientId', isEqualTo: widget.patientId)
        .limit(20)
        .get();

    // For each admission, get ward rounds and daily reports
    for (var admissionDoc in admissionsSnapshot.docs) {
      final wardRoundsSnapshot = await admissionDoc.reference
          .collection('ward_rounds')
          .get();

      for (var wardRoundDoc in wardRoundsSnapshot.docs) {
        allRecords.add({
          ...wardRoundDoc.data(),
          '_type': 'ward_round',
          '_id': wardRoundDoc.id,
        });
      }

      // Get daily reports for this admission
      final dailyReportsSnapshot = await admissionDoc.reference
          .collection('daily_reports')
          .get();

      for (var reportDoc in dailyReportsSnapshot.docs) {
        allRecords.add({
          ...reportDoc.data(),
          '_type': 'daily_report',
          '_id': reportDoc.id,
        });
      }
    }

    // Get discharge notes from health_records
    final dischargeNotesSnapshot = await FirebaseFirestore.instance
        .collection('health_records')
        .where('patientId', isEqualTo: widget.patientId)
        .where('type', isEqualTo: 'WARD_DISCHARGE')
        .limit(50)
        .get();

    for (var dischargeDoc in dischargeNotesSnapshot.docs) {
      allRecords.add({
        ...dischargeDoc.data(),
        '_type': 'discharge',
        '_id': dischargeDoc.id,
      });
    }

    // Sort by date descending
    allRecords.sort((a, b) {
      final aDate =
          (a['roundDate'] ?? a['reportDate'] ?? a['date'] ?? a['createdAt'])
              as Timestamp?;
      final bDate =
          (b['roundDate'] ?? b['reportDate'] ?? b['date'] ?? b['createdAt'])
              as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    return allRecords;
  }

  // ignore: unused_element
  Stream<List<QuerySnapshot>> _combineWardRoundsAndDischarges() {
    final wardRoundsStream = FirebaseFirestore.instance
        .collection('ward_rounds')
        .where('patientId', isEqualTo: widget.patientId)
        .limit(50)
        .snapshots();

    final dischargeNotesStream = FirebaseFirestore.instance
        .collection('health_records')
        .where('patientId', isEqualTo: widget.patientId)
        .where('type', isEqualTo: 'WARD_DISCHARGE')
        .limit(50)
        .snapshots();

    return wardRoundsStream.asyncMap((wardRounds) async {
      final discharges = await dischargeNotesStream.first;
      return [wardRounds, discharges];
    });
  }

  Widget _buildDischargeNoteCard(Map<String, dynamic> discharge) {
    final dischargeDate =
        (discharge['dischargeDate'] ?? discharge['date']) as Timestamp?;
    final data = discharge['data'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.exit_to_app,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DISCHARGE NOTE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (dischargeDate != null)
                        Text(
                          DateFormat(
                            'MMM dd, yyyy - hh:mm a',
                          ).format(dischargeDate.toDate()),
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
            const Divider(height: 24),

            // Discharge Type
            _buildDischargeInfoRow(
              'Discharge Type',
              (discharge['dischargeType'] ?? data['dischargeType'] ?? 'N/A')
                  .toString()
                  .toUpperCase(),
              Colors.green.shade700,
            ),

            // Discharged By
            if (discharge['providerName'] != null ||
                data['dischargedBy'] != null)
              _buildDischargeInfoRow(
                'Discharged By',
                discharge['providerName'] ?? data['dischargedBy'] ?? 'N/A',
                Colors.grey.shade700,
              ),

            // Discharge Summary
            if ((discharge['dischargeSummary'] ?? data['dischargeSummary'])
                    ?.isNotEmpty ==
                true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Discharge Summary:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      discharge['dischargeSummary'] ??
                          data['dischargeSummary'] ??
                          '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

            // Follow-up Instructions
            if ((discharge['followUpInstructions'] ??
                        data['followUpInstructions'])
                    ?.isNotEmpty ==
                true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Follow-up Instructions:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      discharge['followUpInstructions'] ??
                          data['followUpInstructions'] ??
                          '',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),

            // Medications
            if ((discharge['medications'] ?? data['dischargeMedications'])
                    ?.isNotEmpty ==
                true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.medication,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Discharge Medications:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(discharge['medications'] ??
                          data['dischargeMedications'] ??
                          [])
                      .map<Widget>((med) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(color: Colors.orange.shade700),
                              ),
                              Expanded(
                                child: Text(
                                  med.toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                ],
              ),

            // Lab Tests
            if ((discharge['labTests'] ?? data['dischargeLabTests'])
                    ?.isNotEmpty ==
                true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.science,
                        size: 16,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Discharge Lab Tests:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(discharge['labTests'] ?? data['dischargeLabTests'] ?? [])
                      .map<Widget>((test) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 20, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(color: Colors.purple.shade700),
                              ),
                              Expanded(
                                child: Text(
                                  test.toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDischargeInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportCard(Map<String, dynamic> report) {
    final reportDate =
        (report['reportDate'] ?? report['createdAt']) as Timestamp?;
    final shift = report['shift'] ?? 'N/A';
    final reportedBy = report['reportedBy'] ?? 'Unknown';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepOrange.shade200, width: 2),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.description,
            color: Colors.deepOrange.shade700,
            size: 24,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '24-HOUR NURSING REPORT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            if (reportDate != null)
              Text(
                DateFormat('MMM dd, yyyy').format(reportDate.toDate()),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        subtitle: Text(
          '$shift • by $reportedBy',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report['chiefComplaints'] != null &&
                    (report['chiefComplaints'] as String).isNotEmpty) ...[
                  _buildReportSection(
                    'Chief Complaints',
                    report['chiefComplaints'],
                  ),
                  const Divider(height: 24),
                ],
                if (report['vitalSigns'] != null &&
                    (report['vitalSigns'] as String).isNotEmpty) ...[
                  _buildReportSection('Vital Signs', report['vitalSigns']),
                  const Divider(height: 24),
                ],
                if (report['consciousnessLevel'] != null ||
                    report['respiratoryStatus'] != null ||
                    report['cardiovascularStatus'] != null ||
                    report['mobilityStatus'] != null ||
                    report['skinIntegrity'] != null) ...[
                  Text(
                    'Assessment Findings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (report['consciousnessLevel'] != null)
                    _buildInfoRow(
                      'Consciousness:',
                      report['consciousnessLevel'],
                    ),
                  if (report['respiratoryStatus'] != null)
                    _buildInfoRow('Respiratory:', report['respiratoryStatus']),
                  if (report['cardiovascularStatus'] != null)
                    _buildInfoRow(
                      'Cardiovascular:',
                      report['cardiovascularStatus'],
                    ),
                  if (report['mobilityStatus'] != null)
                    _buildInfoRow('Mobility:', report['mobilityStatus']),
                  if (report['skinIntegrity'] != null)
                    _buildInfoRow('Skin Integrity:', report['skinIntegrity']),
                  const Divider(height: 24),
                ],
                if (report['nursingAssessment'] != null &&
                    (report['nursingAssessment'] as String).isNotEmpty) ...[
                  _buildReportSection(
                    'Nursing Assessment',
                    report['nursingAssessment'],
                  ),
                  const Divider(height: 24),
                ],
                if (report['interventions'] != null &&
                    (report['interventions'] as String).isNotEmpty) ...[
                  _buildReportSection('Interventions', report['interventions']),
                  const Divider(height: 24),
                ],
                if (report['evaluation'] != null &&
                    (report['evaluation'] as String).isNotEmpty) ...[
                  _buildReportSection('Evaluation', report['evaluation']),
                  const Divider(height: 24),
                ],
                if (report['plan'] != null &&
                    (report['plan'] as String).isNotEmpty) ...[
                  _buildReportSection('Plan for Next 24 Hours', report['plan']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.deepOrange.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildImagingTab() {
    // Query imaging tests from pending_imaging collection
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_imaging')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.camera_alt_outlined,
            title: 'No Imaging Tests',
            message: 'No imaging/radiology tests found',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final imaging =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildImagingCard(imaging);
          },
        );
      },
    );
  }

  Widget _buildProceduresTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('nursing_procedures')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('performedAt', descending: true)
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
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading procedures',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final procedures = snapshot.data?.docs ?? [];

        if (procedures.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.healing_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No procedures recorded',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: procedures.length,
          itemBuilder: (context, index) {
            final procedureDoc = procedures[index];
            final procedure = procedureDoc.data() as Map<String, dynamic>;
            return _buildProcedureCard(procedure);
          },
        );
      },
    );
  }

  Widget _buildProcedureCard(Map<String, dynamic> procedure) {
    final performedAt = (procedure['performedAt'] as Timestamp?)?.toDate();
    final performedBy = procedure['performedBy'] ?? 'Unknown';
    final procedureName = procedure['procedureName'] ?? 'Unknown Procedure';
    final procedureCategory = procedure['procedureCategory'] ?? '';
    final notes = procedure['notes'] ?? '';
    final patientResponse = procedure['patientResponse'] ?? '';
    final procedureFee = (procedure['procedureFee'] as num?)?.toDouble() ?? 0.0;
    final paymentStatus = procedure['paymentStatus'] ?? '';
    final duration = (procedure['duration'] as num?)?.toDouble();
    final hourlyRate = (procedure['hourlyRate'] as num?)?.toDouble();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.healing,
                    color: Colors.purple.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        procedureName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      if (procedureCategory.isNotEmpty)
                        Text(
                          procedureCategory,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                if (performedAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(performedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(performedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 24),

            // Performed By
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Performed by: ',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Text(
                  performedBy,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Fee (if applicable)
            if (procedureFee > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (duration != null && hourlyRate != null) ...[
                          Text(
                            '${duration}hrs × ₦${hourlyRate.toStringAsFixed(2)}/hr = ₦${procedureFee.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Fee: ₦${procedureFee.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (paymentStatus == 'paid') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'PAID',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Notes
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Text(
                          'Procedure Notes:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Patient Response
            if (patientResponse.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.feedback,
                          size: 14,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Patient Response:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      patientResponse,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVitalCard(Map<String, dynamic> vital) {
    final recordedAt = (vital['recordedAt'] as Timestamp?)?.toDate();
    final recordedBy =
        vital['recordedByName'] ?? vital['recordedBy'] ?? 'Unknown';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vital Signs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                if (recordedAt != null)
                  Text(
                    DateFormat('MMM dd, yyyy HH:mm').format(recordedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const Divider(height: 24),
            _buildVitalRow('Temperature', vital['temperature'], '°C'),
            _buildVitalRow('Blood Pressure', vital['bloodPressure'], 'mmHg'),
            _buildVitalRow('Pulse', vital['pulse'], 'bpm'),
            _buildVitalRow(
              'Respiratory Rate',
              vital['respiratoryRate'],
              '/min',
            ),
            _buildVitalRow('Oxygen Saturation', vital['oxygenSaturation'], '%'),
            if (vital['weight'] != null &&
                vital['weight'].toString().isNotEmpty)
              _buildVitalRow('Weight', vital['weight'], 'kg'),
            if (vital['notes'] != null &&
                vital['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                vital['notes'],
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'Recorded by: $recordedBy',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalRow(String label, dynamic value, String unit) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          Text(
            '$value $unit',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> consultation) {
    final consultedAt = (consultation['consultedAt'] as Timestamp?)?.toDate();
    final clinicianName = consultation['clinicianName'] ?? 'Unknown';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  color: Colors.purple.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Consultation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (consultedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(consultedAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const Divider(height: 24),

            if (consultation['complaints'] != null &&
                consultation['complaints'].toString().isNotEmpty) ...[
              _buildInfoSection(
                'Presenting Complaints',
                consultation['complaints'],
              ),
              const SizedBox(height: 12),
            ],

            if (consultation['history'] != null &&
                consultation['history'].toString().isNotEmpty) ...[
              _buildInfoSection('History', consultation['history']),
              const SizedBox(height: 12),
            ],

            if (consultation['examination'] != null &&
                consultation['examination'].toString().isNotEmpty) ...[
              _buildInfoSection(
                'Examination Findings',
                consultation['examination'],
              ),
              const SizedBox(height: 12),
            ],

            if (consultation['diagnosis'] != null &&
                consultation['diagnosis'].toString().isNotEmpty) ...[
              _buildInfoSection('Diagnosis', consultation['diagnosis']),
              const SizedBox(height: 12),
            ],

            if (consultation['treatmentPlan'] != null &&
                consultation['treatmentPlan'].toString().isNotEmpty) ...[
              _buildInfoSection(
                'Treatment Plan',
                consultation['treatmentPlan'],
              ),
              const SizedBox(height: 12),
            ],

            if (consultation['followUp'] != null &&
                consultation['followUp'].toString().isNotEmpty) ...[
              _buildInfoSection('Follow-up', consultation['followUp']),
              const SizedBox(height: 12),
            ],

            if (consultation['prescriptions'] != null &&
                (consultation['prescriptions'] as List).isNotEmpty) ...[
              Text(
                'Prescriptions:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...(consultation['prescriptions'] as List).map(
                (prescription) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $prescription',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (consultation['labTests'] != null &&
                (consultation['labTests'] as List).isNotEmpty) ...[
              Text(
                'Lab Tests Ordered:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...(consultation['labTests'] as List).map(
                (test) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $test', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Consulted by: $clinicianName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabTestCard(Map<String, dynamic> labTest) {
    final createdAt = (labTest['createdAt'] as Timestamp?)?.toDate();
    final status = labTest['status'] ?? 'pending';

    // Handle clinicianName which might be a string or a map
    String clinicianName = 'Unknown';
    if (labTest['clinicianName'] != null) {
      if (labTest['clinicianName'] is String) {
        clinicianName = labTest['clinicianName'] as String;
      } else {
        clinicianName = labTest['clinicianName'].toString();
      }
    }

    // Handle cost which might be a number or a map
    double cost = 0;
    if (labTest['cost'] != null) {
      if (labTest['cost'] is num) {
        cost = (labTest['cost'] as num).toDouble();
      } else if (labTest['cost'] is String) {
        cost = double.tryParse(labTest['cost']) ?? 0;
      } else if (labTest['cost'] is Map) {
        // If it's a map, try to get a 'cost' or 'amount' field
        final costMap = labTest['cost'] as Map;
        cost = (costMap['cost'] ?? costMap['amount'] ?? 0) is num
            ? ((costMap['cost'] ?? costMap['amount'] ?? 0) as num).toDouble()
            : 0;
      }
    }

    // Handle testName which might be a string or a map
    String testName = 'Lab Test';
    if (labTest['testName'] != null) {
      if (labTest['testName'] is String) {
        testName = labTest['testName'] as String;
      } else if (labTest['testName'] is Map) {
        // If it's a map, try to get the 'name' field
        testName =
            (labTest['testName'] as Map)['name']?.toString() ?? 'Lab Test';
      } else {
        testName = labTest['testName'].toString();
      }
    }

    // Handle results - keep as original type for proper printing
    dynamic resultsData = labTest['results'];
    String resultsDisplay = '';
    if (resultsData != null) {
      resultsDisplay = resultsData is String
          ? resultsData
          : resultsData.toString();
    }

    // Handle notes
    String notes = '';
    if (labTest['notes'] != null) {
      notes = labTest['notes'] is String
          ? labTest['notes']
          : labTest['notes'].toString();
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.orange.shade50.withOpacity(0.3)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.biotech,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          testName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy • HH:mm',
                                ).format(createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                  const SizedBox(width: 8),
                  // Print Button
                  IconButton(
                    onPressed: () => _printLabTest(
                      labTest,
                      testName,
                      clinicianName,
                      cost,
                      createdAt,
                      resultsData,
                      notes,
                    ),
                    icon: const Icon(Icons.print, color: Colors.white),
                    tooltip: 'Print Test Results',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Test Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ordered By',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 16,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      clinicianName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Test Cost',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₦${cost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Results Section - Show "View Results" button for any test with results
                  if (resultsDisplay.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showLabResultsDialog(
                          labTest,
                          testName,
                          clinicianName,
                          cost,
                          createdAt,
                          resultsData,
                          notes,
                        ),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('View Test Results'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Notes Section - Enhanced for readability
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.shade100.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notes Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.sticky_note_2,
                                    color: Colors.amber.shade700,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'CLINICAL NOTES',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Notes Content
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(
                              notes,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.8,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLabResultsDialog(
    Map<String, dynamic> labTest,
    String testName,
    String clinicianName,
    double cost,
    DateTime? createdAt,
    dynamic results,
    String notes,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.biotech, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            testName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'MMM dd, yyyy • HH:mm',
                              ).format(createdAt),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Test Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ordered By',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    clinicianName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Test Cost',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₦${cost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Results
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.analytics,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'TEST RESULTS',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(20),
                              child: _buildFormattedResults(results),
                            ),
                          ],
                        ),
                      ),
                      // Notes
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.sticky_note_2,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'CLINICAL NOTES',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(20),
                                child: SelectableText(
                                  notes,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.8,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printLabTest(
                          labTest,
                          testName,
                          clinicianName,
                          cost,
                          createdAt,
                          results,
                          notes,
                        ),
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to format and display test results in a structured way
  Widget _buildFormattedResults(dynamic results) {
    // Handle different result types
    Map<String, dynamic>? parsedResults;

    if (results == null) {
      return const Text('No results available');
    }

    if (results is Map<String, dynamic>) {
      parsedResults = results;
    } else if (results is String) {
      parsedResults = _parseResultsString(results);
    } else {
      return Text(results.toString());
    }

    if (parsedResults != null && parsedResults.isNotEmpty) {
      return _buildMedicalTestTable(parsedResults);
    }

    // Fallback to plain text display
    return _buildPlainResults(results.toString());
  }

  // Parse string representation of map (e.g., "{key: {value: x, unit: y}}")
  Map<String, dynamic>? _parseResultsString(String results) {
    try {
      Map<String, dynamic> parsedMap = {};

      // Use regex to find all test entries: "TestName: {properties}"
      final pattern = RegExp(r'([^:,{}]+):\s*\{([^}]+)\}');
      final matches = pattern.allMatches(results);

      for (var match in matches) {
        final testName = match.group(1)?.trim() ?? '';
        final properties = match.group(2)?.trim() ?? '';

        if (testName.isNotEmpty && properties.isNotEmpty) {
          parsedMap[testName] = _parseValueMap(properties);
        }
      }

      return parsedMap.isNotEmpty ? parsedMap : null;
    } catch (e) {
      print('Error parsing results: $e');
      return null;
    }
  }

  Map<String, dynamic> _parseValueMap(String valueStr) {
    Map<String, dynamic> result = {};

    // Parse "value: x, unit: y, reference: z"
    List<String> parts = [];
    String current = '';

    for (int i = 0; i < valueStr.length; i++) {
      if (valueStr[i] == ',' &&
          (i + 1 >= valueStr.length || valueStr[i + 1] == ' ')) {
        parts.add(current.trim());
        current = '';
        if (i + 1 < valueStr.length && valueStr[i + 1] == ' ') {
          i++; // skip space
        }
      } else {
        current += valueStr[i];
      }
    }
    if (current.isNotEmpty) {
      parts.add(current.trim());
    }

    for (var part in parts) {
      if (part.contains(':')) {
        var kv = part.split(':');
        if (kv.length >= 2) {
          result[kv[0].trim()] = kv.sublist(1).join(':').trim();
        }
      }
    }

    return result;
  }

  // Map of abbreviated test names to full medical terms
  String _getFullTestName(String abbreviation) {
    final Map<String, String> testNameMap = {
      // Hematology Tests
      'WBC': 'White Blood Cell Count',
      'WBC Count': 'White Blood Cell Count',
      'RBC': 'Red Blood Cell Count',
      'RBC Count': 'Red Blood Cell Count',
      'HGB': 'Hemoglobin',
      'Hemoglobin': 'Hemoglobin',
      'HCT': 'Hematocrit',
      'PCV': 'Packed Cell Volume',
      'PCV/HCT': 'Packed Cell Volume / Hematocrit',
      'MCV': 'Mean Corpuscular Volume',
      'MCH': 'Mean Corpuscular Hemoglobin',
      'MCHC': 'Mean Corpuscular Hemoglobin Concentration',
      'RDW': 'Red Cell Distribution Width',
      'PLT': 'Platelet Count',
      'Platelets': 'Platelet Count',
      'MPV': 'Mean Platelet Volume',

      // White Blood Cell Differential
      'Neutrophils': 'Neutrophils',
      'NEUT': 'Neutrophils',
      'Lymphocytes': 'Lymphocytes',
      'LYMPH': 'Lymphocytes',
      'Monocytes': 'Monocytes',
      'MONO': 'Monocytes',
      'Eosinophils': 'Eosinophils',
      'EOS': 'Eosinophils',
      'E': 'Eosinophils',
      'Basophils': 'Basophils',
      'BASO': 'Basophils',
      'B': 'Basophils',

      // Chemistry Tests
      'GLU': 'Glucose',
      'Glucose': 'Glucose',
      'BUN': 'Blood Urea Nitrogen',
      'CREAT': 'Creatinine',
      'Creatinine': 'Creatinine',
      'Na': 'Sodium',
      'Sodium': 'Sodium',
      'K': 'Potassium',
      'Potassium': 'Potassium',
      'Cl': 'Chloride',
      'Chloride': 'Chloride',
      'CO2': 'Carbon Dioxide',
      'Ca': 'Calcium',
      'Calcium': 'Calcium',
      'ALT': 'Alanine Aminotransferase',
      'AST': 'Aspartate Aminotransferase',
      'ALP': 'Alkaline Phosphatase',
      'TBIL': 'Total Bilirubin',
      'DBIL': 'Direct Bilirubin',
      'TP': 'Total Protein',
      'ALB': 'Albumin',
      'Albumin': 'Albumin',

      // Lipid Panel
      'CHOL': 'Total Cholesterol',
      'Cholesterol': 'Total Cholesterol',
      'TRIG': 'Triglycerides',
      'Triglycerides': 'Triglycerides',
      'HDL': 'High-Density Lipoprotein',
      'LDL': 'Low-Density Lipoprotein',
      'VLDL': 'Very Low-Density Lipoprotein',

      // Thyroid Tests
      'TSH': 'Thyroid Stimulating Hormone',
      'T3': 'Triiodothyronine',
      'T4': 'Thyroxine',
      'FT3': 'Free Triiodothyronine',
      'FT4': 'Free Thyroxine',

      // Other Common Tests
      'ESR': 'Erythrocyte Sedimentation Rate',
      'CRP': 'C-Reactive Protein',
      'HbA1c': 'Hemoglobin A1c',
      'PSA': 'Prostate-Specific Antigen',
      'PT': 'Prothrombin Time',
      'PTT': 'Partial Thromboplastin Time',
      'INR': 'International Normalized Ratio',
    };

    return testNameMap[abbreviation] ?? abbreviation;
  }

  Widget _buildMedicalTestTable(Map<String, dynamic> results) {
    // Sort test names alphabetically for consistency
    final sortedKeys = results.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade300, width: 2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Test Parameter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Result Value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Unit of Measure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Reference Range',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ...sortedKeys.asMap().entries.map((entry) {
          final index = entry.key;
          final testName = entry.value;
          final testData = results[testName];

          return _buildTestResultRow(testName, testData, index % 2 == 0);
        }),
      ],
    );
  }

  Widget _buildTestResultRow(String testName, dynamic testData, bool isEven) {
    String value = '-';
    String unit = '';
    String reference = '-';
    Color? statusColor;

    if (testData is Map) {
      value = testData['value']?.toString() ?? '-';
      unit = testData['unit']?.toString() ?? '';
      reference = testData['reference']?.toString() ?? '-';

      // Check if value is out of range (basic check)
      if (testData['value'] != null &&
          reference != '-' &&
          reference.contains('-')) {
        try {
          final ranges = reference.split('-');
          if (ranges.length == 2) {
            final min = double.tryParse(
              ranges[0].trim().replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            final max = double.tryParse(
              ranges[1].trim().replaceAll(RegExp(r'[^0-9.]'), ''),
            );
            final val = double.tryParse(
              value.replaceAll(RegExp(r'[^0-9.]'), ''),
            );

            if (min != null && max != null && val != null) {
              if (val < min || val > max) {
                statusColor = Colors.red.shade100;
              } else {
                statusColor = Colors.green.shade50;
              }
            }
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: statusColor ?? (isEven ? Colors.white : Colors.grey.shade50),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              _getFullTestName(testName),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor != null
                    ? (statusColor == Colors.red.shade100
                          ? Colors.red.shade900
                          : Colors.green.shade900)
                    : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              unit,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              reference,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainResults(String results) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SelectableText(
        results,
        style: const TextStyle(
          fontSize: 14,
          height: 1.8,
          color: Colors.black87,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // Print lab test results
  void _printLabTest(
    Map<String, dynamic> labTest,
    String testName,
    String clinicianName,
    double cost,
    DateTime? createdAt,
    dynamic results,
    String notes,
  ) {
    // Create a printable HTML content
    final patientName = widget.isInpatient
        ? (widget.admissionData?['patientName'] ?? widget.patientName)
        : widget.patientName;

    final patientId = widget.patientId;

    String htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Lab Test Results - $testName</title>
  <style>
    @media print {
      @page { margin: 1cm; }
      body { margin: 0; }
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 20px;
      max-width: 800px;
      margin: 0 auto;
    }
    .header {
      text-align: center;
      border-bottom: 3px solid #f57c00;
      padding-bottom: 15px;
      margin-bottom: 25px;
    }
    .header h1 {
      color: #f57c00;
      margin: 0 0 5px 0;
      font-size: 24px;
    }
    .header p {
      margin: 5px 0;
      color: #666;
    }
    .info-section {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 15px;
      margin-bottom: 25px;
      padding: 15px;
      background: #f5f5f5;
      border-radius: 8px;
    }
    .info-item {
      margin-bottom: 8px;
    }
    .info-label {
      font-weight: 600;
      color: #555;
      font-size: 12px;
      text-transform: uppercase;
    }
    .info-value {
      font-size: 14px;
      color: #000;
      margin-top: 3px;
    }
    .results-section {
      margin: 25px 0;
    }
    .section-title {
      background: #1976d2;
      color: white;
      padding: 10px 15px;
      border-radius: 6px 6px 0 0;
      font-weight: bold;
      font-size: 14px;
      letter-spacing: 1px;
    }
    .results-content {
      border: 2px solid #1976d2;
      border-top: none;
      border-radius: 0 0 6px 6px;
      padding: 20px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
    }
    th {
      background: #e3f2fd;
      padding: 12px;
      text-align: left;
      font-weight: 600;
      color: #1565c0;
      font-size: 13px;
      border-bottom: 2px solid #1976d2;
    }
    td {
      padding: 12px;
      border-bottom: 1px solid #ddd;
      font-size: 13px;
    }
    tr:nth-child(even) {
      background: #fafafa;
    }
    tr.abnormal {
      background: #ffebee !important;
    }
    tr.normal {
      background: #e8f5e9 !important;
    }
    .notes-section {
      margin: 25px 0;
    }
    .notes-content {
      border: 2px solid #ffa726;
      border-top: none;
      border-radius: 0 0 6px 6px;
      padding: 20px;
      background: #fff;
    }
    .footer {
      margin-top: 40px;
      padding-top: 15px;
      border-top: 2px solid #ddd;
      text-align: center;
      font-size: 12px;
      color: #666;
    }
    .plain-result {
      line-height: 1.8;
      white-space: pre-wrap;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>LABORATORY TEST RESULTS</h1>
    <p><strong>$testName</strong></p>
    <p>${createdAt != null ? DateFormat('MMMM dd, yyyy • HH:mm').format(createdAt) : 'N/A'}</p>
  </div>

  <div class="info-section">
    <div class="info-item">
      <div class="info-label">Patient Name</div>
      <div class="info-value">$patientName</div>
    </div>
    <div class="info-item">
      <div class="info-label">Patient ID</div>
      <div class="info-value">$patientId</div>
    </div>
    <div class="info-item">
      <div class="info-label">Ordered By</div>
      <div class="info-value">$clinicianName</div>
    </div>
    <div class="info-item">
      <div class="info-label">Test Cost</div>
      <div class="info-value">₦${cost.toStringAsFixed(2)}</div>
    </div>
  </div>

  <div class="results-section">
    <div class="section-title">TEST RESULTS</div>
    <div class="results-content">
      ${_generatePrintableResults(results)}
    </div>
  </div>

  ${notes.isNotEmpty ? '''
  <div class="notes-section">
    <div class="section-title" style="background: #ffa726;">CLINICAL NOTES</div>
    <div class="notes-content">
      <div class="plain-result">$notes</div>
    </div>
  </div>
  ''' : ''}

  <div class="footer">
    <p>Generated on ${DateFormat('MMMM dd, yyyy at HH:mm').format(DateTime.now())}</p>
    <p>LifeCare Connect Medical Records System</p>
  </div>

  <script>
    window.onload = function() {
      window.print();
    };
  </script>
</body>
</html>
''';

    // Open in a new window for printing
    _openPrintWindow(htmlContent);
  }

  String _generatePrintableResults(dynamic results) {
    // Handle different result types
    Map<String, dynamic>? parsedResults;

    if (results == null) {
      return '<div class="plain-result">No results available</div>';
    }

    if (results is Map<String, dynamic>) {
      parsedResults = results;
    } else if (results is String) {
      parsedResults = _parseResultsString(results);
    } else {
      return '<div class="plain-result">${results.toString().replaceAll('\n', '<br>')}</div>';
    }

    if (parsedResults != null && parsedResults.isNotEmpty) {
      final sortedKeys = parsedResults.keys.toList()..sort();

      String tableRows = '';
      for (var testName in sortedKeys) {
        final testData = parsedResults[testName];
        if (testData is Map) {
          final value = testData['value']?.toString() ?? '-';
          final unit = testData['unit']?.toString() ?? '';
          final reference = testData['reference']?.toString() ?? '-';
          final fullName = _getFullTestName(testName);

          // Determine if abnormal
          String rowClass = '';
          if (testData['value'] != null &&
              reference != '-' &&
              reference.contains('-')) {
            try {
              final ranges = reference.split('-');
              if (ranges.length == 2) {
                final min = double.tryParse(
                  ranges[0].trim().replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                final max = double.tryParse(
                  ranges[1].trim().replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                final val = double.tryParse(
                  value.replaceAll(RegExp(r'[^0-9.]'), ''),
                );

                if (min != null && max != null && val != null) {
                  rowClass = (val < min || val > max) ? 'abnormal' : 'normal';
                }
              }
            } catch (e) {
              // Ignore
            }
          }

          tableRows +=
              '''
          <tr class="$rowClass">
            <td><strong>$fullName</strong></td>
            <td style="text-align: center;"><strong>$value</strong></td>
            <td style="text-align: center;">$unit</td>
            <td style="text-align: center;">$reference</td>
          </tr>
          ''';
        }
      }

      return '''
      <table>
        <thead>
          <tr>
            <th>Test Parameter</th>
            <th style="text-align: center;">Result Value</th>
            <th style="text-align: center;">Unit of Measure</th>
            <th style="text-align: center;">Reference Range</th>
          </tr>
        </thead>
        <tbody>
          $tableRows
        </tbody>
      </table>
      ''';
    } else {
      // If not a proper map, try to display as string
      String resultsText = '';
      if (results is String) {
        resultsText = results;
      } else {
        resultsText = results.toString();
      }
      return '<div class="plain-result">${resultsText.replaceAll('\n', '<br>')}</div>';
    }
  }

  void _openPrintWindow(String htmlContent) {
    // Use platform-aware print utility
    printHtmlContent(htmlContent);
  }

  // Print prescription
  void _printPrescription(
    Map<String, dynamic> medication,
    String clinicianName,
    DateTime? createdAt,
    List prescriptions,
    String diagnosis,
    String notes,
  ) {
    final patientName = widget.isInpatient
        ? (widget.admissionData?['patientName'] ?? widget.patientName)
        : widget.patientName;

    final patientId = widget.patientId;

    String htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Prescription</title>
  <style>
    @media print {
      @page { margin: 1cm; }
      body { margin: 0; }
    }
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      padding: 20px;
      max-width: 800px;
      margin: 0 auto;
    }
    .header {
      text-align: center;
      border-bottom: 3px solid #2e7d32;
      padding-bottom: 15px;
      margin-bottom: 25px;
    }
    .header h1 {
      color: #2e7d32;
      margin: 0 0 5px 0;
      font-size: 28px;
    }
    .rx-symbol {
      font-size: 48px;
      color: #2e7d32;
      font-weight: bold;
      font-family: serif;
    }
    .info-section {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 15px;
      margin-bottom: 25px;
      padding: 15px;
      background: #f5f5f5;
      border-radius: 8px;
    }
    .info-item {
      margin-bottom: 8px;
    }
    .info-label {
      font-weight: 600;
      color: #555;
      font-size: 12px;
      text-transform: uppercase;
    }
    .info-value {
      font-size: 14px;
      color: #000;
      margin-top: 3px;
    }
    .diagnosis-section {
      margin: 20px 0;
      padding: 15px;
      background: #e3f2fd;
      border-left: 4px solid #1976d2;
      border-radius: 4px;
    }
    .diagnosis-label {
      font-weight: bold;
      color: #1565c0;
      margin-bottom: 8px;
      font-size: 14px;
    }
    .medications-section {
      margin: 25px 0;
    }
    .section-title {
      background: #2e7d32;
      color: white;
      padding: 12px 15px;
      border-radius: 6px 6px 0 0;
      font-weight: bold;
      font-size: 16px;
      letter-spacing: 1px;
    }
    .medications-content {
      border: 2px solid #2e7d32;
      border-top: none;
      border-radius: 0 0 6px 6px;
      padding: 20px;
    }
    .medication-item {
      margin-bottom: 20px;
      padding: 15px;
      background: #f9f9f9;
      border-left: 4px solid #2e7d32;
      border-radius: 4px;
    }
    .medication-number {
      display: inline-block;
      width: 30px;
      height: 30px;
      background: #2e7d32;
      color: white;
      border-radius: 50%;
      text-align: center;
      line-height: 30px;
      font-weight: bold;
      margin-right: 10px;
    }
    .medication-name {
      font-size: 16px;
      font-weight: bold;
      color: #1b5e20;
      margin-bottom: 8px;
    }
    .medication-details {
      margin-left: 40px;
      line-height: 1.8;
    }
    .medication-detail {
      margin-bottom: 4px;
      font-size: 14px;
    }
    .detail-label {
      font-weight: 600;
      color: #555;
      display: inline-block;
      min-width: 100px;
    }
    .notes-section {
      margin: 25px 0;
      padding: 15px;
      background: #fff8e1;
      border-left: 4px solid #ffa726;
      border-radius: 4px;
    }
    .notes-label {
      font-weight: bold;
      color: #f57c00;
      margin-bottom: 8px;
      font-size: 14px;
    }
    .signature-section {
      margin-top: 50px;
      padding-top: 20px;
      border-top: 1px solid #ddd;
    }
    .signature-line {
      margin-top: 40px;
      border-top: 2px solid #000;
      width: 250px;
      padding-top: 5px;
      font-size: 14px;
    }
    .footer {
      margin-top: 40px;
      padding-top: 15px;
      border-top: 2px solid #ddd;
      text-align: center;
      font-size: 12px;
      color: #666;
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="rx-symbol">℞</div>
    <h1>PRESCRIPTION</h1>
    <p>${createdAt != null ? DateFormat('MMMM dd, yyyy').format(createdAt) : 'N/A'}</p>
  </div>

  <div class="info-section">
    <div class="info-item">
      <div class="info-label">Patient Name</div>
      <div class="info-value">$patientName</div>
    </div>
    <div class="info-item">
      <div class="info-label">Patient ID</div>
      <div class="info-value">$patientId</div>
    </div>
    <div class="info-item">
      <div class="info-label">Prescribed By</div>
      <div class="info-value">Dr. $clinicianName</div>
    </div>
    <div class="info-item">
      <div class="info-label">Date</div>
      <div class="info-value">${createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt) : 'N/A'}</div>
    </div>
  </div>

  ${diagnosis.isNotEmpty ? '''
  <div class="diagnosis-section">
    <div class="diagnosis-label">DIAGNOSIS</div>
    <div>$diagnosis</div>
  </div>
  ''' : ''}

  <div class="medications-section">
    <div class="section-title">MEDICATIONS PRESCRIBED</div>
    <div class="medications-content">
      ${_generatePrintablePrescriptions(prescriptions)}
    </div>
  </div>

  ${notes.isNotEmpty ? '''
  <div class="notes-section">
    <div class="notes-label">PRESCRIPTION NOTES</div>
    <div>$notes</div>
  </div>
  ''' : ''}

  <div class="signature-section">
    <div class="signature-line">
      <strong>Dr. $clinicianName</strong><br>
      Prescribing Physician
    </div>
  </div>

  <div class="footer">
    <p>Generated on ${DateFormat('MMMM dd, yyyy at HH:mm').format(DateTime.now())}</p>
    <p>LifeCare Connect Medical Records System</p>
  </div>

  <script>
    window.onload = function() {
      window.print();
    };
  </script>
</body>
</html>
''';

    _openPrintWindow(htmlContent);
  }

  String _generatePrintablePrescriptions(List prescriptions) {
    String html = '';

    for (int i = 0; i < prescriptions.length; i++) {
      final prescription = prescriptions[i];
      final number = i + 1;

      if (prescription is Map) {
        final name =
            prescription['name'] ?? prescription['medication'] ?? 'Medication';
        final dosage = prescription['dosage'] ?? '';
        final frequency = prescription['frequency'] ?? '';
        final duration = prescription['duration'] ?? '';
        final instructions = prescription['instructions'] ?? '';

        html +=
            '''
        <div class="medication-item">
          <div class="medication-name">
            <span class="medication-number">$number</span>
            $name
          </div>
          <div class="medication-details">
            ${dosage.isNotEmpty ? '<div class="medication-detail"><span class="detail-label">Dosage:</span> $dosage</div>' : ''}
            ${frequency.isNotEmpty ? '<div class="medication-detail"><span class="detail-label">Frequency:</span> $frequency</div>' : ''}
            ${duration.isNotEmpty ? '<div class="medication-detail"><span class="detail-label">Duration:</span> $duration</div>' : ''}
            ${instructions.isNotEmpty ? '<div class="medication-detail"><span class="detail-label">Instructions:</span> $instructions</div>' : ''}
          </div>
        </div>
        ''';
      } else {
        html +=
            '''
        <div class="medication-item">
          <span class="medication-number">$number</span>
          <span>$prescription</span>
        </div>
        ''';
      }
    }

    return html.isNotEmpty ? html : '<p>No medications prescribed</p>';
  }

  Widget _buildMedicationCard(Map<String, dynamic> medication) {
    final createdAt = (medication['createdAt'] as Timestamp?)?.toDate();
    final clinicianName = medication['clinicianName'] ?? 'Unknown';
    final status = medication['status'] ?? 'pending';
    final prescriptions = medication['prescriptions'] as List? ?? [];
    final notes = medication['notes']?.toString() ?? '';
    final diagnosis = medication['diagnosis']?.toString() ?? '';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.green.shade50.withOpacity(0.3)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medication_liquid,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prescription',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy • HH:mm',
                                ).format(createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                  const SizedBox(width: 8),
                  // Print Button
                  IconButton(
                    onPressed: () => _printPrescription(
                      medication,
                      clinicianName,
                      createdAt,
                      prescriptions,
                      diagnosis,
                      notes,
                    ),
                    icon: const Icon(Icons.print, color: Colors.white),
                    tooltip: 'Print Prescription',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prescriber Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prescribed By',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                clinicianName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Diagnosis Section (if available)
                  if (diagnosis.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_hospital,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Diagnosis',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            diagnosis,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Medications Section
                  if (prescriptions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade100.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Medications Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.medication,
                                    color: Colors.green.shade700,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'MEDICATIONS PRESCRIBED',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Medications List
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: prescriptions.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final prescription = entry.value;
                                return _buildMedicationItem(
                                  index + 1,
                                  prescription,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Notes Section
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.shade100.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notes Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.sticky_note_2,
                                    color: Colors.amber.shade700,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'PRESCRIPTION NOTES',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Notes Content
                          Container(
                            padding: const EdgeInsets.all(20),
                            child: SelectableText(
                              notes,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.8,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationItem(int number, dynamic prescription) {
    String medicationText = prescription.toString();

    // Try to parse if it's a map with structured data
    if (prescription is Map) {
      final name = prescription['name'] ?? prescription['medication'] ?? '';
      final dosage = prescription['dosage'] ?? '';
      final frequency = prescription['frequency'] ?? '';
      final duration = prescription['duration'] ?? '';
      final instructions = prescription['instructions'] ?? '';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty) ...[
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (dosage.isNotEmpty)
                    _buildMedicationDetail(Icons.medication, 'Dosage', dosage),
                  if (frequency.isNotEmpty)
                    _buildMedicationDetail(
                      Icons.schedule,
                      'Frequency',
                      frequency,
                    ),
                  if (duration.isNotEmpty)
                    _buildMedicationDetail(
                      Icons.timelapse,
                      'Duration',
                      duration,
                    ),
                  if (instructions.isNotEmpty)
                    _buildMedicationDetail(
                      Icons.info_outline,
                      'Instructions',
                      instructions,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Fallback to simple text display
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              medicationText,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color textColor;
    String text;

    switch (status.toLowerCase()) {
      case 'completed':
      case 'dispensed':
        color = Colors.green;
        textColor = Colors.green.shade900;
        text = 'Completed';
        break;
      case 'pending':
        color = Colors.orange;
        textColor = Colors.orange.shade900;
        text = 'Pending';
        break;
      default:
        color = Colors.grey;
        textColor = Colors.grey.shade900;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSummarySection(String title, Widget content) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildVitalsSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vitals_records')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .orderBy('recordedAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No vital signs recorded',
            style: TextStyle(color: Colors.grey),
          );
        }

        final vital = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final recordedAt = (vital['recordedAt'] as Timestamp?)?.toDate();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest: ${recordedAt != null ? DateFormat('MMM dd, yyyy').format(recordedAt) : 'Unknown'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text('Total Records: ${snapshot.data!.docs.length}'),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildConsultationsSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('consultations')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No consultations recorded',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Text('Total Consultations: ${snapshot.data!.docs.length}');
      },
    );
  }

  // ignore: unused_element
  Widget _buildLabTestsSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_lab_tests')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No lab tests recorded',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Text('Total Lab Tests: ${snapshot.data!.docs.length}');
      },
    );
  }

  // ignore: unused_element
  Widget _buildMedicationsSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_prescriptions')
          .where('patientId', isEqualTo: widget.patientId)
          .where('facilityId', isEqualTo: widget.facilityId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No medications dispensed',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Text('Total Medications: ${snapshot.data!.docs.length}');
      },
    );
  }

  // Helper methods for inpatient overview tab
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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

  Future<Map<String, String>> _getWardAndBedInfo(
    String? wardId,
    String? bedId,
    String facilityId,
  ) async {
    try {
      String wardName = 'Unknown Ward';
      String bedNumber = 'Unknown Bed';

      if (wardId != null) {
        // Try main wards collection first (if exists)
        var wardDoc = await FirebaseFirestore.instance
            .collection('wards')
            .doc(wardId)
            .get();

        // If not found, try facility subcollection
        if (!wardDoc.exists) {
          wardDoc = await FirebaseFirestore.instance
              .collection('facilities')
              .doc(facilityId)
              .collection('wards')
              .doc(wardId)
              .get();
        }

        if (wardDoc.exists) {
          wardName =
              wardDoc.data()?['wardName'] ??
              wardDoc.data()?['name'] ??
              'Unknown Ward';
        }
      }

      if (bedId != null && wardId != null) {
        // Try main beds collection first (if exists)
        var bedDoc = await FirebaseFirestore.instance
            .collection('beds')
            .doc(bedId)
            .get();

        // If not found, try facility ward subcollection (correct location)
        if (!bedDoc.exists) {
          bedDoc = await FirebaseFirestore.instance
              .collection('facilities')
              .doc(facilityId)
              .collection('wards')
              .doc(wardId)
              .collection('beds')
              .doc(bedId)
              .get();
        }

        if (bedDoc.exists) {
          bedNumber =
              bedDoc.data()?['bedNumber'] ??
              bedDoc.data()?['number'] ??
              'Unknown Bed';
        }
      }

      return {'ward': wardName, 'bed': bedNumber};
    } catch (e) {
      print('❌ Error loading ward/bed info: $e');
      return {'ward': 'Error loading', 'bed': 'Error loading'};
    }
  }

  // Helper method for ward rounds card
  Widget _buildWardRoundCard(Map<String, dynamic> wardRound) {
    final roundDate = (wardRound['roundDate'] as Timestamp?)?.toDate();
    final doctorName = wardRound['doctorName'] ?? 'Unknown';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.indigo.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.indigo.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ward Round',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (roundDate != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(roundDate),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const Divider(height: 24),

            if (wardRound['complaints'] != null &&
                wardRound['complaints'].toString().isNotEmpty) ...[
              _buildInfoSection('Complaints', wardRound['complaints']),
              const SizedBox(height: 12),
            ],

            if (wardRound['findings'] != null &&
                wardRound['findings'].toString().isNotEmpty) ...[
              _buildInfoSection('Examination Findings', wardRound['findings']),
              const SizedBox(height: 12),
            ],

            if (wardRound['diagnosis'] != null &&
                wardRound['diagnosis'].toString().isNotEmpty) ...[
              _buildInfoSection('Diagnosis', wardRound['diagnosis']),
              const SizedBox(height: 12),
            ],

            if (wardRound['treatmentPlan'] != null &&
                wardRound['treatmentPlan'].toString().isNotEmpty) ...[
              _buildInfoSection('Treatment Plan', wardRound['treatmentPlan']),
              const SizedBox(height: 12),
            ],

            if (wardRound['notes'] != null &&
                wardRound['notes'].toString().isNotEmpty) ...[
              _buildInfoSection('Notes', wardRound['notes']),
              const SizedBox(height: 12),
            ],

            if (wardRound['prescriptions'] != null &&
                (wardRound['prescriptions'] as List).isNotEmpty) ...[
              Text(
                'Prescriptions:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...(wardRound['prescriptions'] as List).map(
                (prescription) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $prescription',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (wardRound['labTests'] != null &&
                (wardRound['labTests'] as List).isNotEmpty) ...[
              Text(
                'Lab Tests Ordered:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...(wardRound['labTests'] as List).map(
                (test) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $test', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (wardRound['imaging'] != null &&
                (wardRound['imaging'] as List).isNotEmpty) ...[
              Text(
                'Imaging Ordered:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...(wardRound['imaging'] as List).map(
                (img) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $img', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Doctor: $doctorName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for imaging card
  Widget _buildImagingCard(Map<String, dynamic> imaging) {
    final createdAt = (imaging['createdAt'] as Timestamp?)?.toDate();
    final clinicianName = imaging['clinicianName'] ?? 'Unknown';
    final status = imaging['status'] ?? 'pending';
    final cost = imaging['cost'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.cyan.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.cyan.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    imaging['imagingType'] ??
                        'Imaging Test', // Changed from testName to imagingType
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade900,
                    ),
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const Divider(height: 24),

            Text(
              'Cost: ₦${cost.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            if (imaging['results'] != null &&
                imaging['results'].toString().isNotEmpty) ...[
              _buildInfoSection('Results', imaging['results']),
              const SizedBox(height: 12),
            ],

            if (imaging['notes'] != null &&
                imaging['notes'].toString().isNotEmpty) ...[
              _buildInfoSection('Notes', imaging['notes']),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Ordered by: $clinicianName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
