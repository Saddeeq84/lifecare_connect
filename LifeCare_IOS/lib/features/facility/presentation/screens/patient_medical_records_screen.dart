import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/fluid_balance_chart.dart';

class PatientMedicalRecordsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientMedicalRecordsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientMedicalRecordsScreen> createState() =>
      _PatientMedicalRecordsScreenState();
}

class _PatientMedicalRecordsScreenState
    extends State<PatientMedicalRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
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
        title: Text(widget.patientName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.monitor_heart), text: 'Vitals'),
            Tab(icon: Icon(Icons.medical_information), text: 'Consultations'),
            Tab(icon: Icon(Icons.science), text: 'Lab Results'),
            Tab(icon: Icon(Icons.scanner), text: 'Imaging'),
            Tab(icon: Icon(Icons.medication), text: 'Medications'),
            Tab(icon: Icon(Icons.water_drop), text: 'Fluid Balance'),
            Tab(icon: Icon(Icons.description), text: 'Daily Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVitalsTab(),
          _buildConsultationsTab(),
          _buildLabResultsTab(),
          _buildImagingTab(),
          _buildMedicationsTab(),
          FluidBalanceChart(
            patientId: widget.patientId,
            patientName: widget.patientName,
          ),
          _buildDailyReportsTab(),
        ],
      ),
    );
  }

  Widget _buildVitalsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('vitals')
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No vitals recorded',
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
            final timestamp = data['recordedAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  timestamp != null
                      ? DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(timestamp.toDate())
                      : 'Date not available',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Recorded by: ${data['recordedBy'] ?? 'Unknown'}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVitalRow(
                          'BP',
                          data['bloodPressure'] != null
                              ? '${data['bloodPressure']['systolic']}/${data['bloodPressure']['diastolic']} mmHg'
                              : '-',
                        ),
                        _buildVitalRow(
                          'Temperature',
                          data['temperature'] != null
                              ? '${data['temperature']}°C'
                              : '-',
                        ),
                        _buildVitalRow(
                          'Pulse',
                          data['pulse'] != null ? '${data['pulse']} bpm' : '-',
                        ),
                        _buildVitalRow(
                          'Respiratory Rate',
                          data['respiratoryRate'] != null
                              ? '${data['respiratoryRate']}/min'
                              : '-',
                        ),
                        _buildVitalRow(
                          'Weight',
                          data['weight'] != null ? '${data['weight']} kg' : '-',
                        ),
                        _buildVitalRow(
                          'Height',
                          data['height'] != null ? '${data['height']} cm' : '-',
                        ),
                        if (data['bmi'] != null)
                          _buildVitalRow(
                            'BMI',
                            '${data['bmi'].toStringAsFixed(1)} (${data['bmiCategory']})',
                          ),
                        if (data['spo2'] != null)
                          _buildVitalRow('SpO2', '${data['spo2']}%'),
                        if (data['bloodGlucose'] != null)
                          _buildVitalRow(
                            'Blood Glucose',
                            '${data['bloodGlucose']} mmol/L',
                          ),
                        if (data['notes'] != null &&
                            data['notes'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Notes: ${data['notes']}',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConsultationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('consultations')
          .orderBy('consultedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'No consultations recorded',
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
            final timestamp = data['consultedAt'] as Timestamp?;
            final prescriptions = data['prescriptions'] as List<dynamic>? ?? [];
            final labTests = data['labTests'] as List<dynamic>? ?? [];
            final imaging = data['imagingRequests'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  timestamp != null
                      ? DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(timestamp.toDate())
                      : 'Date not available',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Clinician: ${data['clinicianName'] ?? 'Unknown'}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConsultationSection(
                          'Complaints',
                          data['complaints'],
                        ),
                        _buildConsultationSection('History', data['history']),
                        _buildConsultationSection(
                          'Examination',
                          data['examination'],
                        ),
                        _buildConsultationSection(
                          'Diagnosis',
                          data['diagnosis'],
                        ),

                        if (prescriptions.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Prescriptions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...prescriptions.map(
                            (rx) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${rx['medication']} ${rx['strength']} - ${rx['dosage']} for ${rx['duration']}',
                              ),
                            ),
                          ),
                        ],

                        if (labTests.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Lab Tests:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...labTests.map(
                            (test) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $test'),
                            ),
                          ),
                        ],

                        if (imaging.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Imaging:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...imaging.map(
                            (img) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $img'),
                            ),
                          ),
                        ],

                        _buildConsultationSection(
                          'Treatment Plan',
                          data['treatmentPlan'],
                        ),
                        _buildConsultationSection(
                          'Follow-up',
                          data['followUp'],
                        ),

                        const Divider(height: 16),
                        Text(
                          'Fee: ₦${(data['consultationFee'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLabResultsTab() {
    // Query from multiple sources to get all lab results
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('lab_results')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, labResultsSnapshot) {
        // Also query from health_records and pending_lab_tests
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: widget.patientId)
              .where('recordType', isEqualTo: 'laboratory')
              .orderBy('completedAt', descending: true)
              .snapshots(),
          builder: (context, healthRecordsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pending_lab_tests')
                  .where('patientId', isEqualTo: widget.patientId)
                  .where('status', isEqualTo: 'completed')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, pendingLabsSnapshot) {
                if (labResultsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    healthRecordsSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    pendingLabsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (labResultsSnapshot.hasError ||
                    healthRecordsSnapshot.hasError ||
                    pendingLabsSnapshot.hasError) {
                  return Center(child: Text('Error loading lab results'));
                }

                // Combine all results from three sources
                final List<Map<String, dynamic>> allResults = [];

                // Add from subcollection
                if (labResultsSnapshot.hasData) {
                  allResults.addAll(
                    labResultsSnapshot.data!.docs
                        .map(
                          (doc) => {
                            ...doc.data() as Map<String, dynamic>,
                            'docId': doc.id,
                            'source': 'lab_results',
                          },
                        )
                        .toList(),
                  );
                }

                // Add from health_records
                if (healthRecordsSnapshot.hasData) {
                  allResults.addAll(
                    healthRecordsSnapshot.data!.docs
                        .map(
                          (doc) => {
                            ...doc.data() as Map<String, dynamic>,
                            'docId': doc.id,
                            'source': 'health_records',
                          },
                        )
                        .toList(),
                  );
                }

                // Add from pending_lab_tests
                if (pendingLabsSnapshot.hasData) {
                  allResults.addAll(
                    pendingLabsSnapshot.data!.docs
                        .map(
                          (doc) => {
                            ...doc.data() as Map<String, dynamic>,
                            'docId': doc.id,
                            'source': 'pending_lab_tests',
                          },
                        )
                        .toList(),
                  );
                }

                // Sort by completedAt or createdAt
                allResults.sort((a, b) {
                  final aTime =
                      (a['completedAt'] ?? a['createdAt']) as Timestamp?;
                  final bTime =
                      (b['completedAt'] ?? b['createdAt']) as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                if (allResults.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No lab results available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allResults.length,
                  itemBuilder: (context, index) {
                    final data = allResults[index];
                    final timestamp =
                        (data['completedAt'] ?? data['createdAt'])
                            as Timestamp?;

                    // Handle results as either Map or String
                    final dynamic resultsData = data['results'];
                    final bool hasResults =
                        resultsData != null &&
                        ((resultsData is Map && resultsData.isNotEmpty) ||
                            (resultsData is String && resultsData.isNotEmpty));

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(
                                Icons.biotech,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            title: Text(
                              data['testName'] ?? 'Unknown Test',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (timestamp != null)
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy - hh:mm a',
                                    ).format(timestamp.toDate()),
                                  ),
                                Text(
                                  'Performed by: ${data['performedBy'] ?? 'Unknown'}',
                                ),
                                Text(
                                  'Cost: ₦${(data['cost'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // View Results Button - Show for all completed tests
                                if (hasResults)
                                  ElevatedButton.icon(
                                    onPressed: () => _showLabResultsDialog(
                                      data,
                                      data['docId'] ?? '',
                                    ),
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 16,
                                    ),
                                    label: const Text('View Results'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                // Print Button - Show for all tests
                                IconButton(
                                  onPressed: () => _printLabResults(data),
                                  icon: const Icon(Icons.print),
                                  tooltip: 'Print Results',
                                  color: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildImagingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('imaging_results')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.scanner_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No imaging results available',
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
            final timestamp = data['completedAt'] as Timestamp?;
            final report = data['report'] as Map<String, dynamic>? ?? {};

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  data['imagingType'] ?? 'Unknown Imaging',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timestamp != null)
                      Text(
                        DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(timestamp.toDate()),
                      ),
                    Text('Reported by: ${report['reportedBy'] ?? 'Unknown'}'),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildReportSection(
                          'CLINICAL INFORMATION',
                          report['clinicalInformation'],
                        ),
                        _buildReportSection('TECHNIQUE', report['technique']),
                        _buildReportSection('FINDINGS', report['findings']),
                        _buildReportSection('IMPRESSION', report['impression']),
                        const Divider(height: 16),
                        Text(
                          'Cost: ₦${(data['cost'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMedicationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_prescriptions')
          .where('patientId', isEqualTo: widget.patientId)
          .where('status', isEqualTo: 'dispensed')
          .orderBy('dispensedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No dispensed medications',
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
            final timestamp = data['dispensedAt'] as Timestamp?;
            final medications = data['dispensedItems'] as List<dynamic>? ?? [];

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                title: Text(
                  timestamp != null
                      ? DateFormat(
                          'MMM dd, yyyy - hh:mm a',
                        ).format(timestamp.toDate())
                      : 'Date not available',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Dispensed by: ${data['dispensedBy'] ?? 'Unknown'}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Medications:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...medications.map(
                          (med) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ${med['medication']} ${med['strength']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text('  Dose: ${med['dosage']}'),
                                Text('  Duration: ${med['duration']}'),
                                if (med['instructions'] != null &&
                                    med['instructions'].toString().isNotEmpty)
                                  Text(
                                    '  Instructions: ${med['instructions']}',
                                  ),
                                Text(
                                  '  Price: ₦${(med['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 16),
                        Text(
                          'Total: ₦${(data['totalCost'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVitalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildConsultationSection(String title, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value.toString()),
        ],
      ),
    );
  }

  Widget _buildReportSection(String title, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(value.toString()),
        ],
      ),
    );
  }

  void _showLabResultsDialog(Map<String, dynamic> data, String docId) {
    final results = data['results'] as Map<String, dynamic>? ?? {};
    final testName = data['testName'] ?? 'Unknown Test';
    final performedBy = data['performedBy'] ?? 'Unknown';
    final timestamp = data['completedAt'] as Timestamp?;
    final comments = data['comments']?.toString() ?? '';
    final cost = (data['cost'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
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
                    const Icon(Icons.biotech, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Laboratory Test Results',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            testName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
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
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Performed By:',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        performedBy,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (timestamp != null)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Date:',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(timestamp.toDate()),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Results
                      if (results.isNotEmpty) ...[
                        const Text(
                          'Test Results',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...results.entries.map((entry) {
                          if (entry.value is Map) {
                            final param = entry.value as Map<String, dynamic>;
                            final value = param['value']?.toString() ?? '';
                            final unit = param['unit']?.toString() ?? '';
                            final reference =
                                param['reference']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Value:',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              '$value $unit',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (reference.isNotEmpty)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Reference:',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                reference,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    entry.value.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }),
                      ],

                      // Comments
                      if (comments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(comments),
                        ),
                      ],

                      // Cost
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Test Cost:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₦${cost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printLabResults(data),
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
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

  void _printLabResults(Map<String, dynamic> data) {
    // TODO: Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Print functionality coming soon')),
    );
  }

  Widget _buildDailyReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient_daily_reports')
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('reportDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No daily reports available',
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
            final reportDate = (data['reportDate'] as Timestamp?)?.toDate();
            final shift = data['shift'] ?? 'N/A';
            final reportedBy = data['reportedBy'] ?? 'Unknown';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepOrange.shade100,
                  child: const Icon(
                    Icons.description,
                    color: Colors.deepOrange,
                  ),
                ),
                title: Text(
                  reportDate != null
                      ? DateFormat('MMM dd, yyyy').format(reportDate)
                      : 'Unknown Date',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$shift • by $reportedBy'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['chiefComplaints'] != null &&
                            (data['chiefComplaints'] as String).isNotEmpty) ...[
                          _buildReportSection(
                            'Chief Complaints',
                            data['chiefComplaints'],
                          ),
                          const Divider(height: 24),
                        ],
                        if (data['vitalSigns'] != null &&
                            (data['vitalSigns'] as String).isNotEmpty) ...[
                          _buildReportSection(
                            'Vital Signs',
                            data['vitalSigns'],
                          ),
                          const Divider(height: 24),
                        ],
                        if (data['consciousnessLevel'] != null) ...[
                          _buildReportField(
                            'Consciousness',
                            data['consciousnessLevel'],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (data['respiratoryStatus'] != null) ...[
                          _buildReportField(
                            'Respiratory Status',
                            data['respiratoryStatus'],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (data['cardiovascularStatus'] != null) ...[
                          _buildReportField(
                            'Cardiovascular Status',
                            data['cardiovascularStatus'],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (data['mobilityStatus'] != null) ...[
                          _buildReportField('Mobility', data['mobilityStatus']),
                          const SizedBox(height: 8),
                        ],
                        if (data['skinIntegrity'] != null) ...[
                          _buildReportField(
                            'Skin Integrity',
                            data['skinIntegrity'],
                          ),
                          const Divider(height: 24),
                        ],
                        if (data['nursingAssessment'] != null &&
                            (data['nursingAssessment'] as String)
                                .isNotEmpty) ...[
                          _buildReportSection(
                            'Nursing Assessment',
                            data['nursingAssessment'],
                          ),
                          const Divider(height: 24),
                        ],
                        if (data['interventions'] != null &&
                            (data['interventions'] as String).isNotEmpty) ...[
                          _buildReportSection(
                            'Interventions',
                            data['interventions'],
                          ),
                          const Divider(height: 24),
                        ],
                        if (data['evaluation'] != null &&
                            (data['evaluation'] as String).isNotEmpty) ...[
                          _buildReportSection('Evaluation', data['evaluation']),
                          const Divider(height: 24),
                        ],
                        if (data['plan'] != null &&
                            (data['plan'] as String).isNotEmpty) ...[
                          _buildReportSection(
                            'Plan for Next 24 Hours',
                            data['plan'],
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
    );
  }

  Widget _buildReportField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
