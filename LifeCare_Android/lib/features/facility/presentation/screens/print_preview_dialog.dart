import 'package:flutter/material.dart';
import '../../../../utils/web_utils.dart';

/// Print Preview Dialog for Various Documents
/// Supports printing consultations, lab results, radiology reports, prescriptions, etc.
class PrintPreviewDialog {
  static void showPrintDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    String? patientName,
    String? facilityName,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.teal.shade800,
                child: Row(
                  children: [
                    const Icon(Icons.print, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Preview Content
              Expanded(
                child: Container(
                  color: Colors.grey.shade200,
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Facility Header
                          if (facilityName != null) ...[
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    facilityName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  const Divider(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Patient Info
                          if (patientName != null) ...[
                            Row(
                              children: [
                                const Text(
                                  'Patient: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(patientName),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Main Content
                          content,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _printDocument(context);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
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

  static void _printDocument(BuildContext context) {
    try {
      printCurrentWindow();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print dialog opened'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Print Consultation Note
  static void printConsultation({
    required BuildContext context,
    required Map<String, dynamic> consultationData,
    required String patientName,
    String? facilityName,
  }) {
    final prescriptions =
        consultationData['prescriptions'] as List<dynamic>? ?? [];
    final labTests = consultationData['labTests'] as List<dynamic>? ?? [];
    final imaging = consultationData['imagingRequests'] as List<dynamic>? ?? [];

    showPrintDialog(
      context: context,
      title: 'Consultation Note',
      patientName: patientName,
      facilityName: facilityName,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Complaints', consultationData['complaints']),
          _buildSection('History', consultationData['history']),
          _buildSection('Examination', consultationData['examination']),
          _buildSection('Diagnosis', consultationData['diagnosis']),

          if (prescriptions.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Prescriptions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...prescriptions.map(
              (rx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ${rx['medication']} ${rx['strength']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text('  Dose: ${rx['dosage']}'),
                    Text('  Duration: ${rx['duration']}'),
                    if (rx['instructions'] != null)
                      Text('  Instructions: ${rx['instructions']}'),
                  ],
                ),
              ),
            ),
          ],

          if (labTests.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Laboratory Tests:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...labTests.map((test) => Text('• $test')),
          ],

          if (imaging.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Imaging Studies:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...imaging.map((img) => Text('• $img')),
          ],

          _buildSection('Treatment Plan', consultationData['treatmentPlan']),
          _buildSection('Follow-up', consultationData['followUp']),

          const Divider(height: 24),
          Text('Clinician: ${consultationData['clinicianName']}'),
        ],
      ),
    );
  }

  /// Print Lab Results
  static void printLabResults({
    required BuildContext context,
    required Map<String, dynamic> labData,
    required String patientName,
    String? facilityName,
  }) {
    final results = labData['results'] as Map<String, dynamic>? ?? {};

    showPrintDialog(
      context: context,
      title: 'Laboratory Results',
      patientName: patientName,
      facilityName: facilityName,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test: ${labData['testName']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (results.isNotEmpty) ...[
            const Text(
              'Results:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Parameter',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Value',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Reference',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...results.entries.map((entry) {
                  if (entry.value is Map) {
                    final param = entry.value as Map<String, dynamic>;
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(entry.key),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '${param['value']} ${param['unit'] ?? ''}',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(param['reference'] ?? ''),
                        ),
                      ],
                    );
                  } else {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(entry.key),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(entry.value.toString()),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(''),
                        ),
                      ],
                    );
                  }
                }),
              ],
            ),
          ],

          if (labData['comments'] != null &&
              labData['comments'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Comments:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(labData['comments']),
          ],

          const Divider(height: 24),
          Text('Performed by: ${labData['performedBy']}'),
        ],
      ),
    );
  }

  /// Print Radiology Report
  static void printRadiologyReport({
    required BuildContext context,
    required Map<String, dynamic> imagingData,
    required String patientName,
    String? facilityName,
  }) {
    final report = imagingData['report'] as Map<String, dynamic>? ?? {};

    showPrintDialog(
      context: context,
      title: 'Radiology Report',
      patientName: patientName,
      facilityName: facilityName,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Imaging Type: ${imagingData['imagingType']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildReportSection(
            'CLINICAL INFORMATION',
            report['clinicalInformation'],
          ),
          _buildReportSection('TECHNIQUE', report['technique']),
          _buildReportSection('FINDINGS', report['findings']),
          _buildReportSection('IMPRESSION', report['impression']),

          const Divider(height: 24),
          Text('Reported by: ${report['reportedBy']}'),
        ],
      ),
    );
  }

  static Widget _buildSection(String title, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(value.toString()),
        ],
      ),
    );
  }

  static Widget _buildReportSection(String title, dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 4),
          Text(value.toString()),
        ],
      ),
    );
  }
}
