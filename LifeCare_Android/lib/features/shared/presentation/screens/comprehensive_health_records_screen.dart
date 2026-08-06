// ignore_for_file: deprecated_member_use, prefer_const_constructors, sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/data/services/health_records_service.dart';

class ComprehensiveHealthRecordsScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;
  final String currentUserRole;

  const ComprehensiveHealthRecordsScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
    required this.currentUserRole,
  });

  @override
  State<ComprehensiveHealthRecordsScreen> createState() =>
      _ComprehensiveHealthRecordsScreenState();
}

class _ComprehensiveHealthRecordsScreenState
    extends State<ComprehensiveHealthRecordsScreen> {
  // --- Helper variables and methods (must be declared before usage) ---
  final List<String> _filterOptions = [
    'ALL',
    'ANC_VISIT',
    'DOCTOR_CONSULTATION',
    'CHW_CONSULTATION',
    'SELF_REPORTED_VITALS',
    'LAB_RESULTS',
    'PRE_CONSULTATION_CHECKLIST',
    'FACILITY_RESULTS',
  ];

  String _selectedFilter = 'ALL';

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'ALL':
        return 'All Records';
      case 'ANC_VISIT':
        return 'ANC Visits';
      case 'DOCTOR_CONSULTATION':
        return 'Doctor Consultations';
      case 'CHW_CONSULTATION':
        return 'CHW Consultations';
      case 'SELF_REPORTED_VITALS':
        return 'Self Reported Vitals';
      case 'LAB_RESULTS':
        return 'Lab Results';
      case 'PRE_CONSULTATION_CHECKLIST':
        return 'Pre-Consultation Checklist';
      case 'FACILITY_RESULTS':
        return 'Facility Results';
      default:
        return filter;
    }
  }

  Stream<QuerySnapshot> _getHealthRecordsStream() {
    if (_selectedFilter == 'ALL') {
      return HealthRecordsService.getPatientHealthRecords(
        patientUid: widget.patientUid,
        currentUserRole: widget.currentUserRole,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
    } else {
      return HealthRecordsService.getRecordsByType(
        patientUid: widget.patientUid,
        recordType: _selectedFilter,
        currentUserRole: widget.currentUserRole,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
    }
  }

  Color _getAppBarColor() {
    switch (widget.currentUserRole) {
      case 'doctor':
        return Colors.blue;
      case 'chw':
        return Colors.green;
      case 'patient':
        return Colors.orange;
      case 'facility':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  bool _isSystemField(String key) {
    const systemFields = [
      'type',
      'patientUid',
      'providerId',
      'chwUid',
      'doctorUid',
      'providerName',
      'providerType',
      'date',
      'createdAt',
      'updatedAt',
      'accessibleBy',
      'isEditable',
      'isDeletable',
      'recordId',
      'id',
      'source',
      'status',
      'appointmentId',
      'userId',
      'patientId',
      'data',
      'fileUrls',
      'fileNames',
      'uploadDate',
      'submissionTimestamp',
      'requiresReview',
    ];
    return systemFields.contains(key);
  }

  String _formatFieldName(String fieldName) {
    // Convert camelCase and snake_case to readable format
    String formatted = fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ')
        .trim();
    return formatted;
  }

  // --- End helper methods ---

  Color _getRecordColor(String type) {
    switch (type) {
      case 'ANC_VISIT':
        return Colors.purple;
      case 'DOCTOR_CONSULTATION':
        return Colors.blue;
      case 'CHW_CONSULTATION':
        return Colors.green;
      case 'SELF_REPORTED_VITALS':
        return Colors.orange;
      case 'LAB_RESULTS':
        return Colors.red;
      case 'PRE_CONSULTATION_CHECKLIST':
        return Colors.teal;
      case 'FACILITY_RESULTS':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecordCard(String recordId, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'UNKNOWN';
    final providerName = data['providerName'] as String? ?? 'Unknown Provider';
    final providerType = data['providerType'] as String? ?? 'Unknown';
    final createdAt = data['createdAt'] as Timestamp?;
    final formattedDate =
        createdAt?.toDate().toString().split(' ')[0] ?? 'Unknown Date';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRecordDetails(recordId, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getRecordColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _getRecordColor(type)),
                ),
                child: Center(
                  child: Text(
                    HealthRecordsService.getRecordIcon(type),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HealthRecordsService.getDisplayType(type),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By: $providerName ($providerType)',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRecordColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'View Only',
                  style: TextStyle(
                    fontSize: 10,
                    color: _getRecordColor(type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (widget.currentUserRole) {
      case 'doctor':
        return Icons.medical_services;
      case 'chw':
        return Icons.health_and_safety;
      case 'patient':
        return Icons.person;
      case 'facility':
        return Icons.local_hospital;
      default:
        return Icons.account_circle;
    }
  }

  String _getRoleDisplayName() {
    switch (widget.currentUserRole) {
      case 'doctor':
        return 'Doctor';
      case 'chw':
        return 'CHW';
      case 'patient':
        return 'Patient';
      case 'facility':
        return 'Facility';
      default:
        return 'Unknown';
    }
  }

  // Add your missing build method here if not present
  @override
  Widget build(BuildContext context) {
    // Your build implementation here
    return Scaffold(
      appBar: AppBar(
        title: Text('Health Records - ${widget.patientName}'),
        backgroundColor: _getAppBarColor(),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => _filterOptions.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Text(_getFilterDisplayName(filter)),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getRoleIcon(), color: _getAppBarColor()),
                      const SizedBox(width: 8),
                      Text(
                        'Viewing as: ${_getRoleDisplayName()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patient: ${widget.patientName}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (_selectedFilter != 'ALL') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Filter: ${_getFilterDisplayName(_selectedFilter)}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Records List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
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
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No health records found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedFilter == 'ALL'
                              ? 'No records have been created yet'
                              : 'No records of this type found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final data = record.data() as Map<String, dynamic>;
                    return _buildRecordCard(record.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    // You can customize the FAB as needed, here is a simple example:
    return FloatingActionButton(
      onPressed: () {
        // Add your desired action here, e.g., navigate to add record screen
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('FAB pressed!')));
      },
      child: const Icon(Icons.add),
      backgroundColor: _getAppBarColor(),
      tooltip: 'Add Health Record',
    );
  }

  // ...existing code for details, FAB, etc...

  void _showRecordDetails(String recordId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        final providerName =
            data['providerName'] as String? ??
            data['chwName'] as String? ??
            data['doctorName'] as String? ??
            'Unknown';
        return AlertDialog(
          title: Text('Record Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (providerName.isNotEmpty)
                  _buildDetailSection('Provider', providerName),
                if (data['diagnosis'] != null)
                  _buildDetailSection(
                    'Diagnosis',
                    data['diagnosis'].toString(),
                  ),
                if (data['prescription'] != null)
                  _buildDetailSection(
                    'Prescription',
                    data['prescription'].toString(),
                  ),
                if (data['labRequest'] != null)
                  _buildDetailSection(
                    'Lab Request',
                    data['labRequest'].toString(),
                  ),
                if (data['radiologyRequest'] != null)
                  _buildDetailSection(
                    'Radiology Request',
                    data['radiologyRequest'].toString(),
                  ),
                if (data['followUpNote'] != null)
                  _buildDetailSection(
                    'Follow-up Note',
                    data['followUpNote'].toString(),
                  ),
                if (data['additionalNotes'] != null)
                  _buildDetailSection(
                    'Additional Notes',
                    data['additionalNotes'].toString(),
                  ),
                // Pre-consultation Checklist Section
                if (data['reason'] != null ||
                    data['allergies'] != null ||
                    data['medicalHistory'] != null) ...[
                  _buildDetailSection(
                    'Reason for Visit',
                    data['reason']?.toString() ?? '',
                  ),
                  _buildDetailSection(
                    'Known Allergies',
                    data['allergies']?.toString() ?? '',
                  ),
                  _buildDetailSection(
                    'Medical History',
                    data['medicalHistory']?.toString() ?? '',
                  ),
                  if (data['currentMedications'] != null)
                    _buildDetailSection(
                      'Current Medications',
                      data['currentMedications'].toString(),
                    ),
                ],
                // Fallback: show all other fields not handled above
                ...data.entries
                    .where(
                      (entry) =>
                          !_isSystemField(entry.key) &&
                          ![
                            'providerName',
                            'chwName',
                            'doctorName',
                            'diagnosis',
                            'prescription',
                            'labRequest',
                            'radiologyRequest',
                            'followUpNote',
                            'additionalNotes',
                            'reason',
                            'allergies',
                            'medicalHistory',
                            'currentMedications',
                          ].contains(entry.key),
                    )
                    .map(
                      (entry) => _buildDetailSection(
                        _formatFieldName(entry.key),
                        entry.value?.toString() ?? '',
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

// REMOVE EVERYTHING BELOW THIS LINE (duplicate imports, ignore comments, duplicate class definitions)
