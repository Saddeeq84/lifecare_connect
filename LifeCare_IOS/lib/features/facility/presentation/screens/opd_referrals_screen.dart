import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/presentation/widgets/searchable_patient_selector.dart';

class OPDReferralsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String doctorId;
  final String doctorName;

  const OPDReferralsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.doctorId,
    required this.doctorName,
  });

  @override
  State<OPDReferralsScreen> createState() => _OPDReferralsScreenState();
}

class _OPDReferralsScreenState extends State<OPDReferralsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedSpecialistDepartment;
  String? _selectedSpecialistUnit;
  String _referralType = 'facility'; // 'facility' or 'remote'
  String? _selectedDoctorId;
  String? _selectedDoctorName;

  bool _isSubmitting = false;
  List<String> _opdPatientIds = [];
  bool _isLoadingPatients = false;

  // List of specialist departments
  final List<Map<String, dynamic>> _specialistDepartments = [
    {
      'name': 'Surgery',
      'units': [
        'General Surgery',
        'Orthopedic Surgery',
        'Neurosurgery',
        'Cardiothoracic Surgery',
        'Pediatric Surgery',
      ],
    },
    {
      'name': 'Medicine',
      'units': [
        'Internal Medicine',
        'Cardiology',
        'Nephrology',
        'Gastroenterology',
        'Endocrinology',
        'Pulmonology',
      ],
    },
    {
      'name': 'Dental',
      'units': [
        'General Dentistry',
        'Orthodontics',
        'Oral Surgery',
        'Periodontics',
        'Endodontics',
      ],
    },
    {
      'name': 'ENT (Ear, Nose & Throat)',
      'units': ['General ENT', 'Otology', 'Rhinology', 'Laryngology'],
    },
    {
      'name': 'Ophthalmology',
      'units': [
        'General Ophthalmology',
        'Retina',
        'Glaucoma',
        'Cornea',
        'Pediatric Ophthalmology',
      ],
    },
    {
      'name': 'Pediatrics',
      'units': [
        'General Pediatrics',
        'Neonatology',
        'Pediatric Cardiology',
        'Pediatric Neurology',
      ],
    },
    {
      'name': 'Obstetrics & Gynecology',
      'units': [
        'Obstetrics',
        'Gynecology',
        'Maternal-Fetal Medicine',
        'Reproductive Endocrinology',
      ],
    },
    {
      'name': 'Radiology',
      'units': [
        'Diagnostic Radiology',
        'Interventional Radiology',
        'Neuroradiology',
      ],
    },
    {
      'name': 'Pathology',
      'units': ['Clinical Pathology', 'Anatomic Pathology', 'Hematology'],
    },
    {
      'name': 'Psychiatry',
      'units': [
        'Adult Psychiatry',
        'Child & Adolescent Psychiatry',
        'Geriatric Psychiatry',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchOPDPatientIds();
  }

  Future<void> _fetchOPDPatientIds() async {
    setState(() => _isLoadingPatients = true);
    try {
      final appointmentsSnapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('facilityId', isEqualTo: widget.facilityId)
          .where('department', isEqualTo: 'Out-Patient Department (OPD)')
          .get();

      final patientIds = appointmentsSnapshot.docs
          .map((doc) => (doc.data())['patientId'] as String?)
          .where((id) => id != null)
          .map((id) => id!)
          .toSet()
          .toList();

      setState(() => _opdPatientIds = patientIds);
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isLoadingPatients = false);
    }
  }

  List<String> _getSpecialistUnits() {
    if (_selectedSpecialistDepartment == null) return [];

    final department = _specialistDepartments.firstWhere(
      (dept) => dept['name'] == _selectedSpecialistDepartment,
      orElse: () => {'units': []},
    );

    return List<String>.from(department['units'] ?? []);
  }

  Future<void> _submitReferral() async {
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

    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('referrals').add({
        'patientId': _selectedPatientId,
        'patientName': _selectedPatientName,
        'fromFacilityId': widget.facilityId,
        'fromFacilityName': widget.facilityName,
        'fromDoctorId': widget.doctorId,
        'fromDoctorName': widget.doctorName,
        'toDoctorId': _selectedDoctorId,
        'toDoctorName': _selectedDoctorName,
        'specialistDepartment': _selectedSpecialistDepartment,
        'specialistUnit': _selectedSpecialistUnit,
        'referralType': _referralType,
        'reason': _reasonController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        setState(() {
          _selectedPatientId = null;
          _selectedPatientName = null;
          _selectedSpecialistDepartment = null;
          _selectedSpecialistUnit = null;
          _selectedDoctorId = null;
          _selectedDoctorName = null;
          _referralType = 'facility';
          _reasonController.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting referral: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Referrals'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.shade700,
                      Colors.deepPurple.shade500,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.send, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Create Referral',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Refer patients to specialist departments and doctors for specialized care',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Patient Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Select Patient',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Patient Selection
                      Builder(
                        builder: (context) {
                          if (_isLoadingPatients) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          } else if (_opdPatientIds.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'No patients with OPD appointments available.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          } else {
                            return SearchablePatientSelector(
                              selectedPatientId: _selectedPatientId,
                              selectedPatientName: _selectedPatientName,
                              facilityId: widget.facilityId,
                              allowedPatientIds: _opdPatientIds,
                              hintText: 'Search patients with OPD appointments',
                              onPatientSelected: (patientId, patientName) {
                                setState(() {
                                  _selectedPatientId = patientId;
                                  _selectedPatientName = patientName;
                                });
                              },
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Specialist Department & Unit Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '2. Select Specialist Department',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Department Selection
                      DropdownButtonFormField<String>(
                        value: _selectedSpecialistDepartment,
                        decoration: const InputDecoration(
                          labelText: 'Specialist Department',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.medical_services),
                        ),
                        items: _specialistDepartments.map((dept) {
                          return DropdownMenuItem<String>(
                            value: dept['name'] as String,
                            child: Text(dept['name'] as String),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSpecialistDepartment = value;
                            _selectedSpecialistUnit =
                                null; // Reset unit when department changes
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a specialist department';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Unit Selection (enabled only after department is selected)
                      DropdownButtonFormField<String>(
                        value: _selectedSpecialistUnit,
                        decoration: InputDecoration(
                          labelText: 'Specialist Unit',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.category),
                          enabled: _selectedSpecialistDepartment != null,
                        ),
                        items: _getSpecialistUnits().map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }).toList(),
                        onChanged: _selectedSpecialistDepartment == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedSpecialistUnit = value;
                                });
                              },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a specialist unit';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Doctor Selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '3. Select Doctor Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Doctor Type Selection
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Facility Doctor'),
                              subtitle: const Text('Doctor in this facility'),
                              value: 'facility',
                              groupValue: _referralType,
                              onChanged: (value) {
                                setState(() {
                                  _referralType = value!;
                                  _selectedDoctorId = null;
                                  _selectedDoctorName = null;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Remote Doctor'),
                              subtitle: const Text('Doctor on main app'),
                              value: 'remote',
                              groupValue: _referralType,
                              onChanged: (value) {
                                setState(() {
                                  _referralType = value!;
                                  _selectedDoctorId = null;
                                  _selectedDoctorName = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Doctor Dropdown
                      if (_referralType == 'facility')
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('facility_staff')
                              .where('facilityId', isEqualTo: widget.facilityId)
                              .where('role', isEqualTo: 'doctor')
                              .where('isActive', isEqualTo: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final doctors = snapshot.data!.docs;

                            if (doctors.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'No facility doctors available',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              value: _selectedDoctorId,
                              decoration: const InputDecoration(
                                labelText: 'Select Facility Doctor',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.local_hospital),
                              ),
                              items: doctors.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(
                                    'Dr. ${data['fullName']} - ${data['specialization'] ?? 'General'}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDoctorId = value;
                                  final doctor = doctors.firstWhere(
                                    (doc) => doc.id == value,
                                  );
                                  final data =
                                      doctor.data() as Map<String, dynamic>;
                                  _selectedDoctorName =
                                      'Dr. ${data['fullName']}';
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a doctor';
                                }
                                return null;
                              },
                            );
                          },
                        )
                      else
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', isEqualTo: 'doctor')
                              .where('isApproved', isEqualTo: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final doctors = snapshot.data!.docs;

                            if (doctors.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'No remote doctors registered on the app',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Remote doctors are those registered on the LifeCare Connect app.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return DropdownButtonFormField<String>(
                              value: _selectedDoctorId,
                              decoration: const InputDecoration(
                                labelText: 'Select Remote Doctor',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.cloud),
                              ),
                              items: doctors.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(
                                    'Dr. ${data['name'] ?? data['fullName']} - ${data['specialization'] ?? 'General'}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDoctorId = value;
                                  final doctor = doctors.firstWhere(
                                    (doc) => doc.id == value,
                                  );
                                  final data =
                                      doctor.data() as Map<String, dynamic>;
                                  _selectedDoctorName =
                                      'Dr. ${data['name'] ?? data['fullName']}';
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a doctor';
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

              // Referral Details
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4. Referral Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Reason for Referral',
                          hintText: 'Enter the reason for this referral',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the reason for referral';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (Optional)',
                          hintText:
                              'Any additional information for the specialist',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReferral,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Referral',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
