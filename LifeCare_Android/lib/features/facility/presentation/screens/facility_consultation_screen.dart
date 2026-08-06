import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../shared/services/ai_validation_service.dart';
import '../../../shared/widgets/ai_validation_dialog.dart';
import '../../../shared/presentation/screens/ai_assistant_screen.dart';
import '../../../shared/services/ai_clinical_suggestions_service.dart';
import '../../../shared/widgets/inline_ai_suggestions_widget.dart';

class FacilityConsultationScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String facilityId;
  final String clinicianId;
  final String clinicianName;

  const FacilityConsultationScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.facilityId,
    required this.clinicianId,
    required this.clinicianName,
  });

  @override
  State<FacilityConsultationScreen> createState() =>
      _FacilityConsultationScreenState();
}

class _FacilityConsultationScreenState
    extends State<FacilityConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintsController = TextEditingController();
  final _historyController = TextEditingController();
  final _examinationController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentPlanController = TextEditingController();
  final _followUpController = TextEditingController();

  final List<Map<String, dynamic>> _prescriptions = [];
  final List<String> _labTests = [];
  final List<String> _imagingRequests = [];

  double _consultationFee = 5000.0; // Will be loaded from facility pricing
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableLabTests = [];
  List<Map<String, dynamic>> _availableImaging = [];

  // AI Suggestions state
  List<String> _diagnosisSuggestions = [];
  List<String> _examinationSuggestions = [];
  List<String> _treatmentSuggestions = [];
  bool _isLoadingDiagnosisSuggestions = false;
  bool _isLoadingExaminationSuggestions = false;
  bool _isLoadingTreatmentSuggestions = false;
  Timer? _diagnosisDebounceTimer;
  Timer? _examinationDebounceTimer;
  Timer? _treatmentDebounceTimer;

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
    _loadConsultationFee();
    _loadLabTestsAndImaging();
  }

  Future<void> _loadConsultationFee() async {
    try {
      // Load consultation fee from facility_service_prices collection
      final servicePricesDoc = await FirebaseFirestore.instance
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .get();

      if (servicePricesDoc.exists && mounted) {
        final servicePrices = servicePricesDoc.data() as Map<String, dynamic>;

        // Try to get general_consultation fee first, then fall back to other consultation types
        double consultationFee = 5000.0; // default

        if (servicePrices.containsKey('general_consultation')) {
          consultationFee =
              (servicePrices['general_consultation'] as num?)?.toDouble() ??
              5000.0;
        } else if (servicePrices.containsKey('specialist_consultation')) {
          consultationFee =
              (servicePrices['specialist_consultation'] as num?)?.toDouble() ??
              5000.0;
        } else if (servicePrices.containsKey('remote_consultation')) {
          consultationFee =
              (servicePrices['remote_consultation'] as num?)?.toDouble() ??
              5000.0;
        }

        setState(() {
          _consultationFee = consultationFee;
        });
      }
    } catch (e) {
      // Keep default fee of 5000.0 if error occurs
    }
  }

  Future<void> _loadLabTestsAndImaging() async {
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

      if (mounted) {
        setState(() {
          _availableLabTests = labTests;
          _availableImaging = imaging;
        });
      }
    } catch (e) {
      // Error loading tests - will use empty lists
    }
  }

  @override
  void dispose() {
    _complaintsController.dispose();
    _historyController.dispose();
    _examinationController.dispose();
    _diagnosisController.dispose();
    _treatmentPlanController.dispose();
    _followUpController.dispose();
    _diagnosisDebounceTimer?.cancel();
    _examinationDebounceTimer?.cancel();
    _treatmentDebounceTimer?.cancel();
    super.dispose();
  }

  // AI Suggestions methods
  void _fetchDiagnosisSuggestions() {
    _diagnosisDebounceTimer?.cancel();
    _diagnosisDebounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      final complaints = _complaintsController.text.trim();
      if (complaints.length < 3) {
        setState(() {
          _diagnosisSuggestions = [];
          _isLoadingDiagnosisSuggestions = false;
        });
        return;
      }

      setState(() => _isLoadingDiagnosisSuggestions = true);

      final suggestions =
          await AIClinicalSuggestionsService.getDifferentialDiagnosisSuggestions(
            complaints: complaints,
            history: _historyController.text.trim(),
            examination: _examinationController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _diagnosisSuggestions = suggestions;
          _isLoadingDiagnosisSuggestions = false;
        });
      }
    });
  }

  void _fetchExaminationSuggestions() {
    _examinationDebounceTimer?.cancel();
    _examinationDebounceTimer = Timer(
      const Duration(milliseconds: 1000),
      () async {
        final complaints = _complaintsController.text.trim();
        if (complaints.length < 3) {
          setState(() {
            _examinationSuggestions = [];
            _isLoadingExaminationSuggestions = false;
          });
          return;
        }

        setState(() => _isLoadingExaminationSuggestions = true);

        final suggestions =
            await AIClinicalSuggestionsService.getExaminationSuggestions(
              complaints: complaints,
              history: _historyController.text.trim(),
            );

        if (mounted) {
          setState(() {
            _examinationSuggestions = suggestions;
            _isLoadingExaminationSuggestions = false;
          });
        }
      },
    );
  }

  void _fetchTreatmentSuggestions() {
    _treatmentDebounceTimer?.cancel();
    _treatmentDebounceTimer = Timer(
      const Duration(milliseconds: 1000),
      () async {
        final diagnosis = _diagnosisController.text.trim();
        if (diagnosis.length < 3) {
          setState(() {
            _treatmentSuggestions = [];
            _isLoadingTreatmentSuggestions = false;
          });
          return;
        }

        setState(() => _isLoadingTreatmentSuggestions = true);

        final suggestions =
            await AIClinicalSuggestionsService.getTreatmentPlanSuggestions(
              diagnosis: diagnosis,
              examination: _examinationController.text.trim(),
            );

        if (mounted) {
          setState(() {
            _treatmentSuggestions = suggestions;
            _isLoadingTreatmentSuggestions = false;
          });
        }
      },
    );
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
      builder: (context) => _SelectionDialog(
        title: 'Select Lab Test',
        items: _availableLabTests,
        selectedItems: _labTests,
        onSelect: (test) {
          setState(() {
            if (!_labTests.contains(test)) {
              _labTests.add(test);
            }
          });
        },
      ),
    );
  }

  void _addImagingRequest() {
    showDialog(
      context: context,
      builder: (context) => _SelectionDialog(
        title: 'Select Imaging',
        items: _availableImaging,
        selectedItems: _imagingRequests,
        onSelect: (imaging) {
          setState(() {
            if (!_imagingRequests.contains(imaging)) {
              _imagingRequests.add(imaging);
            }
          });
        },
      ),
    );
  }

  double _calculateTotalCost() {
    double total = _consultationFee;

    // Add lab test costs
    for (var test in _labTests) {
      final testData = _availableLabTests.firstWhere(
        (t) => t['name'] == test,
        orElse: () => {'cost': 0.0},
      );
      total += (testData['cost'] as num).toDouble();
    }

    // Add imaging costs
    for (var imaging in _imagingRequests) {
      final imagingData = _availableImaging.firstWhere(
        (i) => i['name'] == imaging,
        orElse: () => {'cost': 0.0},
      );
      total += (imagingData['cost'] as num).toDouble();
    }

    return total;
  }

  Future<void> _saveConsultation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_diagnosisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a diagnosis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totalCost = _calculateTotalCost();

      // Get patient document
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .get();

      final patientData = patientDoc.data();
      if (patientData == null) {
        throw Exception('Patient not found');
      }

      // Check patient registration type to determine wallet type
      final registrationType = patientData['registrationType'] as String?;

      double walletBalance = 0.0;
      String? householdId;
      bool useHouseholdWallet = false;
      bool useMainWallet = false; // Track if using main wallets collection
      String? actualWalletUserId; // The actual user ID for wallet lookup

      if (registrationType == 'household') {
        // For household members, use household wallet
        useHouseholdWallet = true;
        householdId = patientData['householdId'] as String?;
        if (householdId == null || householdId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Patient not assigned to a household. Please assign to household first.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Get household wallet balance from household_wallets collection
        final householdDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        if (householdDoc.exists && householdDoc.data() != null) {
          walletBalance =
              (householdDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        } else {
          walletBalance = 0.0;
        }
      } else {
        // For individual patients, first check facility_patients walletBalance
        double facilityWalletBalance =
            (patientData['walletBalance'] as num?)?.toDouble() ?? 0.0;

        // Try multiple strategies to find the correct wallet:
        // 1. widget.patientId (from appointment - this is usually the auth UID)
        // 2. patientData fields from facility_patients document

        // Strategy 1: Try widget.patientId directly (from appointment)
        var mainWalletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(widget.patientId)
            .get();

        double mainWalletBalance = 0.0;
        actualWalletUserId = widget.patientId;

        if (mainWalletDoc.exists && mainWalletDoc.data() != null) {
          mainWalletBalance =
              (mainWalletDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
        } else {
          // Strategy 2: Try other user IDs from patient data
          final alternateUserId =
              patientData['userId'] ??
              patientData['uid'] ??
              patientData['patientId'];
          if (alternateUserId != null && alternateUserId != widget.patientId) {
            mainWalletDoc = await FirebaseFirestore.instance
                .collection('wallets')
                .doc(alternateUserId)
                .get();

            if (mainWalletDoc.exists && mainWalletDoc.data() != null) {
              mainWalletBalance =
                  (mainWalletDoc.data()!['balance'] as num?)?.toDouble() ?? 0.0;
              actualWalletUserId = alternateUserId;
            }
          }
        }

        // Use the wallet with available balance (prefer facility wallet if both have balance)
        // Check against total cost (consultation + lab tests + imaging)
        if (facilityWalletBalance >= totalCost) {
          walletBalance = facilityWalletBalance;
          useMainWallet = false;
        } else if (mainWalletBalance >= totalCost) {
          walletBalance = mainWalletBalance;
          useMainWallet = true;
        } else {
          // Use whichever has more balance for better error message
          if (mainWalletBalance > facilityWalletBalance) {
            walletBalance = mainWalletBalance;
            useMainWallet = true;
          } else {
            walletBalance = facilityWalletBalance;
            useMainWallet = false;
          }
        }
      }

      // Check if wallet has sufficient balance for total cost
      // Total includes consultation fee + lab tests + imaging
      if (walletBalance < totalCost) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient ${useHouseholdWallet ? "household" : "patient"} wallet balance. Total cost: ₦${totalCost.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final consultationData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'facilityId': widget.facilityId,
        'clinicianId': widget.clinicianId,
        'clinicianName': widget.clinicianName,
        'complaints': _complaintsController.text.trim(),
        'history': _historyController.text.trim(),
        'examination': _examinationController.text.trim(),
        'diagnosis': _diagnosisController.text.trim(),
        'treatmentPlan': _treatmentPlanController.text.trim(),
        'followUp': _followUpController.text.trim(),
        'prescriptions': _prescriptions,
        'labTests': _labTests,
        'imagingRequests': _imagingRequests,
        'consultationFee': _consultationFee,
        'totalCost': totalCost,
        'consultedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      };

      // Save consultation
      final consultationRef = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .collection('consultations')
          .add(consultationData);

      // Create pending prescriptions for pharmacy
      if (_prescriptions.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('pending_prescriptions')
            .add({
              'consultationId': consultationRef.id,
              'patientId': widget.patientId,
              'patientName': widget.patientName,
              'facilityId': widget.facilityId,
              'prescriptions': _prescriptions,
              'clinicianName': widget.clinicianName,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'pending',
            });
      }

      // Create pending lab tests
      for (var test in _labTests) {
        final testData = _availableLabTests.firstWhere(
          (t) => t['name'] == test,
        );
        await FirebaseFirestore.instance.collection('pending_lab_tests').add({
          'consultationId': consultationRef.id,
          'patientId': widget.patientId,
          'patientName': widget.patientName,
          'facilityId': widget.facilityId,
          'testName': test,
          'cost': testData['cost'],
          'clinicianName': widget.clinicianName,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      // Create pending imaging requests
      for (var imaging in _imagingRequests) {
        final imagingData = _availableImaging.firstWhere(
          (i) => i['name'] == imaging,
        );
        await FirebaseFirestore.instance.collection('pending_imaging').add({
          'consultationId': consultationRef.id,
          'patientId': widget.patientId,
          'patientName': widget.patientName,
          'facilityId': widget.facilityId,
          'imagingType': imaging,
          'cost': imagingData['cost'],
          'clinicianName': widget.clinicianName,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
      }

      // Deduct total cost (consultation + lab + imaging) from appropriate wallet
      if (useHouseholdWallet && householdId != null) {
        // Deduct from household wallet for household members
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .update({'balance': FieldValue.increment(-totalCost)});

        // Record transaction in household wallet
        await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': totalCost,
              'description':
                  'Consultation for ${widget.patientName} with ${widget.clinicianName} (includes lab tests and imaging)',
              'patientId': widget.patientId,
              'patientName': widget.patientName,
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else if (useMainWallet) {
        // Deduct from main wallets collection (for individual/remote patients)
        // Use actualWalletUserId which was determined during wallet lookup
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(actualWalletUserId)
            .update({
              'balance': FieldValue.increment(-totalCost),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Record transaction in main wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(actualWalletUserId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': totalCost,
              'description':
                  'Consultation with ${widget.clinicianName} at ${widget.facilityId} (includes lab tests and imaging)',
              'facilityId': widget.facilityId,
              'timestamp': FieldValue.serverTimestamp(),
              'balanceBefore': walletBalance,
              'balanceAfter': walletBalance - totalCost,
              'status': 'completed',
            });
      } else {
        // Deduct from facility_patients wallet (for facility-registered patients)
        await FirebaseFirestore.instance
            .collection('facility_patients')
            .doc(widget.patientId)
            .update({'walletBalance': FieldValue.increment(-totalCost)});

        // Record transaction for patient
        await FirebaseFirestore.instance
            .collection('facility_patients')
            .doc(widget.patientId)
            .collection('transactions')
            .add({
              'type': 'debit',
              'amount': totalCost,
              'description':
                  'Consultation with ${widget.clinicianName} (includes lab tests and imaging)',
              'timestamp': FieldValue.serverTimestamp(),
            });
      }

      // Facility patients (both household and individual): 100% to facility
      // Credit the facility wallet
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.facilityId)
          .update({
            'balance': FieldValue.increment(totalCost),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Record transaction in facility wallet
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.facilityId)
          .collection('transactions')
          .add({
            'type': 'credit',
            'amount': totalCost,
            'description':
                'Consultation payment from ${widget.patientName} (Facility Patient)',
            'patientId': widget.patientId,
            'patientName': widget.patientName,
            'clinicianId': widget.clinicianId,
            'clinicianName': widget.clinicianName,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });

      // Update appointment status to completed
      final appointmentsQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: widget.patientId)
          .where('assignedStaffId', isEqualTo: widget.clinicianId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (var appointmentDoc in appointmentsQuery.docs) {
        await appointmentDoc.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update facility_patients outpatient record with consultation complete flags
      await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(widget.patientId)
          .update({'hasConsultation': true, 'consultationComplete': true});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consultation saved. ₦${_consultationFee.toStringAsFixed(2)} deducted from wallet.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving consultation: $e'),
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
        title: const Text('Consultation Form'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy),
            tooltip: 'AI Assistant - Clinical Decision Support',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AIAssistantScreen(
                    assistantType: AIAssistantType.doctor,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Patient Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient: ${widget.patientName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Clinician: ${widget.clinicianName}'),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now())}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Presenting Complaints
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _complaintsController,
                  onChanged: (value) {
                    _fetchDiagnosisSuggestions();
                    _fetchExaminationSuggestions();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Presenting Complaints *',
                    hintText: 'Chief complaints...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter presenting complaints';
                    }
                    return null;
                  },
                ),
              ),
            ),

            // History
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _historyController,
                  onChanged: (value) {
                    _fetchDiagnosisSuggestions();
                    _fetchExaminationSuggestions();
                  },
                  decoration: const InputDecoration(
                    labelText: 'History of Presenting Complaints',
                    hintText: 'Detailed history...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ),
            ),

            // Physical Examination
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _examinationController,
                      onChanged: (value) => _fetchDiagnosisSuggestions(),
                      decoration: const InputDecoration(
                        labelText: 'Physical Examination',
                        hintText: 'Examination findings...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    // AI Suggestions for Examination
                    if (_isLoadingExaminationSuggestions)
                      const InlineAILoadingWidget(
                        title: 'Generating examination suggestions...',
                        color: Colors.purple,
                      ),
                    if (!_isLoadingExaminationSuggestions &&
                        _examinationSuggestions.isNotEmpty)
                      InlineAISuggestionsWidget(
                        suggestions: _examinationSuggestions,
                        title: 'AI Examination Suggestions',
                        icon: Icons.medical_services,
                        color: Colors.purple,
                        onRefresh: _fetchExaminationSuggestions,
                      ),
                  ],
                ),
              ),
            ),

            // Diagnosis
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _diagnosisController,
                      onChanged: (value) => _fetchTreatmentSuggestions(),
                      decoration: const InputDecoration(
                        labelText: 'Diagnosis *',
                        hintText: 'Clinical diagnosis...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter diagnosis';
                        }
                        return null;
                      },
                    ),
                    // AI Differential Diagnosis Suggestions
                    if (_isLoadingDiagnosisSuggestions)
                      const InlineAILoadingWidget(
                        title: 'Analyzing differential diagnosis...',
                        color: Colors.orange,
                      ),
                    if (!_isLoadingDiagnosisSuggestions &&
                        _diagnosisSuggestions.isNotEmpty)
                      InlineAISuggestionsWidget(
                        suggestions: _diagnosisSuggestions,
                        title: 'AI Differential Diagnosis Suggestions',
                        icon: Icons.psychology,
                        color: Colors.orange,
                        onRefresh: _fetchDiagnosisSuggestions,
                      ),
                  ],
                ),
              ),
            ),

            // Prescriptions
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
                          'Prescriptions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addPrescription,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_prescriptions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No prescriptions added'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _prescriptions.length,
                        itemBuilder: (context, index) {
                          final rx = _prescriptions[index];
                          return ListTile(
                            title: Text('${rx['medication']}'),
                            subtitle: Text(
                              'Dose: ${rx['dosage']} | Duration: ${rx['duration']} | ${rx['instructions']}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _prescriptions.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Lab Tests
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
                          'Lab Tests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addLabTest,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_labTests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No lab tests requested'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: _labTests.map((test) {
                          final testData = _availableLabTests.firstWhere(
                            (t) => t['name'] == test,
                          );
                          return Chip(
                            label: Text('$test (₦${testData['cost']})'),
                            onDeleted: () {
                              setState(() {
                                _labTests.remove(test);
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Imaging
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addImagingRequest,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_imagingRequests.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No imaging requested'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: _imagingRequests.map((imaging) {
                          final imagingData = _availableImaging.firstWhere(
                            (i) => i['name'] == imaging,
                          );
                          return Chip(
                            label: Text('$imaging (₦${imagingData['cost']})'),
                            onDeleted: () {
                              setState(() {
                                _imagingRequests.remove(imaging);
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            // Treatment Plan
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _treatmentPlanController,
                      decoration: const InputDecoration(
                        labelText: 'Treatment Plan',
                        hintText: 'Management plan...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    // AI Treatment Suggestions
                    if (_isLoadingTreatmentSuggestions)
                      const InlineAILoadingWidget(
                        title: 'Generating treatment suggestions...',
                        color: Colors.teal,
                      ),
                    if (!_isLoadingTreatmentSuggestions &&
                        _treatmentSuggestions.isNotEmpty)
                      InlineAISuggestionsWidget(
                        suggestions: _treatmentSuggestions,
                        title: 'AI Treatment Plan Suggestions',
                        icon: Icons.medical_information,
                        color: Colors.teal,
                        onRefresh: _fetchTreatmentSuggestions,
                      ),
                  ],
                ),
              ),
            ),

            // Follow-up
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _followUpController,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up Instructions',
                    hintText: 'Review in 1 week...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ),
            ),

            // Cost Summary
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cost Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Consultation Fee:'),
                        Text('₦${_consultationFee.toStringAsFixed(2)}'),
                      ],
                    ),
                    if (_labTests.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lab Tests (${_labTests.length}):'),
                          Text(
                            '₦${_labTests.fold<double>(0.0, (sum, test) {
                              final testData = _availableLabTests.firstWhere((t) => t['name'] == test);
                              return sum + (testData['cost'] as num).toDouble();
                            }).toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ],
                    if (_imagingRequests.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Imaging (${_imagingRequests.length}):'),
                          Text(
                            '₦${_imagingRequests.fold<double>(0.0, (sum, imaging) {
                              final imagingData = _availableImaging.firstWhere((i) => i['name'] == imaging);
                              return sum + (imagingData['cost'] as num).toDouble();
                            }).toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ],
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₦${_calculateTotalCost().toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveConsultation,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save Consultation',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Prescription Dialog
class _PrescriptionDialog extends StatefulWidget {
  final List<Map<String, String>> medications;
  final Function(Map<String, dynamic>) onAdd;

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
  ValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time validation
    _dosageController.addListener(_validatePrescription);
    _customMedicationController.addListener(_validatePrescription);
  }

  @override
  void dispose() {
    _dosageController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _customMedicationController.dispose();
    super.dispose();
  }

  Future<void> _validatePrescription() async {
    final medicationName = _selectedMedication == 'Other'
        ? _customMedicationController.text.trim()
        : _selectedMedication ?? '';
    final dosage = _dosageController.text.trim();

    if (medicationName.isEmpty || dosage.isEmpty) {
      setState(() => _validationResult = null);
      return;
    }

    // Parse frequency and route from dosage/instructions
    String frequency = 'as directed';
    String route = 'Oral';

    // Extract frequency from dosage (e.g., "1 tab TDS")
    final dosageLower = dosage.toLowerCase();
    if (dosageLower.contains('tid') || dosageLower.contains('tds')) {
      frequency = 'TID';
    } else if (dosageLower.contains('bid') || dosageLower.contains('bd')) {
      frequency = 'BID';
    } else if (dosageLower.contains('qid')) {
      frequency = 'QID';
    } else if (dosageLower.contains('od') || dosageLower.contains('daily')) {
      frequency = 'OD';
    }

    final result = await AIValidationService.validatePrescription(
      medicationName: medicationName,
      dosage: dosage,
      frequency: frequency,
      route: route,
    );

    setState(() => _validationResult = result);
  }

  @override
  Widget build(BuildContext context) {
    final uniqueMedications =
        widget.medications.map((m) => m['name']!).toSet().toList()..sort();

    // Add "Other" option at the end
    uniqueMedications.add('Other');

    return AlertDialog(
      title: const Text('Add Prescription'),
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
            const SizedBox(height: 16),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                hintText: 'e.g., 1 tab TDS',
                border: OutlineInputBorder(),
              ),
            ),
            // AI Validation Inline Display
            if (_validationResult != null)
              InlineValidationWidget(result: _validationResult!),
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
          onPressed: () async {
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

// Selection Dialog for Lab Tests and Imaging
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
      actions: [
        if (!_showCustomInput)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }
}
