import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifecare_connect/features/shared/presentation/widgets/searchable_patient_selector.dart';

class AdmissionScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final String? patientId;
  final String? patientName;
  final String? admittingDepartment; // Department that is admitting the patient

  const AdmissionScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.patientId,
    this.patientName,
    this.admittingDepartment, // Optional, defaults to OPD if not provided
  });

  @override
  State<AdmissionScreen> createState() => _AdmissionScreenState();
}

class _AdmissionScreenState extends State<AdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _admissionDiagnosisController = TextEditingController();
  final _admissionNotesController = TextEditingController();
  final _expectedDurationController = TextEditingController();

  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedWardId;
  String? _selectedWardName;
  String? _selectedBedId;
  String? _selectedBedNumber;
  String _patientStatus = 'stable';
  String _admissionType = 'planned';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill patient if provided
    if (widget.patientId != null && widget.patientName != null) {
      _selectedPatientId = widget.patientId;
      _selectedPatientName = widget.patientName;
    }
  }

  @override
  void dispose() {
    _admissionDiagnosisController.dispose();
    _admissionNotesController.dispose();
    _expectedDurationController.dispose();
    super.dispose();
  }

  Future<void> _admitPatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedWardId == null || _selectedBedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a ward and bed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final admissionId = FirebaseFirestore.instance
          .collection('admissions')
          .doc()
          .id;

      // Create admission record
      await FirebaseFirestore.instance
          .collection('admissions')
          .doc(admissionId)
          .set({
            'admissionId': admissionId,
            'patientId': _selectedPatientId,
            'patientName': _selectedPatientName,
            'facilityId': widget.facilityId,
            'facilityName': widget.facilityName,
            'wardId': _selectedWardId,
            'wardName': _selectedWardName,
            'bedId': _selectedBedId,
            'bedNumber': _selectedBedNumber,
            'admissionDiagnosis': _admissionDiagnosisController.text.trim(),
            'admissionNotes': _admissionNotesController.text.trim(),
            'admissionType': _admissionType,
            'patientStatus': _patientStatus,
            'expectedDuration': _expectedDurationController.text.trim(),
            'admittingDoctorId': widget.staffId,
            'admittingDoctorName': widget.staffName,
            'department':
                widget.admittingDepartment ??
                'Out-Patient Department (OPD)', // Use provided department or default to OPD
            'admittedBy': widget.staffName, // REQUIRED for Firestore rules
            'admissionDate': FieldValue.serverTimestamp(),
            'admittedAt':
                FieldValue.serverTimestamp(), // Add admittedAt timestamp
            'status':
                'pending_acceptance', // Waiting for nursing department to accept
            'isActive': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Update bed status to 'reserved' (not occupied yet)
      await FirebaseFirestore.instance
          .collection('beds')
          .doc(_selectedBedId)
          .update({
            'status': 'reserved', // Reserved until nursing accepts
            'reservedFor': _selectedPatientId,
            'reservedForName': _selectedPatientName,
            'admissionId': admissionId,
            'reservedAt': FieldValue.serverTimestamp(),
          });

      // Don't update patient admission status yet - wait for nursing to accept
      // Patient will be marked as admitted after nursing department accepts

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admission request sent to nursing department for approval',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error admitting patient: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admit Patient'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Patient Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Patient Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Show pre-selected patient or dropdown
                          if (widget.patientId != null &&
                              widget.patientName != null)
                            // Pre-selected patient (read-only)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                border: Border.all(color: Colors.blue.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Patient',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.patientName!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.check_circle, color: Colors.green),
                                ],
                              ),
                            )
                          else
                            // Patient selection with search
                            SearchablePatientSelector(
                              selectedPatientId: _selectedPatientId,
                              selectedPatientName: _selectedPatientName,
                              facilityId: widget.facilityId,
                              onPatientSelected: (patientId, patientName) {
                                setState(() {
                                  _selectedPatientId = patientId;
                                  _selectedPatientName = patientName;
                                });
                              },
                              currentUserRole: 'facility',
                              hintText: 'Search and select patient',
                              isRequired: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ward and Bed Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ward & Bed Assignment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('wards')
                                .where(
                                  'facilityId',
                                  isEqualTo: widget.facilityId,
                                )
                                .where('isActive', isEqualTo: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }

                              final wards = snapshot.data!.docs;

                              return DropdownButtonFormField<String>(
                                value: _selectedWardId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Ward',
                                  border: OutlineInputBorder(),
                                ),
                                items: wards.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(
                                      '${data['wardName']} - ${data['wardType']}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedWardId = value;
                                    // Find and store the ward name
                                    final selectedWard = wards.firstWhere(
                                      (doc) => doc.id == value,
                                    );
                                    final wardData =
                                        selectedWard.data()
                                            as Map<String, dynamic>?;
                                    _selectedWardName = wardData?['wardName'];
                                    _selectedBedId =
                                        null; // Reset bed selection
                                    _selectedBedNumber =
                                        null; // Reset bed number
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a ward';
                                  }
                                  return null;
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_selectedWardId != null)
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('beds')
                                  .where(
                                    'facilityId',
                                    isEqualTo: widget.facilityId,
                                  )
                                  .where('wardId', isEqualTo: _selectedWardId)
                                  .where('status', isEqualTo: 'available')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final beds = snapshot.data!.docs;

                                if (beds.isEmpty) {
                                  return const Text(
                                    'No available beds in this ward',
                                    style: TextStyle(color: Colors.red),
                                  );
                                }

                                return DropdownButtonFormField<String>(
                                  value: _selectedBedId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Bed',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: beds.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(
                                        '${data['bedNumber']} - ${data['bedType']}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBedId = value;
                                      // Find and store the bed number
                                      final selectedBed = beds.firstWhere(
                                        (doc) => doc.id == value,
                                      );
                                      final bedData =
                                          selectedBed.data()
                                              as Map<String, dynamic>?;
                                      _selectedBedNumber =
                                          bedData?['bedNumber'];
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a bed';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Admission Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admission Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _admissionType,
                            decoration: const InputDecoration(
                              labelText: 'Admission Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'planned',
                                child: Text('Planned'),
                              ),
                              DropdownMenuItem(
                                value: 'emergency',
                                child: Text('Emergency'),
                              ),
                              DropdownMenuItem(
                                value: 'transfer',
                                child: Text('Transfer'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _admissionType = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _patientStatus,
                            decoration: const InputDecoration(
                              labelText: 'Patient Status',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'stable',
                                child: Text('Stable'),
                              ),
                              DropdownMenuItem(
                                value: 'critical',
                                child: Text('Critical'),
                              ),
                              DropdownMenuItem(
                                value: 'serious',
                                child: Text('Serious'),
                              ),
                              DropdownMenuItem(
                                value: 'fair',
                                child: Text('Fair'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _patientStatus = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _admissionDiagnosisController,
                            decoration: const InputDecoration(
                              labelText: 'Admission Diagnosis',
                              border: OutlineInputBorder(),
                              hintText: 'Primary reason for admission',
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter admission diagnosis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _expectedDurationController,
                            decoration: const InputDecoration(
                              labelText: 'Expected Duration of Stay',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., 3-5 days',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter expected duration';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _admissionNotesController,
                            decoration: const InputDecoration(
                              labelText: 'Admission Notes',
                              border: OutlineInputBorder(),
                              hintText: 'Additional notes and observations',
                            ),
                            maxLines: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _admitPatient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Admit Patient',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
