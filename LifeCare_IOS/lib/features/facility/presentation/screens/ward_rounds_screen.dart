import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/ai_validation_service.dart';
import '../../../shared/widgets/ai_validation_dialog.dart';

class WardRoundsScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final bool excludeEmergencyAdmissions;
  final bool filterByEmergency;

  const WardRoundsScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.excludeEmergencyAdmissions = false,
    this.filterByEmergency = false,
  });

  @override
  State<WardRoundsScreen> createState() => _WardRoundsScreenState();
}

class _WardRoundsScreenState extends State<WardRoundsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _progressNotesController = TextEditingController();
  final _treatmentPlanController = TextEditingController();

  String? _selectedAdmissionId;
  String? _selectedPatientId;
  String? _selectedPatientName;
  String _patientCondition = 'improving';

  bool _isLoading = false;

  // Prescription management
  final List<Map<String, dynamic>> _prescriptions = [];
  final List<String> _labTests = [];
  final List<String> _imagingRequests = [];

  // Load from Firestore instead of hardcoded
  List<Map<String, dynamic>> _availableLabTests = [];
  List<Map<String, dynamic>> _availableImaging = [];

  @override
  void initState() {
    super.initState();
    _loadServicesFromFirestore();
  }

  Future<void> _loadServicesFromFirestore() async {
    try {
      // Load service prices from facility_service_prices collection
      final servicePricesDoc = await FirebaseFirestore.instance
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .get();

      if (!servicePricesDoc.exists) {
        debugPrint(
          '❌ No service prices found for facility ${widget.facilityId}',
        );
        _setDefaultServices();
        return;
      }

      final servicePrices = servicePricesDoc.data() as Map<String, dynamic>;

      // Laboratory Services - extract from service_management categories
      final List<Map<String, dynamic>> labTests = [];

      // Lab service IDs from service_management 'Laboratory Services' category
      final labServiceIds = [
        'blood_test_basic',
        'blood_test_full',
        'malaria_test',
        'typhoid_test',
        'hiv_test',
        'hepatitis_test',
        'pregnancy_test',
        'urine_test',
        'stool_test',
        'blood_sugar',
        'cholesterol_test',
        'liver_function',
        'kidney_function',
        'ecg',
      ];

      // Imaging/Radiology service IDs from service_management 'Laboratory Services' category
      final radiologyServiceIds = ['xray_chest', 'xray_other', 'ultrasound'];

      // Map of service IDs to display names (from service_management)
      final serviceNames = {
        'blood_test_basic': 'Basic Blood Test',
        'blood_test_full': 'Full Blood Count (FBC)',
        'malaria_test': 'Malaria Test',
        'typhoid_test': 'Typhoid Test',
        'hiv_test': 'HIV Screening',
        'hepatitis_test': 'Hepatitis B/C Test',
        'pregnancy_test': 'Pregnancy Test',
        'urine_test': 'Urinalysis',
        'stool_test': 'Stool Analysis',
        'blood_sugar': 'Blood Sugar (Glucose)',
        'cholesterol_test': 'Cholesterol Test',
        'liver_function': 'Liver Function Test',
        'kidney_function': 'Kidney Function Test',
        'xray_chest': 'X-Ray (Chest)',
        'xray_other': 'X-Ray (Other)',
        'ultrasound': 'Ultrasound Scan',
        'ecg': 'ECG/EKG',
      };

      // Extract lab tests
      for (var serviceId in labServiceIds) {
        if (servicePrices.containsKey(serviceId)) {
          final price = (servicePrices[serviceId] as num?)?.toDouble() ?? 0.0;
          final name = serviceNames[serviceId] ?? serviceId;
          labTests.add({'name': name, 'cost': price});
        }
      }

      // Extract imaging/radiology services
      final List<Map<String, dynamic>> imaging = [];
      for (var serviceId in radiologyServiceIds) {
        if (servicePrices.containsKey(serviceId)) {
          final price = (servicePrices[serviceId] as num?)?.toDouble() ?? 0.0;
          final name = serviceNames[serviceId] ?? serviceId;
          imaging.add({'name': name, 'cost': price});
        }
      }

      setState(() {
        _availableLabTests = labTests;
        _availableImaging = imaging;
      });
    } catch (e) {
      print('Error loading services: $e');
      // Fallback to default values if loading fails
      _setDefaultServices();
    }
  }

  void _setDefaultServices() {
    setState(() {
      _availableLabTests = [
        {'name': 'Full Blood Count (FBC)', 'cost': 3000.0},
        {'name': 'Malaria Parasite (MP)', 'cost': 1500.0},
        {'name': 'Blood Sugar (Random)', 'cost': 1000.0},
        {'name': 'Blood Sugar (Fasting)', 'cost': 1200.0},
        {'name': 'Lipid Profile', 'cost': 5000.0},
        {'name': 'Liver Function Test (LFT)', 'cost': 6000.0},
        {'name': 'Kidney Function Test (RFT)', 'cost': 6000.0},
        {'name': 'Urinalysis', 'cost': 1500.0},
        {'name': 'Urine Microscopy', 'cost': 2000.0},
        {'name': 'Stool Examination', 'cost': 2000.0},
        {'name': 'Pregnancy Test', 'cost': 1000.0},
        {'name': 'HIV Screening', 'cost': 3000.0},
        {'name': 'Hepatitis B Surface Antigen (HBsAg)', 'cost': 3500.0},
        {'name': 'Hepatitis C Antibody', 'cost': 4000.0},
        {'name': 'Widal Test (Typhoid)', 'cost': 2500.0},
        {'name': 'Blood Culture', 'cost': 8000.0},
        {'name': 'Sputum for AFB (TB)', 'cost': 3000.0},
        {'name': 'Electrolytes, Urea & Creatinine (E/U/Cr)', 'cost': 7000.0},
        {'name': 'Thyroid Function Test', 'cost': 8000.0},
      ];

      _availableImaging = [
        {'name': 'Chest X-Ray', 'cost': 5000.0},
        {'name': 'Abdominal X-Ray', 'cost': 5000.0},
        {'name': 'Pelvic X-Ray', 'cost': 5000.0},
        {'name': 'Skull X-Ray', 'cost': 5000.0},
        {'name': 'Abdominal Ultrasound', 'cost': 8000.0},
        {'name': 'Pelvic Ultrasound', 'cost': 8000.0},
        {'name': 'Obstetric Ultrasound', 'cost': 10000.0},
        {'name': 'Breast Ultrasound', 'cost': 8000.0},
        {'name': 'CT Scan (Head)', 'cost': 35000.0},
        {'name': 'CT Scan (Chest)', 'cost': 40000.0},
        {'name': 'CT Scan (Abdomen)', 'cost': 40000.0},
        {'name': 'MRI Scan', 'cost': 60000.0},
        {'name': 'Echocardiography', 'cost': 15000.0},
      ];
    });
  }

  final List<Map<String, String>> _medications = [
    {'name': 'Paracetamol', 'strength': '500mg'},
    {'name': 'Paracetamol', 'strength': '1000mg'},
    {'name': 'Ibuprofen', 'strength': '400mg'},
    {'name': 'Ibuprofen', 'strength': '600mg'},
    {'name': 'Amoxicillin', 'strength': '500mg'},
    {'name': 'Amoxicillin', 'strength': '1g'},
    {'name': 'Ciprofloxacin', 'strength': '500mg'},
    {'name': 'Metronidazole', 'strength': '400mg'},
    {'name': 'Artemether-Lumefantrine (Coartem)', 'strength': '20/120mg'},
    {'name': 'Artesunate', 'strength': '50mg'},
    {'name': 'Quinine', 'strength': '300mg'},
    {'name': 'Chloroquine', 'strength': '250mg'},
    {'name': 'Vitamin B Complex', 'strength': 'Standard'},
    {'name': 'Multivitamin', 'strength': 'Standard'},
    {'name': 'Ferrous Sulphate', 'strength': '200mg'},
    {'name': 'Folic Acid', 'strength': '5mg'},
    {'name': 'Omeprazole', 'strength': '20mg'},
    {'name': 'Ranitidine', 'strength': '150mg'},
    {'name': 'Diclofenac', 'strength': '50mg'},
    {'name': 'Prednisolone', 'strength': '5mg'},
    {'name': 'Salbutamol Inhaler', 'strength': '100mcg'},
    {'name': 'Hydrocortisone Cream', 'strength': '1%'},
    {'name': 'Gentamycin Eye Drops', 'strength': '0.3%'},
    {'name': 'Tetracycline Eye Ointment', 'strength': '1%'},
    {'name': 'Nifedipine', 'strength': '20mg'},
    {'name': 'Enalapril', 'strength': '5mg'},
    {'name': 'Atenolol', 'strength': '50mg'},
    {'name': 'Metformin', 'strength': '500mg'},
    {'name': 'Glibenclamide', 'strength': '5mg'},
    {'name': 'Insulin (Actrapid)', 'strength': '100IU/ml'},
    {'name': 'Oral Rehydration Salt (ORS)', 'strength': 'Sachet'},
    {'name': 'Zinc Sulphate', 'strength': '20mg'},
    {'name': 'Albendazole', 'strength': '400mg'},
    {'name': 'Mebendazole', 'strength': '100mg'},
    {'name': 'Praziquantel', 'strength': '600mg'},
    {'name': 'Cotrimoxazole', 'strength': '480mg'},
    {'name': 'Doxycycline', 'strength': '100mg'},
    {'name': 'Erythromycin', 'strength': '250mg'},
    {'name': 'Ceftriaxone Injection', 'strength': '1g'},
    {'name': 'Benzathine Penicillin', 'strength': '2.4MU'},
  ];

  @override
  void dispose() {
    _progressNotesController.dispose();
    _treatmentPlanController.dispose();
    super.dispose();
  }

  Future<void> _saveWardRound() async {
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
      // Save ward round notes
      await FirebaseFirestore.instance
          .collection('admissions')
          .doc(_selectedAdmissionId)
          .collection('ward_rounds')
          .add({
            'progressNotes': _progressNotesController.text.trim(),
            'treatmentPlan': _treatmentPlanController.text.trim(),
            'prescriptions': _prescriptions,
            'labTests': _labTests,
            'imagingRequests': _imagingRequests,
            'patientCondition': _patientCondition,
            'doctorId': widget.staffId,
            'doctorName': widget.staffName,
            'roundDate': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Create pending prescriptions for pharmacy (if any)
      if (_prescriptions.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .add({
              'admissionId': _selectedAdmissionId,
              'patientId': _selectedPatientId,
              'patientName': _selectedPatientName,
              'facilityId': widget.facilityId,
              'prescriptions': _prescriptions,
              'clinicianName': widget.staffName,
              'source': 'ward_round', // Indicate source
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'pending',
            });
      }

      // Create pending lab tests (if any)
      for (var test in _labTests) {
        final testData = _availableLabTests.firstWhere(
          (t) => t['name'] == test,
        );
        await FirebaseFirestore.instance.collection('pending_lab_tests').add({
          'admissionId': _selectedAdmissionId,
          'patientId': _selectedPatientId,
          'patientName': _selectedPatientName,
          'facilityId': widget.facilityId,
          'testName': test,
          'cost': testData['cost'],
          'clinicianName': widget.staffName,
          'source': 'ward_round', // Indicate source
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      // Create pending imaging requests (if any)
      for (var imaging in _imagingRequests) {
        final imagingData = _availableImaging.firstWhere(
          (i) => i['name'] == imaging,
        );
        await FirebaseFirestore.instance.collection('pending_imaging').add({
          'admissionId': _selectedAdmissionId,
          'patientId': _selectedPatientId,
          'patientName': _selectedPatientName,
          'facilityId': widget.facilityId,
          'imagingType': imaging,
          'cost': imagingData['cost'],
          'clinicianName': widget.staffName,
          'source': 'ward_round', // Indicate source
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ward round notes saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _progressNotesController.clear();
        _treatmentPlanController.clear();
        setState(() {
          _selectedAdmissionId = null;
          _selectedPatientId = null;
          _selectedPatientName = null;
          _patientCondition = 'improving';
          _prescriptions.clear();
          _labTests.clear();
          _imagingRequests.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving ward round: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addPrescription() {
    showDialog(
      context: context,
      builder: (context) => _PrescriptionDialog(
        medications: _medications,
        onAdd: (prescription) {
          setState(() {
            _prescriptions.add(prescription);
          });
        },
      ),
    );
  }

  void _addLabTest() {
    showDialog(
      context: context,
      builder: (context) => _LabTestDialog(
        availableTests: _availableLabTests,
        selectedTests: _labTests,
        onAdd: (testName) {
          setState(() {
            if (!_labTests.contains(testName)) {
              _labTests.add(testName);
            }
          });
        },
      ),
    );
  }

  void _addImagingRequest() {
    showDialog(
      context: context,
      builder: (context) => _ImagingDialog(
        availableImaging: _availableImaging,
        selectedImaging: _imagingRequests,
        onAdd: (imagingName) {
          setState(() {
            if (!_imagingRequests.contains(imagingName)) {
              _imagingRequests.add(imagingName);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ward Rounds'),
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
                            'Select Patient',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: widget.filterByEmergency
                                ? FirebaseFirestore.instance
                                      .collection('admissions')
                                      .where(
                                        'facilityId',
                                        isEqualTo: widget.facilityId,
                                      )
                                      .where('status', isEqualTo: 'admitted')
                                      .where('isActive', isEqualTo: true)
                                      .where(
                                        'admissionType',
                                        isEqualTo: 'emergency',
                                      )
                                      .snapshots()
                                : widget.excludeEmergencyAdmissions
                                ? FirebaseFirestore.instance
                                      .collection('admissions')
                                      .where(
                                        'facilityId',
                                        isEqualTo: widget.facilityId,
                                      )
                                      .where('status', isEqualTo: 'admitted')
                                      .where('isActive', isEqualTo: true)
                                      .where(
                                        'admissionType',
                                        isNotEqualTo: 'emergency',
                                      )
                                      .snapshots()
                                : FirebaseFirestore.instance
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
                                      '${data['patientName']} - ${data['admissionDiagnosis'] ?? 'N/A'}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  final selectedDoc = admissions.firstWhere(
                                    (doc) => doc.id == value,
                                  );
                                  final data =
                                      selectedDoc.data()
                                          as Map<String, dynamic>;
                                  setState(() {
                                    _selectedAdmissionId = value;
                                    _selectedPatientId = data['patientId'];
                                    _selectedPatientName = data['patientName'];
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

                  // Ward Round Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ward Round Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _patientCondition,
                            decoration: const InputDecoration(
                              labelText: 'Patient Condition',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'improving',
                                child: Text('Improving'),
                              ),
                              DropdownMenuItem(
                                value: 'stable',
                                child: Text('Stable'),
                              ),
                              DropdownMenuItem(
                                value: 'deteriorating',
                                child: Text('Deteriorating'),
                              ),
                              DropdownMenuItem(
                                value: 'critical',
                                child: Text('Critical'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _patientCondition = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _progressNotesController,
                            decoration: const InputDecoration(
                              labelText: 'Progress Notes',
                              border: OutlineInputBorder(),
                              hintText: 'Document patient progress...',
                            ),
                            maxLines: 5,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter progress notes';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _treatmentPlanController,
                            decoration: const InputDecoration(
                              labelText: 'Treatment Plan (Optional Notes)',
                              border: OutlineInputBorder(),
                              hintText: 'Additional treatment instructions...',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Prescriptions Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Medications Prescribed',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addPrescription,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_prescriptions.isEmpty)
                            const Text(
                              'No medications prescribed yet',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _prescriptions.length,
                              itemBuilder: (context, index) {
                                final rx = _prescriptions[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      '${rx['medication']} ${rx['strength']}',
                                    ),
                                    subtitle: Text(
                                      '${rx['dosage']} - ${rx['frequency']} for ${rx['duration']}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
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
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lab Tests Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Laboratory Tests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addLabTest,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_labTests.isEmpty)
                            const Text(
                              'No lab tests requested yet',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _labTests.length,
                              itemBuilder: (context, index) {
                                final testName = _labTests[index];
                                final testData = _availableLabTests.firstWhere(
                                  (t) => t['name'] == testName,
                                  orElse: () => {'name': testName, 'cost': 0},
                                );
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.biotech,
                                      color: Colors.green,
                                    ),
                                    title: Text(testName),
                                    subtitle: Text(
                                      'Cost: ₦${testData['cost']}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _labTests.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Imaging Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Imaging Requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _addImagingRequest,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_imagingRequests.isEmpty)
                            const Text(
                              'No imaging requested yet',
                              style: TextStyle(color: Colors.grey),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _imagingRequests.length,
                              itemBuilder: (context, index) {
                                final imagingName = _imagingRequests[index];
                                final imagingData = _availableImaging
                                    .firstWhere(
                                      (i) => i['name'] == imagingName,
                                      orElse: () => {
                                        'name': imagingName,
                                        'cost': 0,
                                      },
                                    );
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.medical_services,
                                      color: Colors.orange,
                                    ),
                                    title: Text(imagingName),
                                    subtitle: Text(
                                      'Cost: ₦${imagingData['cost']}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _imagingRequests.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveWardRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Save Ward Round',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Previous Ward Rounds
                  if (_selectedAdmissionId != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Previous Ward Rounds',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('admissions')
                                  .doc(_selectedAdmissionId)
                                  .collection('ward_rounds')
                                  .orderBy('roundDate', descending: true)
                                  .limit(5)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final rounds = snapshot.data!.docs;

                                if (rounds.isEmpty) {
                                  return const Text('No previous ward rounds');
                                }

                                return Column(
                                  children: rounds.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final roundDate =
                                        data['roundDate'] as Timestamp?;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ExpansionTile(
                                        title: Text(
                                          'Dr. ${data['doctorName']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          roundDate != null
                                              ? DateFormat(
                                                  'MMM dd, yyyy HH:mm',
                                                ).format(roundDate.toDate())
                                              : 'N/A',
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildRoundDetail(
                                                  'Condition',
                                                  (data['patientCondition'] ??
                                                          'N/A')
                                                      .toString()
                                                      .toUpperCase(),
                                                ),
                                                _buildRoundDetail(
                                                  'Progress Notes',
                                                  data['progressNotes'] ??
                                                      'N/A',
                                                ),
                                                _buildRoundDetail(
                                                  'Treatment Plan',
                                                  data['treatmentPlan'] ??
                                                      'N/A',
                                                ),
                                                if (data['investigations'] !=
                                                        null &&
                                                    data['investigations']
                                                        .toString()
                                                        .isNotEmpty)
                                                  _buildRoundDetail(
                                                    'Investigations',
                                                    data['investigations'],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildRoundDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ==================== PRESCRIPTION DIALOG ====================
class _PrescriptionDialog extends StatefulWidget {
  final List<Map<String, String>> medications;
  final Function(Map<String, dynamic>) onAdd;

  const _PrescriptionDialog({required this.medications, required this.onAdd});

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMedication;
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  ValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    _dosageController.addListener(_validatePrescription);
    _frequencyController.addListener(_validatePrescription);
  }

  @override
  void dispose() {
    _dosageController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _validatePrescription() async {
    if (_selectedMedication == null || _dosageController.text.trim().isEmpty) {
      setState(() => _validationResult = null);
      return;
    }

    final result = await AIValidationService.validatePrescription(
      medicationName: _selectedMedication!,
      dosage: _dosageController.text.trim(),
      frequency: _frequencyController.text.trim(),
      route: 'Oral',
    );

    setState(() => _validationResult = result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Prescription'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Medication Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Medication',
                  border: OutlineInputBorder(),
                ),
                items: widget.medications.map((med) {
                  final fullName = '${med['name']} ${med['strength']}';
                  return DropdownMenuItem(
                    value: fullName,
                    child: Text(fullName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMedication = value;
                  });
                },
                validator: (value) {
                  if (value == null) return 'Please select medication';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (e.g., 1 tablet, 5ml)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter dosage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _frequencyController,
                decoration: const InputDecoration(
                  labelText: 'Frequency (e.g., Twice daily, TDS)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter frequency';
                  }
                  return null;
                },
              ),
              // AI Validation Inline Display
              if (_validationResult != null)
                InlineValidationWidget(result: _validationResult!),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (e.g., 7 days, 2 weeks)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter duration';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              // AI Validation Advisory before adding prescription
              if (_validationResult != null &&
                  (_validationResult!.severity == ValidationSeverity.critical ||
                      _validationResult!.severity ==
                          ValidationSeverity.warning)) {
                await AIValidationDialog.show(
                  context: context,
                  result: _validationResult!,
                  title: 'AI Prescription Advisory',
                );
              }

              final parts = _selectedMedication!.split(' ');
              final strength = parts.last;
              final medication = parts.sublist(0, parts.length - 1).join(' ');

              widget.onAdd({
                'medication': medication,
                'strength': strength,
                'dosage': _dosageController.text.trim(),
                'frequency': _frequencyController.text.trim(),
                'duration': _durationController.text.trim(),
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ==================== LAB TEST DIALOG ====================
class _LabTestDialog extends StatelessWidget {
  final List<Map<String, dynamic>> availableTests;
  final List<String> selectedTests;
  final Function(String) onAdd;

  const _LabTestDialog({
    required this.availableTests,
    required this.selectedTests,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Laboratory Test'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: availableTests.length,
          itemBuilder: (context, index) {
            final test = availableTests[index];
            final testName = test['name'] as String;
            final isAlreadySelected = selectedTests.contains(testName);

            return ListTile(
              leading: Icon(
                Icons.biotech,
                color: isAlreadySelected ? Colors.grey : Colors.green,
              ),
              title: Text(
                testName,
                style: TextStyle(
                  color: isAlreadySelected ? Colors.grey : Colors.black,
                  fontWeight: isAlreadySelected
                      ? FontWeight.normal
                      : FontWeight.w500,
                ),
              ),
              subtitle: Text('Cost: ₦${test['cost']}'),
              trailing: isAlreadySelected
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              enabled: !isAlreadySelected,
              onTap: isAlreadySelected
                  ? null
                  : () {
                      onAdd(testName);
                      Navigator.pop(context);
                    },
            );
          },
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
}

// ==================== IMAGING DIALOG ====================
class _ImagingDialog extends StatelessWidget {
  final List<Map<String, dynamic>> availableImaging;
  final List<String> selectedImaging;
  final Function(String) onAdd;

  const _ImagingDialog({
    required this.availableImaging,
    required this.selectedImaging,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Imaging Request'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: availableImaging.length,
          itemBuilder: (context, index) {
            final imaging = availableImaging[index];
            final imagingName = imaging['name'] as String;
            final isAlreadySelected = selectedImaging.contains(imagingName);

            return ListTile(
              leading: Icon(
                Icons.medical_services,
                color: isAlreadySelected ? Colors.grey : Colors.orange,
              ),
              title: Text(
                imagingName,
                style: TextStyle(
                  color: isAlreadySelected ? Colors.grey : Colors.black,
                  fontWeight: isAlreadySelected
                      ? FontWeight.normal
                      : FontWeight.w500,
                ),
              ),
              subtitle: Text('Cost: ₦${imaging['cost']}'),
              trailing: isAlreadySelected
                  ? const Icon(Icons.check_circle, color: Colors.orange)
                  : null,
              enabled: !isAlreadySelected,
              onTap: isAlreadySelected
                  ? null
                  : () {
                      onAdd(imagingName);
                      Navigator.pop(context);
                    },
            );
          },
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
}
