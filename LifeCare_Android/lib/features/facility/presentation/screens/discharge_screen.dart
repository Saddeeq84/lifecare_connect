import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DischargeScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;

  const DischargeScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
  });

  @override
  State<DischargeScreen> createState() => _DischargeScreenState();
}

class _DischargeScreenState extends State<DischargeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _finalDiagnosisController = TextEditingController();
  final _dischargeSummaryController = TextEditingController();
  final _dischargeMedicationsController = TextEditingController();
  final _followUpInstructionsController = TextEditingController();
  final _followUpDateController = TextEditingController();

  String? _selectedAdmissionId;
  String? _selectedPatientId;
  String? _selectedBedId;
  String? _selectedWardId;
  String _dischargeType = 'normal';

  bool _isLoading = false;

  @override
  void dispose() {
    _finalDiagnosisController.dispose();
    _dischargeSummaryController.dispose();
    _dischargeMedicationsController.dispose();
    _followUpInstructionsController.dispose();
    _followUpDateController.dispose();
    super.dispose();
  }

  Future<void> _selectFollowUpDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _followUpDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _dischargePatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAdmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create discharge summary
      final dischargeData = {
        'admissionId': _selectedAdmissionId,
        'patientId': _selectedPatientId,
        'finalDiagnosis': _finalDiagnosisController.text.trim(),
        'dischargeSummary': _dischargeSummaryController.text.trim(),
        'dischargeMedications': _dischargeMedicationsController.text.trim(),
        'followUpInstructions': _followUpInstructionsController.text.trim(),
        'followUpDate': _followUpDateController.text.trim(),
        'dischargeType': _dischargeType,
        'dischargedBy': widget.staffName,
        'dischargedById': widget.staffId,
        'dischargeDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final batch = FirebaseFirestore.instance.batch();

      // Update admission record
      final admissionRef = FirebaseFirestore.instance
          .collection('admissions')
          .doc(_selectedAdmissionId);
      batch.update(admissionRef, {
        'status': 'discharged',
        'isActive': false,
        'dischargeDate': FieldValue.serverTimestamp(),
        'dischargeSummary': dischargeData,
      });

      // Save discharge summary
      final dischargeSummaryRef = FirebaseFirestore.instance
          .collection('discharge_summaries')
          .doc();
      batch.set(dischargeSummaryRef, dischargeData);

      // Update inpatients collection if exists - STOP AUTOMATIC BILLING
      final inpatientQuery = await FirebaseFirestore.instance
          .collection('inpatients')
          .where('admissionId', isEqualTo: _selectedAdmissionId)
          .limit(1)
          .get();

      if (inpatientQuery.docs.isNotEmpty) {
        final inpatientRef = inpatientQuery.docs.first.reference;

        // Mark as discharged to stop automatic daily billing
        batch.update(inpatientRef, {
          'status': 'discharged',
          'isActive': false, // Critical: stops automatic billing
          'dischargedAt': FieldValue.serverTimestamp(),
          'dischargedBy': widget.staffId,
          'dischargedByName': widget.staffName,
          'billingCycle': 'none', // Disable daily billing
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Release bed if bedId exists in inpatient record
        final inpatientData = inpatientQuery.docs.first.data();
        final bedId = inpatientData['bedId'];
        final wardId = inpatientData['wardId'];

        if (bedId != null && wardId != null) {
          final bedRef = FirebaseFirestore.instance
              .collection('facilities')
              .doc(widget.facilityId)
              .collection('wards')
              .doc(wardId)
              .collection('beds')
              .doc(bedId);
          batch.update(bedRef, {
            'status': 'available',
            'patientId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Update bed status (legacy handling)
      if (_selectedBedId != null && _selectedWardId != null) {
        final bedRef = FirebaseFirestore.instance
            .collection('facilities')
            .doc(widget.facilityId)
            .collection('wards')
            .doc(_selectedWardId)
            .collection('beds')
            .doc(_selectedBedId);
        batch.update(bedRef, {
          'status': 'available',
          'occupiedBy': null,
          'occupiedByName': null,
          'admissionId': null,
          'vacatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update patient admission status
      if (_selectedPatientId != null) {
        final patientRef = FirebaseFirestore.instance
            .collection('facility_patients')
            .doc(_selectedPatientId);
        batch.update(patientRef, {
          'isAdmitted': false,
          'currentAdmissionId': null,
          'dischargeDate': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient discharged successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error discharging patient: $e'),
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
        title: const Text('Discharge Patient'),
        backgroundColor: Colors.orange,
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
                            'Select Patient to Discharge',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('admissions')
                                .where(
                                  'facilityId',
                                  isEqualTo: widget.facilityId,
                                )
                                .where('status', isEqualTo: 'admitted')
                                .where('isActive', isEqualTo: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const CircularProgressIndicator();
                              }

                              final admissions = snapshot.data!.docs;

                              if (admissions.isEmpty) {
                                return const Text(
                                  'No admitted patients',
                                  style: TextStyle(color: Colors.red),
                                );
                              }

                              return DropdownButtonFormField<String>(
                                value: _selectedAdmissionId,
                                decoration: const InputDecoration(
                                  labelText: 'Patient',
                                  border: OutlineInputBorder(),
                                ),
                                items: admissions.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(
                                      '${data['patientName']} - ${data['admissionDiagnosis']}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedAdmissionId = value;
                                    final admission = admissions.firstWhere(
                                      (doc) => doc.id == value,
                                    );
                                    final data =
                                        admission.data()
                                            as Map<String, dynamic>;
                                    _selectedPatientId = data['patientId'];
                                    _selectedBedId = data['bedId'];
                                    _selectedWardId = data['wardId'];
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a patient';
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

                  // Discharge Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Discharge Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _dischargeType,
                            decoration: const InputDecoration(
                              labelText: 'Discharge Type',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'normal',
                                child: Text('Normal Discharge'),
                              ),
                              DropdownMenuItem(
                                value: 'against_advice',
                                child: Text('Against Medical Advice (AMA)'),
                              ),
                              DropdownMenuItem(
                                value: 'transfer',
                                child: Text('Transfer to Another Facility'),
                              ),
                              DropdownMenuItem(
                                value: 'absconded',
                                child: Text('Absconded'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _dischargeType = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _finalDiagnosisController,
                            decoration: const InputDecoration(
                              labelText: 'Final Diagnosis',
                              border: OutlineInputBorder(),
                              hintText: 'Confirmed diagnosis at discharge',
                            ),
                            maxLines: 2,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter final diagnosis';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dischargeSummaryController,
                            decoration: const InputDecoration(
                              labelText: 'Discharge Summary',
                              border: OutlineInputBorder(),
                              hintText:
                                  'Summary of hospital stay, treatments, etc.',
                            ),
                            maxLines: 6,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter discharge summary';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dischargeMedicationsController,
                            decoration: const InputDecoration(
                              labelText: 'Discharge Medications',
                              border: OutlineInputBorder(),
                              hintText: 'Medications to continue at home',
                            ),
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter discharge medications';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _followUpInstructionsController,
                            decoration: const InputDecoration(
                              labelText: 'Follow-up Instructions',
                              border: OutlineInputBorder(),
                              hintText:
                                  'Instructions for home care and follow-up',
                            ),
                            maxLines: 4,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter follow-up instructions';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _followUpDateController,
                            decoration: InputDecoration(
                              labelText: 'Follow-up Date',
                              border: const OutlineInputBorder(),
                              hintText: 'Select follow-up date',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectFollowUpDate,
                              ),
                            ),
                            readOnly: true,
                            onTap: _selectFollowUpDate,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please select follow-up date';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Discharge Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _dischargePatient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Discharge Patient',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
