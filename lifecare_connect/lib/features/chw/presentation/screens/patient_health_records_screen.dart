// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PatientHealthRecordsScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const PatientHealthRecordsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$patientName - Health Records'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        // Remove CHW-specific add record button. You may add a generic add record button here if needed.
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getHealthRecordsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text('Error loading health records: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Refresh the stream
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final records = snapshot.data?.docs ?? [];

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, color: Colors.grey, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No health records found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add the first health record by tapping the + button above',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to ANC/PNC Consultation Screen (update route and params as needed)
                      context.push(
                        '/chw_anc_pnc_consultation',
                        extra: {
                          'appointmentId': '', // New record, so no appointmentId yet
                          'patientId': patientId,
                          'patientName': patientName,
                          'appointmentType': 'ANC',
                        },
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add ANC Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final recordData = record.data() as Map<String, dynamic>;
              return _buildHealthRecordCard(context, record.id, recordData);
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getHealthRecordsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    // Query all health records for the patient, regardless of role
    return FirebaseFirestore.instance
        .collection('health_records')
        .where('patientUid', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildHealthRecordCard(BuildContext context, String recordId, Map<String, dynamic> recordData) {
    final type = recordData['type'] ?? 'Unknown';
    final date = recordData['createdAt'] as Timestamp?;
    final providerName = recordData['providerName'] ?? 'Unknown Provider';
    final data = recordData['data'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _showRecordDetails(context, recordId, recordData),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getRecordIcon(type),
                    color: Colors.teal,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getRecordTitle(type),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by $providerName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        date != null
                            ? DateFormat('MMM dd, yyyy').format(date.toDate())
                            : 'Unknown date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        date != null
                            ? DateFormat('hh:mm a').format(date.toDate())
                            : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildRecordSummary(data),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showRecordDetails(context, recordId, recordData),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordSummary(Map<String, dynamic> data) {
    final List<Widget> summaryItems = [];

    if (data['bloodPressure'] != null) {
      summaryItems.add(_buildSummaryItem('BP', data['bloodPressure']));
    }
    if (data['weight'] != null) {
      summaryItems.add(_buildSummaryItem('Weight', '${data['weight']} kg'));
    }
    if (data['height'] != null) {
      summaryItems.add(_buildSummaryItem('Height', '${data['height']} cm'));
    }
    if (data['bmi'] != null) {
      final bmi = data['bmi'].toString();
      final category = data['bmiCategory'] ?? '';
      summaryItems.add(_buildSummaryItem('BMI', '$bmi ($category)'));
    }
    if (data['bloodSugar'] != null) {
      summaryItems.add(_buildSummaryItem('Blood Sugar', '${data['bloodSugar']} mg/dL'));
    }
    if (data['urineAnalysis'] != null && data['urineAnalysis'].toString().isNotEmpty) {
      summaryItems.add(_buildSummaryItem('Urine', data['urineAnalysis']));
    }

    if (summaryItems.isEmpty) {
      return const Text(
        'No vital signs recorded',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: summaryItems,
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.teal,
        ),
      ),
    );
  }

  IconData _getRecordIcon(String type) {
    switch (type) {
      case 'ANC_VISIT':
        return Icons.pregnant_woman;
      case 'PNC_VISIT':
        return Icons.baby_changing_station;
      case 'CONSULTATION':
        return Icons.medical_services;
      case 'pre_consultation':
      case 'PRE_CONSULTATION_CHECKLIST':
        return Icons.assignment_turned_in;
      default:
        return Icons.folder;
    }
  }

  String _getRecordTitle(String type) {
    switch (type) {
      case 'ANC_VISIT':
        return 'Antenatal Care Visit';
      case 'PNC_VISIT':
        return 'Postnatal Care Visit';
      case 'CONSULTATION':
        return 'Medical Consultation';
      case 'pre_consultation':
      case 'PRE_CONSULTATION_CHECKLIST':
        return 'Pre-Consultation Checklist';
      default:
        return 'Health Record';
    }
  }

  void _showRecordDetails(BuildContext context, String recordId, Map<String, dynamic> recordData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          // Merge top-level fields and data fields for display
          final Map<String, dynamic> merged = {...recordData};
          if (recordData['data'] is Map<String, dynamic>) {
            merged.addAll(recordData['data'] as Map<String, dynamic>);
          }
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 40,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getRecordTitle(merged['type'] ?? ''),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recorded on ${_formatDate(merged['createdAt'])}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Divider(height: 32),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: _buildDetailItems(merged),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This record cannot be edited or deleted for audit trail compliance.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDetailItems(Map<String, dynamic> data) {
    final List<Widget> items = [];
    // Always show all available fields for any user (doctor, CHW, etc.)
    // Group by sections if possible, otherwise just list all fields
    if (data.isEmpty) {
      items.add(const Text('No details available', style: TextStyle(color: Colors.grey)));
      return items;
    }

    // Provider Section
    if (data['providerName'] != null) {
      items.add(_DetailItem(label: 'Provider', value: _safeToString(data['providerName'])));
    }
    // Diagnosis Section
    if (data['diagnosis'] != null) {
      items.add(const _SectionHeader(title: 'Diagnosis'));
      items.add(_DetailItem(label: 'Diagnosis', value: _safeToString(data['diagnosis'])));
    }
    if (data['prescription'] != null) {
      items.add(const _SectionHeader(title: 'Prescription'));
      final prescription = data['prescription'];
      if (prescription is List) {
        for (var p in prescription) {
          if (p is String) {
            items.add(_DetailItem(label: 'Prescription', value: p));
          } else if (p is Map<String, dynamic>) {
            // If structured, show as before
            String line = '';
            if (p['medication'] != null) line += p['medication'].toString();
            if (p['strength'] != null) line += ' ${p['strength']}';
            if (p['dosage'] != null) line += ' ${p['dosage']}';
            if (p['frequency'] != null) line += ' ${p['frequency']}';
            if (p['duration'] != null) line += ' for ${p['duration']}';
            if (p['specialInstructions'] != null) line += ' (${p['specialInstructions']})';
            items.add(_DetailItem(label: 'Prescription', value: line.trim()));
          } else {
            items.add(_DetailItem(label: 'Prescription', value: _safeToString(p)));
          }
        }
      } else if (prescription is String) {
        items.add(_DetailItem(label: 'Prescription', value: prescription));
      } else if (prescription is Map<String, dynamic>) {
        String line = '';
        if (prescription['medication'] != null) line += prescription['medication'].toString();
        if (prescription['strength'] != null) line += ' ${prescription['strength']}';
        if (prescription['dosage'] != null) line += ' ${prescription['dosage']}';
        if (prescription['frequency'] != null) line += ' ${prescription['frequency']}';
        if (prescription['duration'] != null) line += ' for ${prescription['duration']}';
        if (prescription['specialInstructions'] != null) line += ' (${prescription['specialInstructions']})';
        items.add(_DetailItem(label: 'Prescription', value: line.trim()));
      } else {
        items.add(_DetailItem(label: 'Prescription', value: _safeToString(prescription)));
      }
    }
    if (data['labRequest'] != null) {
      items.add(const _SectionHeader(title: 'Lab Request'));
      items.add(_DetailItem(label: 'Lab Request', value: _safeToString(data['labRequest'])));
    }
    if (data['radiologyRequest'] != null) {
      items.add(const _SectionHeader(title: 'Radiology Request'));
      items.add(_DetailItem(label: 'Radiology Request', value: _safeToString(data['radiologyRequest'])));
    }
    if (data['followUpNote'] != null) {
      items.add(const _SectionHeader(title: 'Follow-up Note'));
      items.add(_DetailItem(label: 'Follow-up Note', value: _safeToString(data['followUpNote'])));
    }
    if (data['additionalNotes'] != null) {
      items.add(const _SectionHeader(title: 'Additional Notes'));
      items.add(_DetailItem(label: 'Additional Notes', value: _safeToString(data['additionalNotes'])));
    }
    if (data['bloodPressure'] != null || data['weight'] != null || data['height'] != null || data['bmi'] != null) {
      items.add(const _SectionHeader(title: 'Vital Signs'));
      if (data['bloodPressure'] != null) {
        items.add(_DetailItem(label: 'Blood Pressure', value: _safeToString(data['bloodPressure'])));
      }
      if (data['weight'] != null) {
        items.add(_DetailItem(label: 'Weight', value: '${data['weight']} kg'));
      }
      if (data['height'] != null) {
        items.add(_DetailItem(label: 'Height', value: '${data['height']} cm'));
      }
      if (data['bmi'] != null) {
        final bmi = double.parse(data['bmi'].toString()).toStringAsFixed(1);
        final category = data['bmiCategory'] ?? '';
        items.add(_DetailItem(label: 'BMI', value: '$bmi ($category)'));
      }
    }
    if (data['bloodSugar'] != null || data['urineAnalysis'] != null) {
      items.add(const _SectionHeader(title: 'Laboratory Results'));
      if (data['bloodSugar'] != null) {
        items.add(_DetailItem(label: 'Blood Sugar', value: '${data['bloodSugar']} mg/dL'));
      }
      if (data['urineAnalysis'] != null) {
        items.add(_DetailItem(label: 'Urine Analysis', value: _safeToString(data['urineAnalysis'])));
      }
    }
    if (data['symptoms'] != null || data['medications'] != null || data['notes'] != null) {
      items.add(const _SectionHeader(title: 'Clinical Notes'));
      if (data['symptoms'] != null) {
        items.add(_DetailItem(label: 'Symptoms', value: _safeToString(data['symptoms'])));
      }
      if (data['medications'] != null) {
        items.add(_DetailItem(label: 'Medications', value: _safeToString(data['medications'])));
      }
      if (data['notes'] != null) {
        items.add(_DetailItem(label: 'Additional Notes', value: _safeToString(data['notes'])));
      }
    }
    if (data['checklistData'] != null) {
      items.add(const _SectionHeader(title: 'ANC Checklist'));
      final checklistData = data['checklistData'] as Map<String, dynamic>;
      if (checklistData['currentSymptoms'] != null) {
        items.add(_DetailItem(label: 'Current Symptoms', value: _safeToString(checklistData['currentSymptoms'])));
      }
      if (checklistData['pregnancyWeek'] != null) {
        items.add(_DetailItem(label: 'Pregnancy Week', value: _safeToString(checklistData['pregnancyWeek'])));
      }
      if (checklistData['lastMenstrualPeriod'] != null) {
        items.add(_DetailItem(label: 'Last Menstrual Period', value: _safeToString(checklistData['lastMenstrualPeriod'])));
      }
      if (checklistData['previousPregnancies'] != null) {
        items.add(_DetailItem(label: 'Previous Pregnancies', value: _safeToString(checklistData['previousPregnancies'])));
      }
      if (checklistData['complications'] != null) {
        items.add(_DetailItem(label: 'Complications', value: _safeToString(checklistData['complications'])));
      }
      if (checklistData['currentMedications'] != null) {
        items.add(_DetailItem(label: 'Current Medications', value: _safeToString(checklistData['currentMedications'])));
      }
    }
    final healthAssessment = data['healthAssessment'] as Map<String, dynamic>?;
    final hasPreConsultTop = data['reason'] != null || data['symptoms'] != null || data['currentMedications'] != null || data['allergies'] != null || data['appointmentType'] != null || data['durationOfSymptoms'] != null || data['appointmentDate'] != null || data['consultationChannel'] != null || data['medicalHistory'] != null;
    final hasPreConsultNested = healthAssessment != null && healthAssessment.isNotEmpty;
    bool addedAny = false;
    if (hasPreConsultTop || hasPreConsultNested) {
      items.add(const _SectionHeader(title: 'Pre-Consultation Information'));
      final ignored = {'providerName','providerType','appointmentId','createdAt','updatedAt','userId','patientUid','type','healthAssessment','attachments','source','submissionTimestamp'};
      data.forEach((key, value) {
        if (!ignored.contains(key) && value != null && key != 'healthAssessment') {
          items.add(_DetailItem(label: _formatFieldName(key), value: _safeToString(value)));
          addedAny = true;
        }
      });
      if (healthAssessment != null) {
        healthAssessment.forEach((key, value) {
          if (value != null) {
            items.add(_DetailItem(label: _formatFieldName(key), value: _safeToString(value)));
            addedAny = true;
          }
        });
      }
      if (!addedAny) {
        items.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No pre-consultation details available.', style: TextStyle(color: Colors.grey)),
        ));
      }
    }
    if (data['nextVisitDate'] != null) {
      items.add(const _SectionHeader(title: 'Follow-up'));
      final nextVisit = data['nextVisitDate'] as Timestamp;
      items.add(_DetailItem(
        label: 'Next Visit Date',
        value: DateFormat('MMMM dd, yyyy').format(nextVisit.toDate()),
      ));
    }
    final handledFields = {
      'providerName', 'diagnosis', 'prescription', 'labRequest', 'radiologyRequest', 'followUpNote', 'additionalNotes',
      'bloodPressure', 'weight', 'height', 'bmi', 'bmiCategory',
      'bloodSugar', 'urineAnalysis', 'symptoms', 'medications', 'notes',
      'checklistData', 'reason', 'allergies', 'medicalHistory', 'currentMedications',
      'nextVisitDate', 'createdAt', 'type', 'userId', 'date', 'accessibleBy'
    };
    final additionalFields = data.entries
        .where((entry) => !handledFields.contains(entry.key) && entry.value != null)
        .toList();
    if (additionalFields.isNotEmpty) {
      items.add(const _SectionHeader(title: 'Additional Information'));
      for (final entry in additionalFields) {
        items.add(_DetailItem(
          label: _formatFieldName(entry.key),
          value: _safeToString(entry.value),
        ));
      }
    }
    return items;
  }

  String _safeToString(dynamic value) {
    if (value == null) return 'N/A';
    if (value is String) return value;
    if (value is Map<String, dynamic>) {
      // Convert map to readable format
      final entries = value.entries
          .where((e) => e.value != null)
          .map((e) => '${_formatFieldName(e.key)}: ${_safeToString(e.value)}')
          .join('\n');
      return entries.isNotEmpty ? entries : 'No data available';
    }
    if (value is List) {
      return value.map((item) => _safeToString(item)).join(', ');
    }
    return value.toString();
  }

  String _formatFieldName(String fieldName) {
    // Convert camelCase to readable format
    return fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1))
        .join(' ')
        .trim();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    if (timestamp is Timestamp) {
      return DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(timestamp.toDate());
    }
    return 'Unknown date';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
