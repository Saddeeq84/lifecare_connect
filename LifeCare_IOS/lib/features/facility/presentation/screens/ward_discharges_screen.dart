import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class WardDischargesScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;
  final String staffId;
  final String staffName;
  final bool excludeEmergencyAdmissions;
  final bool filterByEmergency;

  const WardDischargesScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
    required this.staffId,
    required this.staffName,
    this.excludeEmergencyAdmissions = false,
    this.filterByEmergency = false,
  });

  @override
  State<WardDischargesScreen> createState() => _WardDischargesScreenState();
}

class _WardDischargesScreenState extends State<WardDischargesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dischargeSummaryController = TextEditingController();
  final _followUpInstructionsController = TextEditingController();

  String? _selectedAdmissionId;
  String _dischargeType = 'improved';
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;

  // Medications and lab tests lists (same as consultation screen)
  final List<Map<String, dynamic>> _dischargeMedications = [];
  final List<Map<String, dynamic>> _dischargeLabTests = [];
  List<Map<String, dynamic>> _availableLabTests = [];

  // Nigerian/African Medicine Formulary
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
  void initState() {
    super.initState();
    _loadLabTests();
  }

  @override
  void dispose() {
    _dischargeSummaryController.dispose();
    _followUpInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadLabTests() async {
    try {
      // Load service prices from facility_service_prices collection
      final servicePricesDoc = await FirebaseFirestore.instance
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .get();

      if (!servicePricesDoc.exists) {
        return;
      }

      final servicePrices = servicePricesDoc.data() as Map<String, dynamic>;

      // Laboratory Services
      final List<Map<String, dynamic>> labTests = [];

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
      };

      for (var serviceId in labServiceIds) {
        if (servicePrices.containsKey(serviceId)) {
          labTests.add({
            'name': serviceNames[serviceId] ?? serviceId,
            'cost': (servicePrices[serviceId] as num?)?.toDouble() ?? 0.0,
          });
        }
      }

      setState(() {
        _availableLabTests = labTests;
      });
    } catch (e) {
      debugPrint('Error loading lab tests: $e');
    }
  }

  void _addDischargeMedication() {
    showDialog(
      context: context,
      builder: (context) => _PrescriptionDialog(
        medications: _medications,
        onAdd: (prescription) {
          setState(() {
            _dischargeMedications.add(prescription);
          });
        },
      ),
    );
  }

  void _addDischargeLabTest() {
    if (_availableLabTests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No lab tests available. Please configure service prices first.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _SelectionDialog(
        title: 'Select Lab Test',
        items: _availableLabTests,
        selectedItems: _dischargeLabTests
            .map((t) => t['testName'] as String)
            .toList(),
        onSelect: (testName) {
          final alreadyAdded = _dischargeLabTests.any(
            (t) => t['testName'] == testName,
          );
          if (!alreadyAdded) {
            final testData = _availableLabTests.firstWhere(
              (t) => t['name'] == testName,
              orElse: () => {'name': testName, 'cost': 0.0},
            );
            setState(() {
              _dischargeLabTests.add({
                'testName': testData['name'],
                'cost': testData['cost'],
              });
            });
          }
        },
      ),
    );
  }

  double _calculateDischargeCosts() {
    double total = 0.0;

    // Add lab test costs
    for (var test in _dischargeLabTests) {
      total += (test['cost'] as num).toDouble();
    }

    return total;
  }

  Future<void> _dischargePatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAdmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient to discharge'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Calculate total discharge costs (lab tests)
      final dischargeCosts = _calculateDischargeCosts();

      // Get admission document to find patient details
      final admissionDoc = await FirebaseFirestore.instance
          .collection('admissions')
          .doc(_selectedAdmissionId)
          .get();

      if (!admissionDoc.exists) {
        throw Exception('Admission record not found');
      }

      final admissionData = admissionDoc.data() as Map<String, dynamic>;
      final patientId = admissionData['patientId'] as String;
      final patientName = admissionData['patientName'] as String;

      print('🚀 DISCHARGE PROCESS STARTED');
      print('   Admission ID: $_selectedAdmissionId');
      print('   Patient: $patientName');
      print('   Discharge Type: $_dischargeType');

      // If there are discharge costs, deduct from patient wallet
      if (dischargeCosts > 0) {
        // Get patient document to check wallet
        final patientDoc = await FirebaseFirestore.instance
            .collection('facility_patients')
            .doc(patientId)
            .get();

        if (patientDoc.exists) {
          final patientData = patientDoc.data();
          final registrationType = patientData?['registrationType'] as String?;

          double walletBalance = 0.0;
          String? householdId;
          bool useHouseholdWallet = false;

          if (registrationType == 'household') {
            useHouseholdWallet = true;
            householdId = patientData?['householdId'] as String?;

            if (householdId == null || householdId.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Patient not assigned to a household.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              setState(() => _isLoading = false);
              return;
            }

            final householdDoc = await FirebaseFirestore.instance
                .collection('household_wallets')
                .doc(householdId)
                .get();

            if (householdDoc.exists && householdDoc.data() != null) {
              walletBalance =
                  (householdDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
            }
          } else {
            walletBalance =
                (patientData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
          }

          // Check sufficient balance
          if (walletBalance < dischargeCosts) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Insufficient wallet balance. Discharge costs: ₦${dischargeCosts.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }

          // Deduct from appropriate wallet
          if (useHouseholdWallet && householdId != null) {
            await FirebaseFirestore.instance
                .collection('household_wallets')
                .doc(householdId)
                .update({'balance': FieldValue.increment(-dischargeCosts)});

            await FirebaseFirestore.instance
                .collection('household_wallets')
                .doc(householdId)
                .collection('transactions')
                .add({
                  'type': 'debit',
                  'amount': dischargeCosts,
                  'description': 'Discharge lab tests for $patientName',
                  'patientId': patientId,
                  'patientName': patientName,
                  'timestamp': FieldValue.serverTimestamp(),
                });
          } else {
            await FirebaseFirestore.instance
                .collection('facility_patients')
                .doc(patientId)
                .update({
                  'walletBalance': FieldValue.increment(-dischargeCosts),
                });

            await FirebaseFirestore.instance
                .collection('facility_patients')
                .doc(patientId)
                .collection('transactions')
                .add({
                  'type': 'debit',
                  'amount': dischargeCosts,
                  'description': 'Discharge lab tests',
                  'timestamp': FieldValue.serverTimestamp(),
                });
          }

          // Credit facility wallet
          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(widget.facilityId)
              .update({
                'balance': FieldValue.increment(dischargeCosts),
                'updatedAt': FieldValue.serverTimestamp(),
              });

          await FirebaseFirestore.instance
              .collection('wallets')
              .doc(widget.facilityId)
              .collection('transactions')
              .add({
                'type': 'credit',
                'amount': dischargeCosts,
                'description': 'Discharge lab tests from $patientName',
                'patientId': patientId,
                'patientName': patientName,
                'timestamp': FieldValue.serverTimestamp(),
                'status': 'completed',
              });
        }
      }

      final batch = FirebaseFirestore.instance.batch();

      // Update admission record
      final admissionRef = FirebaseFirestore.instance
          .collection('admissions')
          .doc(_selectedAdmissionId);
      batch.update(admissionRef, {
        'status': 'discharged',
        'dischargedBy': widget.staffId,
        'dischargedByName': widget.staffName,
        'dischargeDate': Timestamp.fromDate(_selectedDate),
        'dischargeType': _dischargeType,
        'dischargeSummary': _dischargeSummaryController.text.trim(),
        'dischargeMedications': _dischargeMedications,
        'dischargeLabTests': _dischargeLabTests,
        'dischargeCosts': dischargeCosts,
        'followUpInstructions': _followUpInstructionsController.text.trim(),
        'chargesStopped': true, // Stop automated daily billing
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark linked appointment as completed (moves to history)
      String? appointmentId = admissionData['appointmentId'] as String?;
      print('📋 Appointment ID from admission: $appointmentId');

      // If no appointmentId in admission, search for appointment by admissionId
      if (appointmentId == null || appointmentId.isEmpty) {
        print('🔍 Searching for appointment by admissionId...');
        final appointmentQuery = await FirebaseFirestore.instance
            .collection('appointments')
            .where('admissionId', isEqualTo: _selectedAdmissionId)
            .limit(1)
            .get();

        if (appointmentQuery.docs.isNotEmpty) {
          appointmentId = appointmentQuery.docs.first.id;
          print('✅ Found appointment: $appointmentId');
        } else {
          print(
            '⚠️ WARNING: No appointment found with admissionId: $_selectedAdmissionId',
          );
        }
      }

      // Update inpatients collection and get bed info for release
      final inpatientQuery = await FirebaseFirestore.instance
          .collection('inpatients')
          .where('appointmentId', isEqualTo: _selectedAdmissionId)
          .limit(1)
          .get();

      String? bedIdToRelease;
      String? wardIdToRelease;
      String? appointmentIdToUpdate;

      if (inpatientQuery.docs.isNotEmpty) {
        final inpatientRef = inpatientQuery.docs.first.reference;
        final inpatientData = inpatientQuery.docs.first.data();

        // Get bed info from inpatient record
        bedIdToRelease = inpatientData['bedId'];
        wardIdToRelease = inpatientData['wardId'];
        print(
          '🛏️ Got bed info from inpatient: bedId=$bedIdToRelease, wardId=$wardIdToRelease',
        );

        // Update inpatient record to discharged status (DO NOT DELETE - needed for analytics)
        batch.update(inpatientRef, {
          'status': 'discharged',
          'isActive': false,
          'dischargedAt': FieldValue.serverTimestamp(),
          'dischargeDate': Timestamp.fromDate(_selectedDate),
          'dischargedBy': widget.staffId,
          'dischargedByName': widget.staffName,
          'billingCycle': 'none', // Stop automatic billing
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Inpatient record updated to discharged status');
      } else {
        print(
          '⚠️ WARNING: No inpatient record found for admission $_selectedAdmissionId',
        );
      }

      // Fallback: If no bed info from inpatient, try to get from admission record
      if (bedIdToRelease == null || wardIdToRelease == null) {
        bedIdToRelease = bedIdToRelease ?? admissionData['bedId'];
        wardIdToRelease = wardIdToRelease ?? admissionData['wardId'];
        print(
          '📋 Got bed info from admission: bedId=$bedIdToRelease, wardId=$wardIdToRelease',
        );
      }

      // Get appointment ID to update AFTER batch commit
      appointmentIdToUpdate = admissionData['appointmentId'] as String?;
      print('📋 Appointment ID from admission: $appointmentIdToUpdate');

      // If no appointmentId in admission, search for appointment by patientId and status
      if (appointmentIdToUpdate == null || appointmentIdToUpdate.isEmpty) {
        print(
          '🔍 Searching for appointment by patientId and status=admitted...',
        );
        final appointmentQuery = await FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: patientId)
            .where('facilityId', isEqualTo: widget.facilityId)
            .where('status', isEqualTo: 'admitted')
            .limit(1)
            .get();

        if (appointmentQuery.docs.isNotEmpty) {
          appointmentIdToUpdate = appointmentQuery.docs.first.id;
          print('✅ Found appointment: $appointmentIdToUpdate');
        } else {
          print(
            '⚠️ WARNING: No appointment found for patient $patientId with status=admitted',
          );
          print('   Checking for status=approved as fallback...');

          // Fallback: Check for approved appointments
          final approvedQuery = await FirebaseFirestore.instance
              .collection('appointments')
              .where('patientId', isEqualTo: patientId)
              .where('facilityId', isEqualTo: widget.facilityId)
              .where('status', isEqualTo: 'approved')
              .limit(1)
              .get();

          if (approvedQuery.docs.isNotEmpty) {
            appointmentIdToUpdate = approvedQuery.docs.first.id;
            print('✅ Found approved appointment: $appointmentIdToUpdate');
          } else {
            print(
              '⚠️ WARNING: No appointment found for this patient - may not have come from OPD',
            );
          }
        }
      }

      // Commit batch first (admission update + inpatient deletion)
      await batch.commit();
      print('✅ Discharge batch committed successfully');

      // Mark appointment as completed using direct update (not batch) to ensure it executes
      if (appointmentIdToUpdate != null && appointmentIdToUpdate.isNotEmpty) {
        try {
          final appointmentRef = FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentIdToUpdate);

          // First check if appointment exists
          final appointmentDoc = await appointmentRef.get();
          if (!appointmentDoc.exists) {
            print(
              '⚠️ ERROR: Appointment document does not exist: $appointmentIdToUpdate',
            );
            print(
              '   Cannot mark as completed - appointment not found in Firestore',
            );
          } else {
            final appointmentData = appointmentDoc.data();
            print(
              '📋 Found appointment: ${appointmentData?['patientName']} - Status: ${appointmentData?['status']}',
            );

            await appointmentRef.update({
              'status': 'completed',
              'completedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'completionNotes':
                  'Patient discharged from ward - $_dischargeType',
              'manuallyCompleted': false, // Automatic completion from discharge
            });
            print(
              '✅ Appointment $appointmentIdToUpdate marked as completed successfully',
            );
            print('   Patient will no longer appear in OPD out-patient screen');
          }
        } catch (e) {
          print('⚠️ ERROR marking appointment as completed: $e');
          print('   Appointment ID: $appointmentIdToUpdate');
          print(
            '   This patient will reappear in OPD until manually marked complete',
          );
        }
      } else {
        print('⚠️ ERROR: Cannot update appointment - no appointmentId found!');
        print('   Admission ID: $_selectedAdmissionId');
        print(
          '   This patient will reappear in OPD until manually marked complete',
        );
      }

      // Release bed using direct update (not batch) to ensure it executes
      if (bedIdToRelease != null && wardIdToRelease != null) {
        try {
          final bedRef = FirebaseFirestore.instance
              .collection('facilities')
              .doc(widget.facilityId)
              .collection('wards')
              .doc(wardIdToRelease)
              .collection('beds')
              .doc(bedIdToRelease);

          await bedRef.update({
            'status': 'available',
            'occupiedBy': null,
            'occupiedByName': null,
            'patientId': null,
            'inpatientId': null,
            'occupiedAt': null,
            'reservedFor': null,
            'reservedForName': null,
            'reservedAt': null,
            'admissionId': null,
            'releasedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print(
            '✅ Bed $bedIdToRelease in ward $wardIdToRelease released successfully',
          );
        } catch (e) {
          print('⚠️ ERROR releasing bed: $e');
          print(
            '   Path: facilities/${widget.facilityId}/wards/$wardIdToRelease/beds/$bedIdToRelease',
          );
        }
      } else {
        print(
          '⚠️ ERROR: Cannot release bed - missing bedId ($bedIdToRelease) or wardId ($wardIdToRelease)',
        );
        print('   Admission ID: $_selectedAdmissionId');
        print('   Admission data has bedId: ${admissionData['bedId']}');
        print('   Admission data has wardId: ${admissionData['wardId']}');
      }

      // Create pending prescriptions for pharmacy (if any)
      if (_dischargeMedications.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .add({
              'admissionId': _selectedAdmissionId,
              'patientId': patientId,
              'patientName': patientName,
              'facilityId': widget.facilityId,
              'prescriptions': _dischargeMedications,
              'clinicianName': widget.staffName,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'pending',
              'source': 'discharge',
            });
      }

      // Create pending lab tests (if any)
      for (var test in _dischargeLabTests) {
        await FirebaseFirestore.instance.collection('pending_lab_tests').add({
          'admissionId': _selectedAdmissionId,
          'patientId': patientId,
          'patientName': patientName,
          'facilityId': widget.facilityId,
          'testName': test['testName'],
          'cost': test['cost'],
          'clinicianName': widget.staffName,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'source': 'discharge',
        });
      }

      // Save discharge note to patient health records
      await FirebaseFirestore.instance.collection('health_records').add({
        'type': 'WARD_DISCHARGE',
        'patientId': patientId,
        'patientUid': patientId,
        'patientName': patientName,
        'providerId': widget.staffId,
        'providerName': widget.staffName,
        'providerType': 'FACILITY_STAFF',
        'facilityId': widget.facilityId,
        'facilityName': widget.facilityName,
        'admissionId': _selectedAdmissionId,
        'appointmentId': appointmentId,
        'date': FieldValue.serverTimestamp(),
        'dischargeDate': Timestamp.fromDate(_selectedDate),
        'data': {
          'dischargeType': _dischargeType,
          'dischargeSummary': _dischargeSummaryController.text.trim(),
          'dischargeMedications': _dischargeMedications,
          'dischargeLabTests': _dischargeLabTests,
          'dischargeCosts': dischargeCosts,
          'followUpInstructions': _followUpInstructionsController.text.trim(),
          'dischargedBy': widget.staffName,
          'dischargedById': widget.staffId,
        },
        'dischargeSummary': _dischargeSummaryController.text.trim(),
        'dischargeType': _dischargeType,
        'medications': _dischargeMedications,
        'labTests': _dischargeLabTests,
        'followUpInstructions': _followUpInstructionsController.text.trim(),
        'accessibleBy': ['patient', 'doctor', 'chw', 'facility'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'isEditable': false,
        'isDeletable': false,
        'statusFlag': 'completed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dischargeCosts > 0
                  ? 'Patient discharged successfully. ₦${dischargeCosts.toStringAsFixed(2)} deducted for lab tests.'
                  : 'Patient discharged successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _dischargeSummaryController.clear();
        _followUpInstructionsController.clear();
        setState(() {
          _selectedAdmissionId = null;
          _dischargeType = 'improved';
          _selectedDate = DateTime.now();
          _dischargeMedications.clear();
          _dischargeLabTests.clear();
        });
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Discharges'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade400, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.exit_to_app, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Discharge',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.facilityName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Patient Selection
            StreamBuilder<QuerySnapshot>(
              stream: widget.filterByEmergency
                  ? FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .where('admissionType', isEqualTo: 'emergency')
                        .snapshots()
                  : widget.excludeEmergencyAdmissions
                  ? FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .where('admissionType', isNotEqualTo: 'emergency')
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('admissions')
                        .where('facilityId', isEqualTo: widget.facilityId)
                        .where('status', isEqualTo: 'admitted')
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final admissions = snapshot.data!.docs;

                if (admissions.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No admitted patients',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Patient *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedAdmissionId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          hint: const Text('Choose patient to discharge'),
                          isExpanded: true,
                          items: admissions.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final patientName =
                                data['patientName'] ?? 'Unknown';
                            final admissionDate =
                                (data['admissionDate'] as Timestamp?)?.toDate();
                            final dateStr = admissionDate != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(admissionDate)
                                : 'N/A';

                            return DropdownMenuItem<String>(
                              value: doc.id,
                              child: Text(
                                '$patientName - Admitted: $dateStr',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedAdmissionId = value;
                            });
                          },
                        ),
                        if (_selectedAdmissionId != null) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              context.push(
                                '/ward_admission_billing',
                                extra: {
                                  'admissionId': _selectedAdmissionId,
                                  'facilityId': widget.facilityId,
                                  'facilityName': widget.facilityName,
                                },
                              );
                            },
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('View Billing'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Discharge Form
            if (_selectedAdmissionId != null) ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Discharge Date
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Discharge Date *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _selectDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  DateFormat(
                                    'EEEE, MMMM dd, yyyy',
                                  ).format(_selectedDate),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discharge Type
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Discharge Type *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _dischargeType,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'improved',
                                  child: Text('Improved'),
                                ),
                                DropdownMenuItem(
                                  value: 'recovered',
                                  child: Text('Fully Recovered'),
                                ),
                                DropdownMenuItem(
                                  value: 'stable',
                                  child: Text('Stable'),
                                ),
                                DropdownMenuItem(
                                  value: 'transferred',
                                  child: Text('Transferred'),
                                ),
                                DropdownMenuItem(
                                  value: 'ama',
                                  child: Text('Against Medical Advice (AMA)'),
                                ),
                                DropdownMenuItem(
                                  value: 'deceased',
                                  child: Text('Deceased'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _dischargeType = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discharge Summary
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Discharge Summary *',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _dischargeSummaryController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter discharge summary, diagnosis, and treatment provided...',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter discharge summary';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Medications
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Discharge Medications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _addDischargeMedication,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_dischargeMedications.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'No medications added yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _dischargeMedications.length,
                                itemBuilder: (context, index) {
                                  final prescription =
                                      _dischargeMedications[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.medication,
                                        color: Colors.teal,
                                      ),
                                      title: Text(
                                        prescription['medication'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${prescription['dosage']}\n'
                                        'Duration: ${prescription['duration']}\n'
                                        '${prescription['instructions']}',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _dischargeMedications.removeAt(
                                              index,
                                            );
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

                    // Lab Tests
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Discharge Lab Tests',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _addDischargeLabTest,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_dischargeLabTests.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'No lab tests added yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _dischargeLabTests.map((test) {
                                  return Chip(
                                    label: Text(
                                      '${test['testName']} - ₦${test['cost'].toStringAsFixed(2)}',
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 18,
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _dischargeLabTests.remove(test);
                                      });
                                    },
                                    backgroundColor: Colors.teal.shade50,
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cost Summary
                    if (_dischargeLabTests.isNotEmpty)
                      Card(
                        elevation: 2,
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Discharge Costs',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Lab Tests:'),
                                  Text(
                                    '₦${_calculateDischargeCosts().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '₦${_calculateDischargeCosts().toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_dischargeLabTests.isNotEmpty)
                      const SizedBox(height: 16),

                    // Follow-up Instructions
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Follow-up Instructions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _followUpInstructionsController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter follow-up visit schedule and instructions...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Discharge Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _dischargePatient,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Discharge Patient',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Prescription Dialog Widget
class _PrescriptionDialog extends StatefulWidget {
  final List<Map<String, String>> medications;
  final Function(Map<String, String>) onAdd;

  const _PrescriptionDialog({required this.medications, required this.onAdd});

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  String? _selectedMedication;
  final _dosageController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _customMedicationController = TextEditingController();

  @override
  void dispose() {
    _dosageController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _customMedicationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uniqueMedications =
        widget.medications.map((m) => m['name']!).toSet().toList()..sort();

    // Add "Other" option at the end
    uniqueMedications.add('Other');

    return AlertDialog(
      title: const Text('Add Discharge Medication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedMedication,
              decoration: const InputDecoration(
                labelText: 'Medication',
                border: OutlineInputBorder(),
              ),
              items: uniqueMedications.map((med) {
                return DropdownMenuItem(value: med, child: Text(med));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMedication = value;
                  if (value != 'Other') {
                    _customMedicationController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Show custom medication field when "Other" is selected
            if (_selectedMedication == 'Other')
              TextField(
                controller: _customMedicationController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  hintText: 'Enter medication name',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_selectedMedication == 'Other') const SizedBox(height: 16),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g., 1 tab TDS',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: 'Duration',
                hintText: 'e.g., 7 days',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Instructions',
                hintText: 'e.g., After meals',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Validate based on whether "Other" is selected
            final isOther = _selectedMedication == 'Other';
            final medicationName = isOther
                ? _customMedicationController.text.trim()
                : _selectedMedication;

            if (medicationName == null ||
                medicationName.isEmpty ||
                _dosageController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please fill in all required fields'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            widget.onAdd({
              'medication': medicationName,
              'dosage': _dosageController.text,
              'duration': _durationController.text,
              'instructions': _instructionsController.text,
            });
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Selection Dialog for Lab Tests
class _SelectionDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<String> selectedItems;
  final Function(String) onSelect;

  const _SelectionDialog({
    required this.title,
    required this.items,
    required this.selectedItems,
    required this.onSelect,
  });

  @override
  State<_SelectionDialog> createState() => _SelectionDialogState();
}

class _SelectionDialogState extends State<_SelectionDialog> {
  bool _showCustomInput = false;
  final _customItemController = TextEditingController();

  @override
  void dispose() {
    _customItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showCustomInput)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length + 1, // +1 for "Other" option
                  itemBuilder: (context, index) {
                    // Add "Other" as last item
                    if (index == widget.items.length) {
                      return ListTile(
                        leading: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.blue,
                        ),
                        title: const Text(
                          'Other',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        subtitle: const Text('Add custom item'),
                        onTap: () {
                          setState(() {
                            _showCustomInput = true;
                          });
                        },
                      );
                    }

                    final item = widget.items[index];
                    final name = item['name'] as String;
                    final cost = item['cost'] as num;
                    final isSelected = widget.selectedItems.contains(name);

                    return ListTile(
                      title: Text(name),
                      subtitle: Text('₦${cost.toStringAsFixed(2)}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        widget.onSelect(name);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),

            // Custom input field when "Other" is selected
            if (_showCustomInput) ...[
              TextField(
                controller: _customItemController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText:
                      'Enter ${widget.title.toLowerCase().replaceAll('Select ', '')}',
                  hintText: 'Type the name here',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCustomInput = false;
                        _customItemController.clear();
                      });
                    },
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final customItem = _customItemController.text.trim();
                      if (customItem.isNotEmpty) {
                        widget.onSelect(customItem);
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: !_showCustomInput
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ]
          : [],
    );
  }
}
