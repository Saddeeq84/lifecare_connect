// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PatientConsultationsScreen extends StatelessWidget {
  const PatientConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Consultations'),
        backgroundColor: Colors.green.shade700,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading consultations'));
          }
          final consultations = snapshot.data?.docs ?? [];
          if (consultations.isEmpty) {
            return const Center(child: Text('No completed consultations yet.'));
          }
          return ListView.builder(
            itemCount: consultations.length,
            itemBuilder: (context, index) {
              final doc = consultations[index];
              final data = doc.data() as Map<String, dynamic>;
              // Include document ID in the data for appointment linking
              final dataWithId = {
                ...data,
                'id': doc.id,
                'appointmentId': doc.id,
              };
              final date = data['completedAt'] != null
                  ? (data['completedAt'] as Timestamp).toDate()
                  : null;
              final dateStr = date != null
                  ? DateFormat('MMM dd, yyyy • hh:mm a').format(date)
                  : 'Date not set';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['appointmentType'] ?? 'Consultation',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Provider: ${data['providerName'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        'Completed: $dateStr',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => showDialog(
                              context: context,
                              builder: (context) =>
                                  _ConsultationDetailsDialog(data: dataWithId),
                            ),
                            icon: const Icon(Icons.visibility, size: 18),
                            label: const Text('View Details'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _generatePrescriptionPDF(context, dataWithId),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Print'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
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

  Future<void> _generatePrescriptionPDF(
    BuildContext context,
    Map<String, dynamic> appointmentData,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get patient information (same logic as View Details)
      final patientId = appointmentData['patientId'];
      final providerId = appointmentData['providerId'];
      final providerType = appointmentData['providerType']
          ?.toString()
          .toUpperCase();
      final completedAt = appointmentData['completedAt'] as Timestamp?;

      Map<String, dynamic>? healthRecordData;

      if (patientId != null) {
        // Query health_records by patientId (same as View Details dialog)
        List<QueryDocumentSnapshot> healthRecordDocs = [];

        if (providerType == 'CHW' ||
            providerType == 'COMMUNITY HEALTH WORKER') {
          try {
            final result = await FirebaseFirestore.instance
                .collection('health_records')
                .where('patientId', isEqualTo: patientId)
                .where('providerType', isEqualTo: 'CHW')
                .orderBy('timestamp', descending: true)
                .get();
            healthRecordDocs = result.docs;
          } catch (e) {
            // Fallback: Query without orderBy
            final result = await FirebaseFirestore.instance
                .collection('health_records')
                .where('patientId', isEqualTo: patientId)
                .where('providerType', isEqualTo: 'CHW')
                .get();
            healthRecordDocs = result.docs.toList();
            healthRecordDocs.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
          }
        } else {
          try {
            final result = await FirebaseFirestore.instance
                .collection('health_records')
                .where('patientId', isEqualTo: patientId)
                .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
                .orderBy('timestamp', descending: true)
                .get();
            healthRecordDocs = result.docs;
          } catch (e) {
            // Fallback: Query without orderBy
            final result = await FirebaseFirestore.instance
                .collection('health_records')
                .where('patientId', isEqualTo: patientId)
                .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
                .get();
            healthRecordDocs = result.docs.toList();
            healthRecordDocs.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
          }
        }

        // Find matching record (same logic as View Details)
        if (healthRecordDocs.isNotEmpty) {
          QueryDocumentSnapshot? matchedRecord;

          if (providerId != null && completedAt != null) {
            final completedDate = completedAt.toDate();

            for (var doc in healthRecordDocs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) continue;

              final recordProviderId =
                  data['providerId'] ?? data['chwId'] ?? data['chwUid'];
              final recordTimestamp = data['timestamp'] as Timestamp?;

              if (recordProviderId == providerId && recordTimestamp != null) {
                final recordDate = recordTimestamp.toDate();
                final diff = completedDate.difference(recordDate).abs();

                if (diff.inHours < 2) {
                  matchedRecord = doc;
                  break;
                }
              }
            }
          }

          matchedRecord ??= healthRecordDocs.first;
          healthRecordData = matchedRecord.data() as Map<String, dynamic>;
        }
      }

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      if (healthRecordData == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No consultation details available for this appointment',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Generate PDF
      final pdf = pw.Document();

      // Load logo image
      final logoImage = await rootBundle.load('assets/images/logo.png');
      final logoImageBytes = logoImage.buffer.asUint8List();

      // Get patient info - Use healthRecordData for provider info (actual doctor who wrote prescription)
      final patientName = appointmentData['patientName'] ?? 'Patient';
      // FIX: Use providerName from health_records (actual doctor) not from appointment
      final providerName =
          healthRecordData['providerName'] ??
          appointmentData['providerName'] ??
          'Provider';
      final providerTypeStr =
          healthRecordData['providerType']?.toString() ??
          appointmentData['providerType']?.toString() ??
          '';
      final completedAtDate = appointmentData['completedAt'] != null
          ? (appointmentData['completedAt'] as Timestamp).toDate()
          : DateTime.now();
      final dateStr = DateFormat(
        'MMMM dd, yyyy • hh:mm a',
      ).format(completedAtDate);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Company Header with Logo
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LifeCare Connect',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Connecting you to quality healthcare services',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  width: 80,
                  height: 80,
                  child: pw.Image(
                    pw.MemoryImage(logoImageBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.teal, thickness: 2),
            pw.SizedBox(height: 15),

            // Document Title
            pw.Center(
              child: pw.Text(
                'MEDICAL PRESCRIPTION & REQUESTS',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Patient Information
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Patient Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildPdfRow('Patient Name:', patientName),
                  _buildPdfRow('Date:', dateStr),
                  _buildPdfRow('Healthcare Provider:', providerName),
                  if (providerTypeStr.isNotEmpty)
                    _buildPdfRow('Provider Type:', providerTypeStr),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Diagnosis (check both top-level and nested data)
            if ((healthRecordData?['diagnosis'] != null &&
                    healthRecordData!['diagnosis'].toString().isNotEmpty) ||
                (healthRecordData?['data'] != null &&
                    healthRecordData!['data']['diagnosis'] != null &&
                    healthRecordData['data']['diagnosis']
                        .toString()
                        .isNotEmpty)) ...[
              _buildPdfSection('DIAGNOSIS', Icons.healing.codePoint),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Text(
                  (healthRecordData['diagnosis'] ??
                          healthRecordData['data']?['diagnosis'] ??
                          '')
                      .toString(),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Prescriptions/Medications
            // Check both doctor format (top-level) and CHW format (nested in data)
            if (healthRecordData?['prescriptions'] != null ||
                (healthRecordData?['data'] != null &&
                    healthRecordData!['data']['prescriptions'] != null &&
                    healthRecordData['data']['prescriptions']
                        .toString()
                        .isNotEmpty)) ...[
              _buildPdfSection(
                'MEDICATIONS PRESCRIBED',
                Icons.medication.codePoint,
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  color: PdfColors.blue50,
                ),
                child: _buildPdfList(
                  healthRecordData!['prescriptions'] ??
                      healthRecordData['data']['prescriptions'],
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Lab Investigations
            // Doctor: labRequests, CHW: data.labTests
            if (healthRecordData?['labRequests'] != null ||
                (healthRecordData?['data'] != null &&
                    healthRecordData!['data']['labTests'] != null &&
                    healthRecordData['data']['labTests']
                        .toString()
                        .isNotEmpty)) ...[
              _buildPdfSection(
                'LABORATORY INVESTIGATIONS',
                Icons.science.codePoint,
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.orange300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  color: PdfColors.orange50,
                ),
                child: _buildPdfList(
                  healthRecordData!['labRequests'] ??
                      healthRecordData['data']['labTests'],
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Radiology Requests
            // Doctor: radiologyRequests, CHW: data.radiology
            if (healthRecordData?['radiologyRequests'] != null ||
                (healthRecordData?['data'] != null &&
                    healthRecordData!['data']['radiology'] != null &&
                    healthRecordData['data']['radiology']
                        .toString()
                        .isNotEmpty)) ...[
              _buildPdfSection(
                'RADIOLOGY REQUESTS',
                Icons.medical_services.codePoint,
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.purple300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  color: PdfColors.purple50,
                ),
                child: _buildPdfList(
                  healthRecordData!['radiologyRequests'] ??
                      healthRecordData['data']['radiology'],
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            // Follow-up Instructions (if available)
            if (healthRecordData?['followUp'] != null &&
                healthRecordData!['followUp'].toString().isNotEmpty) ...[
              _buildPdfSection(
                'FOLLOW-UP INSTRUCTIONS',
                Icons.calendar_today.codePoint,
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  color: PdfColors.green50,
                ),
                child: pw.Text(
                  healthRecordData['followUp'].toString(),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.SizedBox(height: 15),
            ],

            pw.SizedBox(height: 30),

            // Footer
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 10),
            pw.Text(
              'This is a computer-generated prescription. Please present this at the pharmacy or laboratory.',
              style: pw.TextStyle(
                fontSize: 10,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Generated on: ${DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 15),
            pw.Divider(color: PdfColors.teal, thickness: 1),
            pw.SizedBox(height: 10),
            // Company Contact Information
            pw.Column(
              children: [
                pw.Text(
                  'LifeCare Connect',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('🌐 ', style: pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      'www.lifecare.rhemn.org.ng',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text('📧 ', style: pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      'info@lifecare.rhemn.org.ng',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.blue800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Save and print PDF
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name:
            'Prescription_${patientName.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(completedAtDate)}.pdf',
      );
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfSection(String title, int iconCode) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 20,
              height: 20,
              margin: const pw.EdgeInsets.only(right: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
            ),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfList(dynamic items) {
    List<String> itemList = [];

    if (items is List) {
      // Doctor consultations: array format
      itemList = items.map((e) => e.toString()).toList();
    } else if (items is String) {
      // CHW consultations: comma-separated string format
      // Split by comma and trim whitespace
      itemList = items
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (itemList.isEmpty) {
      return pw.Text('None', style: const pw.TextStyle(fontSize: 12));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: itemList.map((item) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '• ',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Expanded(
                child: pw.Text(item, style: const pw.TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ConsultationDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  const _ConsultationDetailsDialog({required this.data});

  @override
  State<_ConsultationDetailsDialog> createState() =>
      _ConsultationDetailsDialogState();
}

class _ConsultationDetailsDialogState
    extends State<_ConsultationDetailsDialog> {
  Map<String, dynamic>? healthRecordData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConsultationDetails();
  }

  Future<void> _loadConsultationDetails() async {
    try {
      // Get patient information
      final patientId = widget.data['patientId'];
      final providerId = widget.data['providerId'];
      final providerType = widget.data['providerType']
          ?.toString()
          .toUpperCase();
      final completedAt = widget.data['completedAt'] as Timestamp?;

      if (patientId == null) {
        setState(() => isLoading = false);
        return;
      }

      // Query health_records by patientId and providerType
      // CHW consultations don't have a 'type' field, they use 'providerType'
      // Doctor consultations have type='DOCTOR_CONSULTATION'
      List<QueryDocumentSnapshot> healthRecordDocs = [];

      if (providerType == 'CHW' || providerType == 'COMMUNITY HEALTH WORKER') {
        try {
          // Try with orderBy first
          final result = await FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: patientId)
              .where('providerType', isEqualTo: 'CHW')
              .orderBy('timestamp', descending: true)
              .get();
          healthRecordDocs = result.docs;
        } catch (e) {
          // Fallback: Query without orderBy if index is building
          final result = await FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: patientId)
              .where('providerType', isEqualTo: 'CHW')
              .get();
          healthRecordDocs = result.docs.toList();
          // Sort in memory
          healthRecordDocs.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
        }
      } else {
        try {
          // Try with orderBy first
          final result = await FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: patientId)
              .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
              .orderBy('timestamp', descending: true)
              .get();
          healthRecordDocs = result.docs;
        } catch (e) {
          // Fallback: Query without orderBy if index is building
          final result = await FirebaseFirestore.instance
              .collection('health_records')
              .where('patientId', isEqualTo: patientId)
              .where('type', isEqualTo: 'DOCTOR_CONSULTATION')
              .get();
          healthRecordDocs = result.docs.toList();
          // Sort in memory
          healthRecordDocs.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
        }
      }

      if (healthRecordDocs.isNotEmpty) {
        // Find the record that matches this specific consultation
        // First try to match by providerId and time proximity
        QueryDocumentSnapshot? matchedRecord;

        if (providerId != null && completedAt != null) {
          final completedDate = completedAt.toDate();

          for (var doc in healthRecordDocs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            // For CHW, check chwId or chwUid; for Doctor, check providerId
            final recordProviderId =
                data['providerId'] ?? data['chwId'] ?? data['chwUid'];
            final recordTimestamp = data['timestamp'] as Timestamp?;

            if (recordProviderId == providerId && recordTimestamp != null) {
              final recordDate = recordTimestamp.toDate();
              final diff = completedDate.difference(recordDate).abs();

              // If within 2 hours, consider it a match
              if (diff.inHours < 2) {
                matchedRecord = doc;
                break;
              }
            }
          }
        }

        // If no match found, use the most recent record
        matchedRecord ??= healthRecordDocs.first;

        final recordData = matchedRecord.data() as Map<String, dynamic>;

        setState(() {
          healthRecordData = recordData;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedAt = widget.data['completedAt'] != null
        ? (widget.data['completedAt'] as Timestamp).toDate()
        : null;

    return AlertDialog(
      title: Text(widget.data['appointmentType'] ?? 'Consultation Details'),
      content: isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow(
                    'Provider',
                    '${widget.data['providerName']} (${widget.data['providerType']})',
                  ),
                  _buildDetailRow(
                    'Completed',
                    completedAt != null
                        ? DateFormat(
                            'MMM dd, yyyy • hh:mm a',
                          ).format(completedAt)
                        : 'Date not available',
                  ),
                  _buildDetailRow('Status', widget.data['status'] ?? 'Unknown'),

                  // Show consultation data if available
                  if (healthRecordData != null) ...[
                    const Divider(height: 24),
                    const Text(
                      'Consultation Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Diagnosis (check both top-level and nested data)
                    if ((healthRecordData!['diagnosis'] != null &&
                            healthRecordData!['diagnosis']
                                .toString()
                                .isNotEmpty) ||
                        (healthRecordData!['data'] != null &&
                            healthRecordData!['data']['diagnosis'] != null &&
                            healthRecordData!['data']['diagnosis']
                                .toString()
                                .isNotEmpty)) ...[
                      _buildSectionHeader('Diagnosis', Icons.healing),
                      _buildContentBox(
                        (healthRecordData!['diagnosis'] ??
                                healthRecordData!['data']?['diagnosis'] ??
                                '')
                            .toString(),
                      ),
                    ],

                    // Prescriptions/Medications (PRIORITIZED - Show first after diagnosis)
                    // For Doctor consultations: healthRecordData['prescriptions']
                    // For CHW consultations: healthRecordData['data']['prescriptions']
                    if (healthRecordData!['prescriptions'] != null ||
                        (healthRecordData!['data'] != null &&
                            healthRecordData!['data']['prescriptions'] !=
                                null &&
                            healthRecordData!['data']['prescriptions']
                                .toString()
                                .isNotEmpty)) ...[
                      _buildSectionHeader(
                        'Medications Prescribed',
                        Icons.medication,
                      ),
                      _buildListBox(
                        healthRecordData!['prescriptions'] ??
                            healthRecordData!['data']['prescriptions'],
                      ),
                    ],

                    // Lab Investigations
                    // For Doctor consultations: healthRecordData['labRequests']
                    // For CHW consultations: healthRecordData['data']['labTests']
                    if (healthRecordData!['labRequests'] != null ||
                        (healthRecordData!['data'] != null &&
                            healthRecordData!['data']['labTests'] != null &&
                            healthRecordData!['data']['labTests']
                                .toString()
                                .isNotEmpty)) ...[
                      _buildSectionHeader(
                        'Laboratory Investigations',
                        Icons.science,
                      ),
                      _buildListBox(
                        healthRecordData!['labRequests'] ??
                            healthRecordData!['data']['labTests'],
                      ),
                    ],

                    // Radiology Requests
                    // For Doctor consultations: healthRecordData['radiologyRequests']
                    // For CHW consultations: healthRecordData['data']['radiology']
                    if (healthRecordData!['radiologyRequests'] != null ||
                        (healthRecordData!['data'] != null &&
                            healthRecordData!['data']['radiology'] != null &&
                            healthRecordData!['data']['radiology']
                                .toString()
                                .isNotEmpty)) ...[
                      _buildSectionHeader(
                        'Radiology Requests',
                        Icons.medical_services,
                      ),
                      _buildListBox(
                        healthRecordData!['radiologyRequests'] ??
                            healthRecordData!['data']['radiology'],
                      ),
                    ],

                    // Clinical Notes
                    if (healthRecordData!['clinicalNotes'] != null &&
                        healthRecordData!['clinicalNotes']
                            .toString()
                            .isNotEmpty) ...[
                      _buildSectionHeader('Clinical Notes', Icons.note_alt),
                      _buildContentBox(
                        healthRecordData!['clinicalNotes'].toString(),
                      ),
                    ],

                    // Follow-up Instructions
                    if (healthRecordData!['followUp'] != null &&
                        healthRecordData!['followUp']
                            .toString()
                            .isNotEmpty) ...[
                      _buildSectionHeader(
                        'Follow-up Instructions',
                        Icons.calendar_today,
                      ),
                      _buildContentBox(
                        healthRecordData!['followUp'].toString(),
                      ),
                    ],

                    // Vitals (CHW consultations)
                    if (healthRecordData!['data'] != null &&
                        healthRecordData!['data']['vitals'] != null &&
                        healthRecordData!['data']['vitals']
                            .toString()
                            .isNotEmpty) ...[
                      _buildSectionHeader('Vital Signs', Icons.monitor_heart),
                      _buildContentBox(
                        healthRecordData!['data']['vitals'].toString(),
                      ),
                    ],

                    // Treatment Plan (for CHW consultations - MOVED TO END)
                    if (healthRecordData!['data'] != null &&
                        healthRecordData!['data']['treatment'] != null &&
                        healthRecordData!['data']['treatment']
                            .toString()
                            .isNotEmpty) ...[
                      _buildSectionHeader(
                        'Treatment Plan',
                        Icons.local_hospital,
                      ),
                      _buildContentBox(
                        healthRecordData!['data']['treatment'].toString(),
                      ),
                    ],

                    // Additional Notes (CHW consultations)
                    if (healthRecordData!['data'] != null &&
                        healthRecordData!['data']['notes'] != null &&
                        healthRecordData!['data']['notes']
                            .toString()
                            .isNotEmpty) ...[
                      _buildSectionHeader('Additional Notes', Icons.note),
                      _buildContentBox(
                        healthRecordData!['data']['notes'].toString(),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Detailed consultation notes are not available for this appointment.',
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentBox(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(content, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildListBox(dynamic items) {
    List<String> itemList = [];

    if (items is List) {
      // Doctor consultations: array format
      itemList = items.map((e) => e.toString()).toList();
    } else if (items is String) {
      // CHW consultations: comma-separated string format
      // Split by comma and trim whitespace
      itemList = items
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (itemList.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: itemList.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(item, style: const TextStyle(fontSize: 14)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
