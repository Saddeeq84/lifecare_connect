// ignore_for_file: use_build_context_synchronously, prefer_final_fields, deprecated_member_use, prefer_const_constructors, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/services/health_records_service.dart';
import '../../../shared/helpers/chw_message_helper.dart';

class CHWConsultationDetailsScreen extends StatefulWidget {
  final String appointmentId;
  final String patientId;
  final String patientName;
  final Map<String, dynamic> appointmentData;
  final bool isReadOnly;

  const CHWConsultationDetailsScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.appointmentData,
    this.isReadOnly = false,
  });

  @override
  State<CHWConsultationDetailsScreen> createState() =>
      _CHWConsultationDetailsScreenState();
}

class _CHWConsultationDetailsScreenState
    extends State<CHWConsultationDetailsScreen>
    with TickerProviderStateMixin {
  String _selectedRequestCategory = 'Lab';
  late TabController _tabController;
  final _consultationFormKey = GlobalKey<FormState>();
  final _prescriptionFormKey = GlobalKey<FormState>();
  final _labRequestFormKey = GlobalKey<FormState>();

  // Consultation fields
  final _symptomsController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _vitalsController = TextEditingController();

  // Prescription fields
  final _medicationNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();

  // Lab/Radiology request fields
  final _requestTypeController = TextEditingController();
  final _requestReasonController = TextEditingController();
  final _urgencyController = TextEditingController();
  final _facilityController = TextEditingController();

  List<Map<String, dynamic>> _prescriptions = [];
  List<Map<String, dynamic>> _labRequests = [];
  List<Map<String, dynamic>> _facilities = [];

  bool _isLoading = false;

  final List<String> _commonMedications = [
    'Paracetamol',
    'Ibuprofen',
    'Amoxicillin',
    'Metformin',
    'Lisinopril',
    'Aspirin',
    'Omeprazole',
    'Salbutamol',
    'Prednisolone',
    'Doxycycline',
    'Ciprofloxacin',
    'Azithromycin',
    'Amoxicillin-Clavulanate',
    'Cetirizine',
    'Loratadine',
    'Hydroxychloroquine',
    'Vitamin C',
    'Multivitamins',
    'Other',
  ];

  final List<String> _commonLabTests = [
    'Full Blood Count',
    'Malaria Test',
    'Blood Sugar',
    'Urine Analysis',
    'Stool Test',
    'Pregnancy Test',
    'HIV Test',
    'Hepatitis B Test',
    'Liver Function Test',
    'Kidney Function Test',
    'Electrolytes',
    'Widal Test',
    'Typhoid Test',
    'Other',
  ];

  final List<String> _commonRadiologyTests = [
    'Chest X-ray',
    'Abdominal X-ray',
    'Ultrasound - Abdomen',
    'Ultrasound - Pelvis',
    'Ultrasound - Pregnancy',
    'CT Scan - Head',
    'MRI - Spine',
    'Mammography',
    'Bone X-ray',
    'Dental X-ray',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFacilities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _symptomsController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    _vitalsController.dispose();
    _medicationNameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _requestTypeController.dispose();
    _requestReasonController.dispose();
    _urgencyController.dispose();
    _facilityController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    try {
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _facilities = facilitiesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['facilityName'] ?? data['name'] ?? 'Unknown Facility',
            'type': data['facilityType'] ?? data['type'] ?? 'hospital',
            'services': data['services'] ?? [],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading facilities: $e');
    }
  }

  void _addPrescription() {
    if (widget.isReadOnly) return;
    if (_prescriptionFormKey.currentState!.validate()) {
      setState(() {
        _prescriptions.add({
          'medication': _medicationNameController.text.trim(),
          'dosage': _dosageController.text.trim(),
          'frequency': _frequencyController.text.trim(),
          'duration': _durationController.text.trim(),
          'instructions': _instructionsController.text.trim(),
          'prescribedAt': DateTime.now(),
          'prescribedBy': FirebaseAuth.instance.currentUser?.uid,
        });
      });

      // Clear form
      _medicationNameController.clear();
      _dosageController.clear();
      _frequencyController.clear();
      _durationController.clear();
      _instructionsController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription added successfully')),
      );
    }
  }

  void _addLabRequest() {
    if (widget.isReadOnly) return;
    if (_labRequestFormKey.currentState!.validate()) {
      setState(() {
        _labRequests.add({
          'requestType': _requestTypeController.text.trim(),
          'reason': _requestReasonController.text.trim(),
          'urgency': _urgencyController.text.trim(),
          'facility': _facilityController.text.trim(),
          'requestedAt': DateTime.now(),
          'requestedBy': FirebaseAuth.instance.currentUser?.uid,
          'status': 'pending',
        });
      });

      // Clear form
      _requestTypeController.clear();
      _requestReasonController.clear();
      _urgencyController.clear();
      _facilityController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lab/Radiology request added successfully'),
        ),
      );
    }
  }

  Future<void> _saveConsultation() async {
    if (!_consultationFormKey.currentState!.validate()) {
      _tabController.animateTo(0); // Go to consultation tab
      return;
    }

    setState(() => _isLoading = true);

    // Show confirmation dialog before saving
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: const Text(
          'Are you sure you want to complete this consultation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Compose unified health record data
      final healthRecordData = {
        'appointmentId': widget.appointmentId,
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'chwId': currentUser.uid,
        'symptoms': _symptomsController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatment': _treatmentController.text.trim(),
        'vitals': _vitalsController.text.trim(),
        'notes': _notesController.text.trim(),
        'prescriptions': _prescriptions,
        'labRequests': _labRequests,
        'consultationDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'statusFlag': 'completed',
      };

      // Save unified record to health_records only
      await HealthRecordsService.saveCHWConsultation(
        patientUid: widget.patientId,
        chwUid: currentUser.uid,
        chwName: 'Community Health Worker',
        consultationData: healthRecordData,
      );

      // Update appointment status
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(widget.appointmentId)
          .update({
            'status': 'completed',
            'consultationCompleted': true,
            'completedAt': FieldValue.serverTimestamp(),
          });

      // Notify patient about new vitals, prescriptions, and lab requests
      try {
        if (_vitalsController.text.trim().isNotEmpty) {
          await CHWMessageHelper.sendHealthRecordUpdateToPatient(
            widget.patientId,
            'vitals',
            _vitalsController.text.trim(),
          );
        }
        if (_prescriptions.isNotEmpty) {
          await CHWMessageHelper.sendHealthRecordUpdateToPatient(
            widget.patientId,
            'prescription',
            'New prescription(s) added.',
          );
        }
        if (_labRequests.isNotEmpty) {
          await CHWMessageHelper.sendHealthRecordUpdateToPatient(
            widget.patientId,
            'lab',
            'New lab/radiology request(s) added.',
          );
        }
      } catch (e) {
        debugPrint('Error sending health record update to patient: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      context.pop();
    } catch (e) {
      debugPrint('Error saving consultation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving consultation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Consultation - ${widget.patientName}'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chw_dashboard/patients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              context.go('/chw_dashboard/profile');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.medical_services), text: 'Consultation'),
            Tab(icon: Icon(Icons.medication), text: 'Prescriptions'),
            Tab(icon: Icon(Icons.science), text: 'Lab/Radiology'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConsultationTab(),
          _buildPrescriptionTab(),
          _buildLabRequestTab(),
        ],
      ),
      // Hide the save button and bottom bar if read-only
      bottomNavigationBar: widget.isReadOnly
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: widget.isReadOnly || _isLoading
                    ? null
                    : _saveConsultation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('Complete Consultation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
    );
  }

  Widget _buildConsultationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _consultationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info Card
            Card(
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${widget.patientName}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Appointment ID: ${widget.appointmentId}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Expanded Summary Cards with more detail
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.medication, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          // Counter icon for prescriptions
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.format_list_numbered,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_prescriptions.length}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _prescriptions.isNotEmpty
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _prescriptions[0]['medication'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_prescriptions[0]['dosage'] ?? ''} - ${_prescriptions[0]['frequency'] ?? ''}',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      if ((_prescriptions[0]['instructions'] ??
                                              '')
                                          .isNotEmpty)
                                        Text(
                                          'Note: ${_prescriptions[0]['instructions']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  )
                                : Text(
                                    'No prescriptions added',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.science, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          // Counter icon for lab/radiology
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.format_list_numbered,
                                  color: Colors.orange.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_labRequests.length}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _labRequests.isNotEmpty
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _labRequests[0]['requestType'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Indication: ${_labRequests[0]['reason'] ?? ''}',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      if ((_labRequests[0]['facility'] ?? '')
                                          .isNotEmpty)
                                        Text(
                                          'Facility: ${_labRequests[0]['facility']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                    ],
                                  )
                                : Text(
                                    'No lab/radiology requests',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Consultation form fields
            TextFormField(
              controller: _vitalsController,
              decoration: const InputDecoration(
                labelText: 'Vital Signs',
                hintText: 'BP: 120/80, Temp: 37°C, Pulse: 72 bpm',
                prefixIcon: Icon(Icons.monitor_heart),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              readOnly: widget.isReadOnly,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _symptomsController,
              decoration: const InputDecoration(
                labelText: 'Symptoms *',
                hintText: 'Describe the patient\'s symptoms',
                prefixIcon: Icon(Icons.sick),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the patient\'s symptoms';
                }
                return null;
              },
              readOnly: widget.isReadOnly,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis/Assessment *',
                hintText: 'Your clinical assessment',
                prefixIcon: Icon(Icons.psychology),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your diagnosis or assessment';
                }
                return null;
              },
              readOnly: widget.isReadOnly,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _treatmentController,
              decoration: const InputDecoration(
                labelText: 'Treatment Plan *',
                hintText: 'Describe the treatment given or recommended',
                prefixIcon: Icon(Icons.healing),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the treatment plan';
                }
                return null;
              },
              readOnly: widget.isReadOnly,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                hintText: 'Any additional observations or instructions',
                prefixIcon: Icon(Icons.note_add),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              readOnly: widget.isReadOnly,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Prescription Form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _prescriptionFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Prescription',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Medication Name with suggestions
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _commonMedications;
                        }
                        return _commonMedications.where(
                          (medication) => medication.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (selection) {
                        _medicationNameController.text = selection;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            // Add listener to sync controller text (safe to add repeatedly in this context)
                            _medicationNameController.addListener(() {
                              if (controller.text !=
                                  _medicationNameController.text) {
                                controller.text =
                                    _medicationNameController.text;
                                controller
                                    .selection = TextSelection.fromPosition(
                                  TextPosition(offset: controller.text.length),
                                );
                              }
                            });
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              onEditingComplete: onEditingComplete,
                              decoration: const InputDecoration(
                                labelText: 'Medication Name *',
                                prefixIcon: Icon(Icons.medication),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter medication name';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                if (_medicationNameController.text != value) {
                                  _medicationNameController.text = value;
                                }
                              },
                              readOnly: widget.isReadOnly,
                            );
                          },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dosageController,
                            decoration: const InputDecoration(
                              labelText: 'Dosage *',
                              hintText: 'e.g., 500mg',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter dosage';
                              }
                              return null;
                            },
                            readOnly: widget.isReadOnly,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _frequencyController,
                            decoration: const InputDecoration(
                              labelText: 'Frequency *',
                              hintText: 'e.g., 3 times daily',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter frequency';
                              }
                              return null;
                            },
                            readOnly: widget.isReadOnly,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration *',
                              hintText: 'e.g., 7 days',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter duration';
                              }
                              return null;
                            },
                            readOnly: widget.isReadOnly,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.isReadOnly
                                ? null
                                : _addPrescription,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Special Instructions',
                        hintText: 'Take with food, avoid alcohol, etc.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      readOnly: widget.isReadOnly,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Prescriptions List
          Text(
            'Prescriptions (${_prescriptions.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (_prescriptions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.medication_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No prescriptions added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _prescriptions.length,
              itemBuilder: (context, index) {
                final prescription = _prescriptions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    title: Text(
                      prescription['medication'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${prescription['dosage']} - ${prescription['frequency']} for ${prescription['duration']}\n'
                      '${prescription['instructions'].isNotEmpty ? prescription['instructions'] : 'No special instructions'}',
                    ),
                    trailing: widget.isReadOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _prescriptions.removeAt(index);
                              });
                            },
                          ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLabRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Lab/Radiology Request Form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _labRequestFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Lab/Radiology Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Select Lab or Radiology first
                    DropdownButtonFormField<String>(
                      value: _selectedRequestCategory,
                      decoration: const InputDecoration(
                        labelText: 'Request Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Lab', child: Text('Lab')),
                        DropdownMenuItem(
                          value: 'Radiology',
                          child: Text('Radiology'),
                        ),
                      ],
                      onChanged: widget.isReadOnly
                          ? null
                          : (String? value) {
                              setState(() {
                                _selectedRequestCategory = value ?? 'Lab';
                                _requestTypeController.clear();
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    // Request Type with suggestions, filtered by category, with 'Others' option
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        final List<String> baseList =
                            _selectedRequestCategory == 'Lab'
                            ? List<String>.from(_commonLabTests)
                            : List<String>.from(_commonRadiologyTests);
                        // Ensure 'Other' is always present at the end
                        if (!baseList.contains('Other')) baseList.add('Other');
                        if (textEditingValue.text.isEmpty) {
                          return baseList;
                        }
                        return baseList.where(
                          (test) => test.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (selection) {
                        _requestTypeController.text = selection;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                            _requestTypeController.addListener(() {
                              if (controller.text !=
                                  _requestTypeController.text) {
                                controller.text = _requestTypeController.text;
                                controller
                                    .selection = TextSelection.fromPosition(
                                  TextPosition(offset: controller.text.length),
                                );
                              }
                            });
                            return Column(
                              children: [
                                TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onEditingComplete: onEditingComplete,
                                  decoration: const InputDecoration(
                                    labelText: 'Test/Scan Type *',
                                    prefixIcon: Icon(Icons.science),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter test/scan type';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    if (_requestTypeController.text != value) {
                                      _requestTypeController.text = value;
                                    }
                                  },
                                  readOnly: widget.isReadOnly,
                                ),
                                if (controller.text == 'Other')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: TextFormField(
                                      enabled: !widget.isReadOnly,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Specify Other Test/Investigation',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        _requestTypeController.text = val;
                                      },
                                      validator: (val) {
                                        if (controller.text == 'Other' &&
                                            (val == null ||
                                                val.trim().isEmpty)) {
                                          return 'Please specify the test/investigation';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                              ],
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _requestReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Clinical Indication *',
                        hintText: 'Reason for the test/scan',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter clinical indication';
                        }
                        return null;
                      },
                      readOnly: widget.isReadOnly,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: widget.isReadOnly,
                            child: DropdownButtonFormField<String>(
                              value: _urgencyController.text.isEmpty
                                  ? null
                                  : _urgencyController.text,
                              decoration: const InputDecoration(
                                labelText: 'Urgency *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Routine',
                                  child: Text('Routine'),
                                ),
                                DropdownMenuItem(
                                  value: 'Urgent',
                                  child: Text('Urgent'),
                                ),
                                DropdownMenuItem(
                                  value: 'STAT',
                                  child: Text('STAT (Immediate)'),
                                ),
                              ],
                              onChanged: widget.isReadOnly
                                  ? null
                                  : (String? value) {
                                      _urgencyController.text = value ?? '';
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Select urgency';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: widget.isReadOnly,
                            child: DropdownButtonFormField<String>(
                              value: _facilityController.text.isEmpty
                                  ? null
                                  : _facilityController.text,
                              decoration: const InputDecoration(
                                labelText: 'Preferred Facility',
                                border: OutlineInputBorder(),
                              ),
                              items: _facilities.map((facility) {
                                return DropdownMenuItem<String>(
                                  value: facility['name'],
                                  child: Text(facility['name']),
                                );
                              }).toList(),
                              onChanged: widget.isReadOnly
                                  ? null
                                  : (String? value) {
                                      _facilityController.text = value ?? '';
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: widget.isReadOnly ? null : _addLabRequest,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Lab/Radiology Requests List
          Text(
            'Lab/Radiology Requests (${_labRequests.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (_labRequests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No lab/radiology requests added yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _labRequests.length,
              itemBuilder: (context, index) {
                final request = _labRequests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.science, color: Colors.orange.shade700),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          Icons.biotech,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            request['requestType'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 80,
                              child: Text(
                                request['reason'].length > 6
                                    ? request['reason'].substring(0, 6) + '...'
                                    : request['reason'],
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 80,
                              child: Text(
                                request['urgency'].length > 6
                                    ? request['urgency'].substring(0, 6) + '...'
                                    : request['urgency'],
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.local_hospital,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 80,
                              child: Text(
                                request['facility'].isNotEmpty
                                    ? (request['facility'].length > 6
                                          ? request['facility'].substring(
                                                  0,
                                                  6,
                                                ) +
                                                '...'
                                          : request['facility'])
                                    : 'No facility',
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: widget.isReadOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _labRequests.removeAt(index);
                              });
                            },
                          ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
