// ignore_for_file: use_build_context_synchronously, avoid_print

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/data/services/appointment_service.dart';
import '../../../../core/services/fee_config_service.dart';

class ComprehensiveBookAppointmentScreen extends StatefulWidget {
  final Map<String, dynamic>? preSelectedProvider;
  final bool fromReferral;

  const ComprehensiveBookAppointmentScreen({
    super.key,
    this.preSelectedProvider,
    this.fromReferral = false,
  });

  @override
  State<ComprehensiveBookAppointmentScreen> createState() =>
      _ComprehensiveBookAppointmentScreenState();
}

class _ComprehensiveBookAppointmentScreenState
    extends State<ComprehensiveBookAppointmentScreen> {
  // Lock flags for provider and appointment type (for referral booking)
  bool _providerLocked = false;
  bool _appointmentTypeLocked = false;
  int? _freeAppointmentsLeft;
  bool _freeDialogShown = false;
  // Payment variables
  double? _calculatedFee;
  String _currency = 'NGN';

  // Calculate appointment fee with free first appointment logic and custom pricing
  Future<double> _calculateAppointmentFeeWithFreeLogic() async {
    // Get user ID from Firebase Auth or SharedPreferences (Termii login)
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');
      } catch (e) {
        print('⚠️ Error reading SharedPreferences: $e');
      }
    }

    if (userId == null ||
        userId.isEmpty ||
        _selectedProvider == null ||
        _selectedAppointmentType == null) {
      return 0.0;
    }

    // Count previous appointments for this user
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: userId)
        .get();
    final previousCount = snapshot.docs.length;
    if (previousCount < 1) {
      return 0.0;
    }
    final type = (_selectedProvider!['type'] ?? '').toString().toLowerCase();
    final apptType = _selectedAppointmentType?.toLowerCase() ?? '';
    // Default to NGN for now, but could be dynamic per provider in future
    _currency = 'NGN';

    // Use dynamic fee configuration
    return await FeeConfigService.getAppointmentFee(
      providerType: type,
      appointmentType: apptType,
    );
  }

  // Simulated payment confirmation dialog
  Future<bool> _showPaymentDialog(double amount) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Pay for Appointment'),
            content: Text(
              'Proceed to pay ${_currencySymbol(_currency)}${amount.toStringAsFixed(2)} for this appointment?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Pay'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _currencySymbol(String currency) {
    switch (currency) {
      case 'NGN':
        return '₦';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return '';
    }
  }

  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // Form Controllers
  // Main Reason for Appointment (single-select)
  final List<String> _mainReasons = [
    'Fever or Chills',
    'Cough or Breathing Difficulty',
    'Chest Pain or Palpitations',
    'Stomach Pain, Diarrhea or Constipation',
    'Urinary Problems (pain, frequency, blood in urine)',
    'Skin Rash, Itching or Swelling',
    'Headache, Seizures or Weakness',
    'Joint or Muscle Pain',
    'Mental Health Concern (e.g., Anxiety, Depression, Stress)',
    "Pregnancy or Women's Health Concern",
    "Child's Health Concern",
    'Eye or Vision Issues',
    'Ear, Nose or Throat Issues',
    'Cancer-related Concerns',
    'Other',
  ];
  String? _selectedMainReason;
  String _otherMainReason = '';
  final _symptomsController = TextEditingController();
  final _medicationsTakenController = TextEditingController();
  final _triggersController = TextEditingController();
  final _durationController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  // State Variables
  int _currentPage = 0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _providers = [];
  Map<String, dynamic>? _selectedProvider;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedAppointmentType;
  String? _selectedUrgency;
  String? _selectedSeverity;
  // --- Consultation Channel ---
  String? _selectedConsultationChannel;
  final List<String> _consultationChannels = [
    'Video call',
    'Audio call',
    'Messaging chat',
    'Physical',
  ];

  final List<String> _appointmentTypes = [
    'General Consultation',
    'Follow-up Visit',
    'ANC (Antenatal Care)',
    'PNC (Postnatal Care)',
    'Emergency Consultation',
    'Specialist Referral',
    'Health Screening',
    'Vaccination',
    'Specialist Consultation',
    'Mental Health Consultation',
  ];

  final List<String> _urgencyLevels = [
    'Low - Not urgent',
    'Normal - Regular appointment',
    'High - Need attention soon',
    'Urgent - Need immediate care',
  ];

  final List<String> _severityScale = [
    'None - Follow-up/routine check',
    '1 - Mild discomfort',
    '2 - Noticeable but tolerable',
    '3 - Moderate discomfort',
    '4 - Significant discomfort',
    '5 - Severe pain/discomfort',
  ];

  // File upload state
  final List<File> _uploadedFiles = [];
  final List<String> _uploadedFileNames = [];

  @override
  void initState() {
    super.initState();

    // If a provider is pre-selected (e.g., from referral booking link), set it, lock selection, and set appointment type
    if (widget.preSelectedProvider != null) {
      _selectedProvider = widget.preSelectedProvider;
      _providerLocked = true;
      if (widget.fromReferral) {
        _selectedAppointmentType = 'Specialist Referral';
        _appointmentTypeLocked = true;
      } else {
        _appointmentTypeLocked = false;
      }
      // Skip to appointment details page (page 1)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() => _currentPage = 1);
      });
    } else {
      _providerLocked = false;
      _appointmentTypeLocked = false;
      _loadProviders();
    }

    // Load free appointment count
    _loadFreeAppointmentsLeft();
  }

  Future<void> _loadFreeAppointmentsLeft() async {
    // Get user ID from Firebase Auth or SharedPreferences (Termii login)
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null || userId.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('user_id');
      } catch (e) {
        print('⚠️ Error reading SharedPreferences: $e');
      }
    }

    if (userId == null || userId.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: userId)
        .get();
    setState(() {
      _freeAppointmentsLeft = 1 - snapshot.docs.length;
    });
  }

  @override
  void dispose() {
    // No controller for main complaint anymore
    _symptomsController.dispose();
    _medicationsTakenController.dispose();
    _triggersController.dispose();
    _durationController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    _emergencyContactController.dispose();
    _additionalNotesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      setState(() => _isLoading = true);

      print("📋 Loading providers...");

      final providers = <Map<String, dynamic>>[];

      // Get doctors with better error handling
      try {
        final doctorsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'doctor')
            .get();

        print("👨‍⚕️ Found ${doctorsSnapshot.docs.length} doctors");

        // Add doctors
        for (var doc in doctorsSnapshot.docs) {
          final data = doc.data();

          // Skip rejected doctors
          if (data['isRejected'] == true) {
            continue;
          }

          // Check if doctor is approved (if field exists)
          final isApproved =
              data['isApproved'] ??
              true; // Default to true if field doesn't exist

          if (isApproved) {
            providers.add({
              'id': doc.id,
              'name': data['fullName'] ?? data['name'] ?? 'Unknown Doctor',
              'type': 'Doctor',
              'specialization': data['specialization'] ?? 'General Practice',
              'location': data['location'] ?? 'Not specified',
              'rating': data['rating'] ?? 4.5,
              'image': data['imageUrl'] ?? data['profileImage'],
              'availability': data['availability'] ?? 'Available',
              'isApproved': isApproved,
            });
          }
        }
      } catch (e) {
        print("❌ Error loading doctors: $e");
      }

      // Get CHWs with better error handling
      try {
        final chwsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'chw')
            .get();

        print("👩‍⚕️ Found ${chwsSnapshot.docs.length} CHWs");

        // Add CHWs
        for (var doc in chwsSnapshot.docs) {
          final data = doc.data();

          // Skip rejected CHWs
          if (data['isRejected'] == true) {
            continue;
          }

          // CHWs need to be approved or have no approval status (legacy accounts)
          final isApproved = data['isApproved'] ?? true;

          if (isApproved) {
            providers.add({
              'id': doc.id,
              'name': data['fullName'] ?? data['name'] ?? 'Unknown CHW',
              'type': 'Community Health Worker',
              'specialization': 'Community Health',
              'location': data['location'] ?? 'Community Center',
              'rating': data['rating'] ?? 4.0,
              'image': data['imageUrl'] ?? data['profileImage'],
              'availability': data['availability'] ?? 'Available',
              'isApproved': isApproved,
            });
          }
        }
      } catch (e) {
        print("❌ Error loading CHWs: $e");
      }

      print(
        "📊 Total healthcare providers loaded: ${providers.length} (doctors & CHWs only)",
      );

      setState(() {
        _providers = providers;
        _isLoading = false;
      });

      if (providers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No doctors or CHWs available for appointments at the moment',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("❌ Error loading providers: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading healthcare providers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _uploadedFiles.addAll(
            result.files.map((file) => File(file.path!)).toList(),
          );
          _uploadedFileNames.addAll(
            result.files.map((file) => file.name).toList(),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    }
  }

  void _removeFile(int index) {
    setState(() {
      _uploadedFiles.removeAt(index);
      _uploadedFileNames.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Select Appointment Date',
    );

    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Select Appointment Time',
    );

    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<String?> _createSimpleAppointmentRecord() async {
    try {
      // Get user ID from Firebase Auth or SharedPreferences (for Termii login)
      String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null || userId.isEmpty) {
        // Try SharedPreferences for Termii login users
        try {
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getString('user_id');
        } catch (e) {
          print('⚠️ Error reading SharedPreferences: $e');
        }
      }

      if (userId == null || userId.isEmpty) {
        print('❌ No user ID found - user not logged in');
        return null;
      }

      print('📝 SIMPLE: Creating appointment record for userId: $userId');

      // Fetch patient name and email from Firestore users collection
      String patientName = 'Unknown Patient';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          patientName =
              userData['fullName'] ??
              userData['name'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              'Unknown Patient';
        }
      } catch (e) {
        print('⚠️ Could not fetch patient data from Firestore: $e');
        patientName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown Patient';
      }

      // Prepare appointment date as Timestamp for proper ordering
      DateTime? appointmentDateTime;
      if (_selectedDate != null) {
        if (_selectedTime != null) {
          appointmentDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
        } else {
          appointmentDateTime = _selectedDate;
        }
      }

      // Prepare pre-consultation checklist data
      final preConsultationData = {
        'mainComplaint': _selectedMainReason == 'Other'
            ? _otherMainReason
            : _selectedMainReason,
        'symptoms': _symptomsController.text,
        'duration': _durationController.text,
        'severity': _selectedSeverity,
        'medicationsTaken': _medicationsTakenController.text,
        'allergies': _allergiesController.text,
        'medicalHistory': _medicalHistoryController.text,
        'triggers': _triggersController.text,
        'emergencyContact': _emergencyContactController.text,
        'additionalNotes': _additionalNotesController.text,
        'urgency': _selectedUrgency,
        'consultationChannel': _selectedConsultationChannel,
      };

      // Use AppointmentService instead of direct Firestore write to bypass security rules
      final appointmentId = await AppointmentService.createAppointment(
        patientId: userId,
        patientName: patientName,
        providerId: _selectedProvider!['id'],
        providerName: _selectedProvider!['name'] ?? 'Unknown Provider',
        providerType: _selectedProvider!['type'] ?? 'Unknown',
        appointmentDate: appointmentDateTime ?? DateTime.now(),
        reason: _selectedMainReason == 'Other'
            ? _otherMainReason
            : (_selectedMainReason ?? 'General Consultation'),
        notes: _additionalNotesController.text.isNotEmpty
            ? _additionalNotesController.text
            : null,
        department: _selectedAppointmentType,
      );

      print(
        '✅ SIMPLE: Appointment record created successfully with ID: $appointmentId',
      );

      // Create health_records entry for pre-consultation checklist
      try {
        final healthRecordData = {
          'patientId': userId,
          'patientName': patientName,
          'appointmentId': appointmentId,
          'providerId': _selectedProvider!['id'],
          'providerName': _selectedProvider!['name'] ?? 'Unknown Provider',
          'providerType': _selectedProvider!['type'] ?? 'Unknown',
          'type': 'preconsultation_checklist',
          'appointmentType': _selectedAppointmentType ?? 'General Consultation',
          'appointmentDate': appointmentDateTime != null
              ? Timestamp.fromDate(appointmentDateTime)
              : FieldValue.serverTimestamp(),
          'data': preConsultationData,
          // Also store individual fields at top level for easier querying
          'mainComplaint': preConsultationData['mainComplaint'],
          'reason': preConsultationData['mainComplaint'],
          'symptoms': preConsultationData['symptoms'],
          'duration': preConsultationData['duration'],
          'severity': preConsultationData['severity'],
          'medications': preConsultationData['medicationsTaken'],
          'currentMedications': preConsultationData['medicationsTaken'],
          'medicationsTaken': preConsultationData['medicationsTaken'],
          'allergies': preConsultationData['allergies'],
          'medicalHistory': preConsultationData['medicalHistory'],
          'additionalNotes': preConsultationData['additionalNotes'],
          'notes': preConsultationData['additionalNotes'],
          'consultationChannel': preConsultationData['consultationChannel'],
          'channel': preConsultationData['consultationChannel'],
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('health_records')
            .add(healthRecordData);

        print(
          '✅ SIMPLE: Health record (pre-consultation checklist) created successfully',
        );
      } catch (e) {
        print('⚠️ SIMPLE: Could not create health record: $e');
        // Don't fail the appointment creation if health record creation fails
      }

      // Send notification to service provider about new appointment request
      try {
        final providerType =
            _selectedProvider!['type']?.toString().toLowerCase() ?? '';
        final appointmentReason = _selectedMainReason == 'Other'
            ? _otherMainReason
            : (_selectedMainReason ?? 'General consultation');

        if (providerType.contains('doctor')) {
          await MessageService.notifyDoctorOfNewAppointment(
            appointmentId: appointmentId,
            doctorId: _selectedProvider!['id'],
            patientName: patientName,
            appointmentDate: appointmentDateTime ?? DateTime.now(),
            reason: appointmentReason,
          );
        } else if (providerType.contains('chw') ||
            providerType.contains('community')) {
          await MessageService.notifyChwOfNewAppointment(
            appointmentId: appointmentId,
            chwId: _selectedProvider!['id'],
            patientName: patientName,
            appointmentDate: appointmentDateTime ?? DateTime.now(),
            reason: appointmentReason,
          );
        }
        print('✅ SIMPLE: Notification sent to service provider');
      } catch (e) {
        print('⚠️ SIMPLE: Could not send notification to provider: $e');
        // Don't fail the appointment creation if notification fails
      }

      // If from referral, update the referral document with appointment ID
      if (widget.fromReferral && _selectedProvider!['referralId'] != null) {
        try {
          await FirebaseFirestore.instance
              .collection('referrals')
              .doc(_selectedProvider!['referralId'])
              .update({
                'appointmentId': appointmentId,
                'appointmentStatus': 'booked',
                'appointmentDate': appointmentDateTime != null
                    ? Timestamp.fromDate(appointmentDateTime)
                    : FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
          print('✅ SIMPLE: Referral updated with appointment ID');
        } catch (e) {
          print('⚠️ SIMPLE: Could not update referral: $e');
          // Don't fail the appointment creation if referral update fails
        }
      }

      return appointmentId;
    } catch (e) {
      print('❌ SIMPLE: Error creating appointment: $e');
      throw Exception('Failed to create appointment record');
    }
  }

  Future<void> _linkPendingPaymentToAppointment(String appointmentId) async {
    try {
      // Get user ID from Firebase Auth or SharedPreferences (Termii login)
      String? userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null || userId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getString('user_id');
        } catch (e) {
          print('⚠️ Error reading SharedPreferences: $e');
        }
      }

      if (userId == null || userId.isEmpty) return;

      final pendingPayments = await FirebaseFirestore.instance
          .collection('pendingPayments')
          .where('patientId', isEqualTo: userId)
          .where('status', isEqualTo: 'held')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (pendingPayments.docs.isNotEmpty) {
        await pendingPayments.docs.first.reference.update({
          'appointmentId': appointmentId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ ESCROW: Pending payment linked to appointment $appointmentId');
      }
    } catch (e) {
      print('⚠️ ESCROW: Could not link pending payment: $e');
      // Don't fail appointment creation if link fails
    }
  }

  Future<bool> _processDirectFirestorePayment(
    String patientId,
    String providerId,
    double totalAmount,
    double providerShare,
    double adminShare,
  ) async {
    try {
      print(
        '💳 SIMPLE: Processing payment - Patient: $patientId, Provider: $providerId',
      );
      print(
        '💰 SIMPLE: Amounts - Total: $totalAmount, Provider: $providerShare, Admin: $adminShare',
      );

      // Check patient wallet balance
      final patientWalletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(patientId);
      final patientDoc = await patientWalletRef.get();

      double currentBalance = 0.0;
      if (patientDoc.exists && patientDoc.data() != null) {
        final balanceValue = patientDoc.data()!['balance'];
        if (balanceValue is num) {
          currentBalance = balanceValue.toDouble();
        }
      }

      print(
        '💳 SIMPLE: Patient balance: $currentBalance, required: $totalAmount',
      );

      if (currentBalance < totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Insufficient balance: \$${currentBalance.toStringAsFixed(2)} < \$${totalAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Fund Wallet',
              onPressed: () => Navigator.pushNamed(context, '/patient-wallet'),
            ),
          ),
        );
        return false;
      }

      // Prepare transaction record
      final transactionRecord = {
        'type': 'deduct',
        'amount': totalAmount,
        'description': 'Appointment booking',
        'timestamp': DateTime.now().toIso8601String(),
        'providerId': providerId,
      };

      print('🔄 SIMPLE: Starting transaction...');

      // ESCROW SYSTEM: Hold payment until consultation completed
      // Deduct from patient and hold in pendingPayments collection
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Read patient wallet
        final patientSnapshot = await transaction.get(patientWalletRef);
        final patientData = patientSnapshot.data() ?? {};
        List<dynamic> patientTransactions = List.from(
          patientData['transactions'] ?? [],
        );

        // Add deduction transaction to patient
        patientTransactions.add(transactionRecord);

        // Deduct from patient wallet
        final newBalance = currentBalance - totalAmount;
        transaction.update(patientWalletRef, {
          'balance': newBalance,
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': patientTransactions,
        });

        print('✅ ESCROW: Payment deducted from patient, funds held in escrow');
      });

      // Store payment in pendingPayments for later release
      // This will be released when consultation is completed
      await FirebaseFirestore.instance.collection('pendingPayments').add({
        'patientId': patientId,
        'providerId': providerId,
        'totalAmount': totalAmount,
        'providerShare': providerShare,
        'adminShare': adminShare,
        'status': 'held',
        'createdAt': FieldValue.serverTimestamp(),
        'paymentDate': DateTime.now().toIso8601String(),
        'description': 'Appointment booking - awaiting consultation completion',
      });

      print('✅ ESCROW: Payment stored in pendingPayments collection');
      print(
        '💡 ESCROW: Funds will be released when consultation status becomes "completed"',
      );

      return true;
    } catch (e) {
      print('❌ SIMPLE: Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  Future<void> _submitAppointment() async {
    try {
      print("🚀 Starting appointment submission...");
      // Calculate fee with free logic
      _calculatedFee = await _calculateAppointmentFeeWithFreeLogic();
      print("💰 Calculated appointment fee: $_calculatedFee");
      if (_calculatedFee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine appointment fee. Please try again.',
            ),
          ),
        );
        return;
      }
      // Defensive logging for provider and critical variables
      print('[DEBUG] _selectedProvider: $_selectedProvider');
      if (_calculatedFee! > 0) {
        // Payment step: Show simple confirmation dialog
        bool paymentSuccess = await _showPaymentDialog(_calculatedFee!);
        if (!paymentSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled. Appointment not booked.'),
            ),
          );
          return;
        }
        // Defensive checks for provider
        if (_selectedProvider == null) {
          print('[ERROR] _selectedProvider is null after payment!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No provider selected. Please select a provider and try again.',
              ),
            ),
          );
          return;
        }
        if (!_selectedProvider!.containsKey('id') ||
            _selectedProvider!['id'] == null) {
          print('[ERROR] _selectedProvider missing id: $_selectedProvider');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Provider information is incomplete. Please try again.',
              ),
            ),
          );
          return;
        }
        final providerId = _selectedProvider!['id'];
        final providerType = (_selectedProvider!['type'] ?? '')
            .toString()
            .toLowerCase();
        print('[DEBUG] providerId: $providerId, providerType: $providerType');

        // Use dynamic revenue share calculation
        final shares = await FeeConfigService.calculateShares(_calculatedFee!);
        final double providerShare = shares['providerShare']!;
        final double adminShare = shares['adminShare']!;
        print('[DEBUG] providerShare: $providerShare, adminShare: $adminShare');

        // Direct Firestore payment processing
        print(
          '[DEBUG] Processing payment directly with Firestore: $_calculatedFee',
        );

        // Get user ID from Firebase Auth or SharedPreferences (Termii login)
        String? userId = FirebaseAuth.instance.currentUser?.uid;

        if (userId == null || userId.isEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            userId = prefs.getString('user_id');
          } catch (e) {
            print('⚠️ Error reading SharedPreferences: $e');
          }
        }

        if (userId == null || userId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        bool paymentProcessed = await _processDirectFirestorePayment(
          userId,
          providerId,
          _calculatedFee!,
          providerShare,
          adminShare,
        );

        if (!paymentProcessed) {
          return; // Error already shown
        }

        print(
          '✅ Payment confirmed, wallet deducted, and revenue split. Proceeding to book appointment.',
        );

        // Show payment success dialog and inform patient
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Payment Successful'),
            content: const Text(
              'Your payment was successful! Your appointment request has been submitted. The service provider will review and confirm your appointment.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        print('✅ Free appointment. Proceeding to book appointment.');
      }

      // Now create the appointment record in Firestore
      final appointmentId = await _createSimpleAppointmentRecord();

      // If paid appointment, link the pendingPayment to this appointmentId
      if (_calculatedFee! > 0 && appointmentId != null) {
        await _linkPendingPaymentToAppointment(appointmentId);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Appointment request submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        print("🎉 Appointment submission completed successfully!");

        // Navigate back
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("💥 Error during appointment submission: $e");
      print("💥 Error type: ${e.runtimeType}");
      if (e.toString().contains('permission')) {
        print("🔒 Firebase permission error detected");
      }
      if (mounted) {
        setState(() => _isLoading = false);

        String errorMessage = 'Error submitting appointment';
        if (e.toString().contains('network')) {
          errorMessage =
              'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please contact support.';
        } else if (e.toString().contains('invalid')) {
          errorMessage =
              'Invalid data. Please check your inputs and try again.';
        } else {
          errorMessage = 'Error submitting appointment: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show persistent free appointment counter at the top
    if (_freeAppointmentsLeft != null && _freeAppointmentsLeft! <= 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_freeDialogShown && _freeAppointmentsLeft != null) {
          if (_freeAppointmentsLeft == 1) {
            _freeDialogShown = true;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text('🎉 First Appointment FREE!')),
                  ],
                ),
                content: const Text(
                  'Great news! Your first appointment with us is completely FREE! '
                  'This is our welcome gift to you.\n\n'
                  'Please note: Subsequent appointments will require payment.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Got it!'),
                  ),
                ],
              ),
            );
          } else if (_freeAppointmentsLeft == 0) {
            _freeDialogShown = true;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Payment Required'),
                content: const Text(
                  'You have used your free first appointment. '
                  'Payment is now required for new bookings.\n\n'
                  'Please ensure your wallet has sufficient funds before proceeding.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Understood'),
                  ),
                ],
              ),
            );
          }
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_freeAppointmentsLeft != null)
            Container(
              width: double.infinity,
              color: _freeAppointmentsLeft! > 0
                  ? Colors.green.shade50
                  : Colors.orange.shade100,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _freeAppointmentsLeft! > 0
                        ? Icons.celebration
                        : Icons.payment,
                    color: _freeAppointmentsLeft! > 0
                        ? Colors.green
                        : Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _freeAppointmentsLeft! > 0
                          ? '🎉 Your first appointment is FREE! No payment required.'
                          : 'Payment required for this appointment. Please ensure your wallet has sufficient funds.',
                      style: TextStyle(
                        color: _freeAppointmentsLeft! > 0
                            ? Colors.green.shade900
                            : Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Progress Indicator
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: Row(
              children: List.generate(4, (index) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4,
                    decoration: BoxDecoration(
                      color: index <= _currentPage
                          ? Colors.teal.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Page Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildProviderSelectionPage(),
                _buildPreConsultationChecklistPage(),
                _buildDateTimeSelectionPage(),
                _buildReviewAndSubmitPage(),
              ],
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            // Only require fields that are visible on the current or previous pages
                            if (_currentPage == 0) {
                              if (_selectedProvider == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a provider before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            } else if (_currentPage == 1) {
                              // Validate all mandatory fields on pre-consultation checklist page
                              if (_selectedMainReason == null ||
                                  (_selectedMainReason == 'Other' &&
                                      _otherMainReason.trim().isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select or specify your main reason for appointment.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_symptomsController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter your symptoms.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_durationController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please enter the duration of your symptoms.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedSeverity == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a severity level.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              // Add more required fields here if needed
                            } else if (_currentPage == 2) {
                              if (_selectedProvider == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a provider before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedAppointmentType == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select an appointment type before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedUrgency == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select an urgency level before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedConsultationChannel == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a consultation channel before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select an appointment date before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedTime == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select an appointment time before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (_selectedSeverity == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a severity level before proceeding.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }
                            if (_currentPage < 3) {
                              _nextPage();
                            } else {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    'Confirm Appointment Submission',
                                  ),
                                  content: const Text(
                                    'Are you sure you want to submit this appointment request?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        // Show confirmation message before actual submission
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Submitting appointment request...',
                                            ),
                                            backgroundColor: Colors.teal,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        _submitAppointment();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                      ),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_currentPage < 3 ? 'Next' : 'Submit Request'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelectionPage() {
    // If provider is locked (from referral), show only the selected provider, not the list
    if (_providerLocked && _selectedProvider != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selected Healthcare Provider',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            _buildReviewCard(
              title: _selectedProvider!['name'],
              icon: Icons.person,
              children: [
                _buildReviewRow('Type', _selectedProvider!['type']),
                _buildReviewRow(
                  'Specialization',
                  _selectedProvider!['specialization'],
                ),
                _buildReviewRow('Location', _selectedProvider!['location']),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'This provider was selected for you as part of a referral. You cannot change the provider for this booking.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    // Otherwise, show the normal provider selection UI
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Doctor or CHW',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose from available doctors and community health workers for your appointment',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For facility services (labs, scans, pharmacy), please use the Service Request option',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading healthcare providers...'),
                ],
              ),
            )
          else if (_providers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.info, size: 48, color: Colors.orange.shade700),
                  const SizedBox(height: 16),
                  Text(
                    'No Providers Available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No healthcare providers are currently available for booking. Please try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.orange.shade600),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final provider = _providers[index];
                final isSelected = _selectedProvider?['id'] == provider['id'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.teal : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected ? Colors.teal.shade50 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _selectedProvider = provider;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Provider Avatar
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.teal.shade100,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.teal
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: provider['image'] != null
                                ? ClipOval(
                                    child: Image.network(
                                      provider['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildProviderIcon(
                                                provider['type'],
                                              ),
                                    ),
                                  )
                                : _buildProviderIcon(provider['type']),
                          ),

                          const SizedBox(width: 16),

                          // Provider Information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isSelected
                                        ? Colors.teal.shade800
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getProviderTypeColor(
                                      provider['type'],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    provider['type'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  provider['specialization'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        provider['location'],
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      provider['rating'].toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        provider['availability'],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Selection Indicator
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreConsultationChecklistPage() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pre-Consultation Checklist',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please provide detailed information to help your healthcare provider prepare for your consultation',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Main Reason for Appointment (single-select)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Main Reason for Appointment *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select the main symptom or reason for consultation (Choose the most relevant one).',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ..._mainReasons.map((reason) {
                  if (reason == 'Other') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RadioListTile<String>(
                          title: const Text('Other (please specify):'),
                          value: 'Other',
                          groupValue: _selectedMainReason,
                          onChanged: (val) {
                            setState(() {
                              _selectedMainReason = val;
                              _otherMainReason = '';
                            });
                          },
                        ),
                        if (_selectedMainReason == 'Other')
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 32.0,
                              bottom: 8,
                            ),
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Please specify',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) =>
                                  setState(() => _otherMainReason = val),
                              validator: (val) {
                                if (_selectedMainReason == 'Other' &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Please specify your main reason';
                                }
                                return null;
                              },
                            ),
                          ),
                      ],
                    );
                  }
                  return RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: _selectedMainReason,
                    onChanged: (val) {
                      setState(() {
                        _selectedMainReason = val;
                        if (val != 'Other') _otherMainReason = '';
                      });
                    },
                  );
                }),
                if (_selectedMainReason == null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, top: 4),
                    child: Text(
                      'Please select a main reason',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),

            // Symptoms
            _buildTextFormField(
              controller: _symptomsController,
              label: 'Current Symptoms',
              hint: 'List all symptoms you are experiencing',
              maxLines: 3,
            ),

            // Duration
            _buildTextFormField(
              controller: _durationController,
              label: 'Duration of Symptoms',
              hint: 'How long have you been experiencing these symptoms?',
            ),

            // Severity
            _buildDropdownField(
              label: 'Severity Level',
              value: _selectedSeverity,
              items: _severityScale,
              onChanged: (value) => setState(() => _selectedSeverity = value),
            ),

            // Medications Taken
            _buildTextFormField(
              controller: _medicationsTakenController,
              label: 'Current Medications',
              hint:
                  'List any medications you are currently taking or have taken recently',
              maxLines: 2,
            ),

            // Triggers
            _buildTextFormField(
              controller: _triggersController,
              label: 'Triggers / What Makes it Worse',
              hint:
                  'Any activities, foods, or situations that worsen your condition',
              maxLines: 2,
            ),

            // Allergies
            _buildTextFormField(
              controller: _allergiesController,
              label: 'Known Allergies',
              hint:
                  'List any allergies to medications, foods, or other substances',
              maxLines: 2,
            ),

            // Medical History
            _buildTextFormField(
              controller: _medicalHistoryController,
              label: 'Relevant Medical History',
              hint: 'Previous surgeries, chronic conditions, family history',
              maxLines: 3,
            ),

            // Emergency Contact
            _buildTextFormField(
              controller: _emergencyContactController,
              label: 'Emergency Contact',
              hint: 'Name and phone number of emergency contact',
            ),

            // Additional Notes
            _buildTextFormField(
              controller: _additionalNotesController,
              label: 'Additional Notes',
              hint: 'Any other information you think might be helpful',
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // File Upload Section
            const Text(
              'Upload Lab Results or Medical Documents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload any relevant lab results, X-rays, or medical documents (PDF, JPG, PNG)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade100,
                foregroundColor: Colors.teal.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),

            if (_uploadedFileNames.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Uploaded Files:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...List.generate(_uploadedFileNames.length, (index) {
                return Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.attach_file,
                      color: Colors.teal.shade700,
                    ),
                    title: Text(_uploadedFileNames[index]),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeFile(index),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelectionPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Date & Time',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your preferred appointment date and time',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Appointment Type
          _buildDropdownField(
            label: 'Appointment Type',
            value: _selectedAppointmentType,
            items: _appointmentTypes,
            onChanged: _appointmentTypeLocked
                ? (String? _) {}
                : (String? value) =>
                      setState(() => _selectedAppointmentType = value),
            required: true,
          ),

          // Urgency Level
          _buildDropdownField(
            label: 'Urgency Level',
            value: _selectedUrgency,
            items: _urgencyLevels,
            onChanged: (value) => setState(() => _selectedUrgency = value),
            required: true,
          ),

          // Consultation Channel
          _buildDropdownField(
            label: 'Consultation Channel',
            value: _selectedConsultationChannel,
            items: _consultationChannels,
            onChanged: (value) =>
                setState(() => _selectedConsultationChannel = value),
            required: true,
          ),

          const SizedBox(height: 24),

          // Date Selection
          Card(
            child: ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.teal.shade700),
              title: const Text('Appointment Date'),
              subtitle: Text(
                _selectedDate != null
                    ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                    : 'Tap to select date',
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _selectDate,
            ),
          ),

          const SizedBox(height: 16),

          // Time Selection
          Card(
            child: ListTile(
              leading: Icon(Icons.access_time, color: Colors.teal.shade700),
              title: const Text('Appointment Time'),
              subtitle: Text(
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'Tap to select time',
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _selectTime,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReviewAndSubmitPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Your Appointment',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please review all information before submitting your appointment request',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Provider Information
          if (_selectedProvider != null)
            _buildReviewCard(
              title: 'Healthcare Provider',
              icon: Icons.person,
              children: [
                _buildReviewRow('Name', _selectedProvider!['name']),
                _buildReviewRow('Type', _selectedProvider!['type']),
                _buildReviewRow(
                  'Specialization',
                  _selectedProvider!['specialization'],
                ),
                _buildReviewRow('Location', _selectedProvider!['location']),
              ],
            ),

          // Important Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Important Notice',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Your appointment request will be reviewed by the selected healthcare provider\n'
                  '• You will receive a notification once your appointment is approved or if any changes are needed\n'
                  '• All information provided will be saved to your health records\n'
                  '• This information will be available to your healthcare provider before the consultation',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal.shade700),
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'This field is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal.shade700),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged as ValueChanged<String?>?,
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select an option';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  Widget _buildProviderIcon(String type) {
    IconData iconData;
    Color iconColor = Colors.teal.shade700;

    switch (type) {
      case 'Doctor':
        iconData = Icons.local_hospital;
        break;
      case 'Community Health Worker':
        iconData = Icons.health_and_safety;
        break;
      default:
        iconData = Icons.person;
    }

    return Icon(iconData, color: iconColor, size: 28);
  }

  Color _getProviderTypeColor(String type) {
    switch (type) {
      case 'Doctor':
        return Colors.blue.shade600;
      case 'Community Health Worker':
        return Colors.green.shade600;
      default:
        return Colors.teal.shade600;
    }
  }
}
