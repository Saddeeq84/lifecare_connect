// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityBookAppointmentScreen extends StatefulWidget {
  final String facilityId;
  final String? facilityName;
  final String? facilityType;

  const FacilityBookAppointmentScreen({
    super.key,
    required this.facilityId,
    this.facilityName,
    this.facilityType,
  });

  @override
  State<FacilityBookAppointmentScreen> createState() =>
      _FacilityBookAppointmentScreenState();
}

class _FacilityBookAppointmentScreenState
    extends State<FacilityBookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _customComplaintController = TextEditingController();
  String? _selectedPatientId;
  String? _selectedDoctorId;
  String? _selectedDepartment;
  String? _selectedDoctorType;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _dateOfBirth;
  int? _calculatedAge;
  String? _facilityName;
  bool _isLoading = false;
  bool _isLoadingFacility = true;
  List<String> _departments = [];
  String? _selectedGender;
  String? _selectedAppointmentType;
  String? _selectedMainComplaint;

  final List<String> _doctorTypes = ['Facility Doctor', 'Remote Doctor'];

  final List<String> _genderOptions = ['Male', 'Female'];

  final List<String> _appointmentTypes = ['New Patient', 'Follow Up'];

  final List<String> _mainComplaints = [
    'Fever',
    'Cough',
    'Headache',
    'Body Pain/Aches',
    'Abdominal Pain',
    'Chest Pain',
    'Difficulty Breathing',
    'Nausea/Vomiting',
    'Diarrhea',
    'Dizziness',
    'Weakness/Fatigue',
    'Malaria Symptoms',
    'High Blood Pressure',
    'Diabetes Related',
    'Skin Rash/Infection',
    'Eye Problems',
    'Ear Pain/Infection',
    'Toothache',
    'Pregnancy Related',
    'Child Vaccination',
    'General Check-up',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadFacilityInfo();
  }

  @override
  @override
  void dispose() {
    _reasonController.dispose();
    _customComplaintController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityInfo() async {
    try {
      print('📋 [BookAppointment] Loading facility info...');
      print('📋 [BookAppointment] widget.facilityId: ${widget.facilityId}');
      print('📋 [BookAppointment] widget.facilityName: ${widget.facilityName}');
      print('📋 [BookAppointment] widget.facilityType: ${widget.facilityType}');

      // First check if facility info was passed as parameters
      if (widget.facilityName != null && widget.facilityType != null) {
        print('✅ [BookAppointment] Using passed parameters');
        if (mounted) {
          setState(() {
            _facilityName = widget.facilityName;
            _isLoadingFacility = false;
          });
          await _loadDepartments();
        }
        return;
      }

      print(
        '⚠️ [BookAppointment] Parameters not complete, trying facility document...',
      );
      // Fallback: Try to get from facility document
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.facilityId)
          .get();

      if (facilityDoc.exists) {
        final data = facilityDoc.data();
        print('✅ [BookAppointment] Loaded from facility document');
        if (mounted) {
          setState(() {
            _facilityName = data?['name'] as String?;
            _isLoadingFacility = false;
          });
          await _loadDepartments();
        }
        return;
      }

      // Last fallback: Try to get from Firebase Auth user (for facility admin)
      print('⚠️ [BookAppointment] Trying Firebase Auth fallback...');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          print('✅ [BookAppointment] Loaded from Firebase Auth');
          if (mounted) {
            setState(() {
              _facilityName = data?['name'] as String?;
              _isLoadingFacility = false;
            });
            await _loadDepartments();
          }
          return;
        }
      }

      // If all fallbacks fail, still load departments
      print(
        '⚠️ [BookAppointment] All fallbacks failed, loading departments anyway',
      );
      if (mounted) {
        setState(() {
          _isLoadingFacility = false;
        });
        await _loadDepartments();
      }
    } catch (e) {
      print('❌ [BookAppointment] Error loading facility info: $e');
      if (mounted) {
        setState(() {
          _isLoadingFacility = false;
        });
        await _loadDepartments();
      }
    }
  }

  Future<void> _loadDepartments() async {
    try {
      // Fetch facility type to get correct department list (same as staff registration)
      final facilityDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.facilityId)
          .get();

      if (facilityDoc.exists) {
        final data = facilityDoc.data();
        final facilityType = data?['type'] as String?;

        if (facilityType != null) {
          // Use the same department list as staff registration form
          final departments = _getDepartmentsForFacilityType(facilityType);

          if (mounted) {
            setState(() {
              _departments = departments;
            });
          }
          return;
        }
      }

      // Fallback: Use clinic departments if facility type not found
      if (mounted) {
        setState(() {
          _departments = [
            'Out-Patient Department (OPD)',
            'Emergency Department',
            'Specialist Department',
            'Pharmacy',
            'Laboratory',
            'Nursing',
          ];
        });
      }
    } catch (e) {
      print('Error loading departments: $e');
      // Fallback on error
      if (mounted) {
        setState(() {
          _departments = [
            'Out-Patient Department (OPD)',
            'Emergency Department',
            'Specialist Department',
            'Pharmacy',
            'Laboratory',
            'Nursing',
          ];
        });
      }
    }
  }

  List<String> _getDepartmentsForFacilityType(String facilityType) {
    final facilityTypeLower = facilityType.toLowerCase().trim();

    // Hospital departments (copied from facility_departments_screen.dart)
    if (facilityTypeLower == 'hospital') {
      return [
        'Emergency Department',
        'Out-Patient Department (OPD)',
        'Inpatient Department (IPD)',
        'Intensive Care Unit (ICU)',
        'Surgery Department',
        'Pediatrics',
        'Obstetrics & Gynecology',
        'Orthopedics',
        'Cardiology',
        'Neurology',
        'Radiology',
        'Laboratory',
        'Pharmacy',
        'Public Health',
        'Specialist Department',
        'Physiotherapy',
        'Nutrition & Dietetics',
        'Dental Department',
        'Ophthalmology Department',
        'ENT Department',
        'Nursing',
      ];
    }
    // Clinic departments (copied from facility_departments_screen.dart)
    else if (facilityTypeLower == 'clinic' ||
        facilityTypeLower == 'clinic/phc') {
      return [
        'Out-Patient Department (OPD)',
        'Emergency Department',
        'Pharmacy',
        'Laboratory',
        'Nursing',
        'Public Health',
        'Specialist Department',
      ];
    }
    // Dental Clinic departments
    else if (facilityTypeLower == 'dental clinic') {
      return [
        'General Dentistry',
        'Oral Surgery',
        'Orthodontics',
        'Periodontics',
        'Pediatric Dentistry',
      ];
    }
    // Eye Clinic departments
    else if (facilityTypeLower == 'eye clinic') {
      return [
        'Ophthalmology',
        'Optometry',
        'Contact Lens Service',
        'Optical Dispensary',
        'Surgical Unit',
      ];
    }
    // Physiotherapy Center departments
    else if (facilityTypeLower == 'physiotherapy center') {
      return [
        'Orthopedic Physiotherapy',
        'Neurological Physiotherapy',
        'Sports Physiotherapy',
        'Pediatric Physiotherapy',
        'Geriatric Physiotherapy',
      ];
    }
    // Default/fallback for other facility types
    else {
      return [
        'Out-Patient Department (OPD)',
        'Specialist Department',
        'Pharmacy',
        'Laboratory',
        'Nursing',
        'Public Health',
      ];
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 30),
      ), // Default to 30 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _calculatedAge = _calculateAge(picked);
      });
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Get appointment booking fee from service management
  Future<double> _getAppointmentFee(String doctorType) async {
    try {
      final serviceDoc = await FirebaseFirestore.instance
          .collection('facility_service_prices')
          .doc(widget.facilityId)
          .get();

      if (serviceDoc.exists) {
        final data = serviceDoc.data();
        if (data != null) {
          // For remote consultations, use remote_consultation price
          if (doctorType == 'remote') {
            return (data['remote_consultation'] as num?)?.toDouble() ?? 5000.0;
          }
          // For facility doctors, use appointment_booking price
          return (data['appointment_booking'] as num?)?.toDouble() ?? 500.0;
        }
      }
      // Default fees if not configured
      return doctorType == 'remote' ? 5000.0 : 500.0;
    } catch (e) {
      print('❌ Error getting appointment fee: $e');
      return doctorType == 'remote' ? 5000.0 : 500.0;
    }
  }

  /// Check wallet balance and return wallet info
  Future<Map<String, dynamic>> _getWalletInfo(String patientId) async {
    try {
      // Get patient details to check if they're household member
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }

      final patientData = patientDoc.data()!;
      final patientType = patientData['patientType'] as String?;
      final householdId = patientData['householdId'] as String?;
      final isHouseholdMember =
          (patientType == 'household_member' || patientType == 'household') &&
          householdId != null;

      double balance = 0.0;
      String walletType = 'individual';
      String? walletId;

      if (isHouseholdMember) {
        // Check household wallet
        final walletDoc = await FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(householdId)
            .get();

        if (walletDoc.exists) {
          balance = (walletDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        }
        walletType = 'household';
        walletId = householdId;
      } else {
        // Check individual wallet
        final walletDoc = await FirebaseFirestore.instance
            .collection('wallets')
            .doc(patientId)
            .get();

        if (walletDoc.exists) {
          balance = (walletDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        }
        walletType = 'individual';
        walletId = patientId;
      }

      return {
        'balance': balance,
        'walletType': walletType,
        'walletId': walletId,
        'patientType': patientType,
        'householdId': householdId,
      };
    } catch (e) {
      print('❌ Error getting wallet info: $e');
      rethrow;
    }
  }

  /// Process payment for facility appointment (deduct from patient, credit facility)
  Future<void> _processFacilityAppointmentPayment({
    required String patientId,
    required String patientName,
    required Map<String, dynamic> walletInfo,
    required double appointmentFee,
    required String appointmentId,
  }) async {
    final walletType = walletInfo['walletType'] as String;
    final walletId = walletInfo['walletId'] as String;

    // Facility patients (both household and individual): 100% to facility
    // Use atomic transaction to ensure all updates succeed or fail together
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Deduct from patient wallet
      if (walletType == 'household') {
        final householdWalletRef = FirebaseFirestore.instance
            .collection('household_wallets')
            .doc(walletId);

        transaction.update(householdWalletRef, {
          'balance': FieldValue.increment(-appointmentFee),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        final individualWalletRef = FirebaseFirestore.instance
            .collection('wallets')
            .doc(walletId);

        transaction.update(individualWalletRef, {
          'balance': FieldValue.increment(-appointmentFee),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Credit facility wallet (100% for facility patients)
      final facilityWalletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(widget.facilityId);

      transaction.set(facilityWalletRef, {
        'balance': FieldValue.increment(appointmentFee),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // Record patient transaction
    if (walletType == 'household') {
      await FirebaseFirestore.instance
          .collection('household_wallets')
          .doc(walletId)
          .collection('transactions')
          .add({
            'type': 'debit',
            'amount': appointmentFee,
            'description': 'Appointment booking fee for $patientName',
            'patientId': patientId,
            'patientName': patientName,
            'facilityId': widget.facilityId,
            'appointmentId': appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
    } else {
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(walletId)
          .collection('transactions')
          .add({
            'type': 'debit',
            'amount': appointmentFee,
            'description': 'Appointment booking fee',
            'facilityId': widget.facilityId,
            'appointmentId': appointmentId,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'completed',
          });
    }

    // Record facility transaction
    await FirebaseFirestore.instance
        .collection('wallets')
        .doc(widget.facilityId)
        .collection('transactions')
        .add({
          'type': 'credit',
          'amount': appointmentFee,
          'description':
              'Appointment booking fee from $patientName (Facility Patient)',
          'patientId': patientId,
          'patientName': patientName,
          'appointmentId': appointmentId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
        });
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _showBookingConfirmation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date of birth'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select gender'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAppointmentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select appointment type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedAppointmentType == 'New Patient' &&
        _selectedMainComplaint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select main complaint for new patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedMainComplaint == 'Other' &&
        _customComplaintController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify the complaint'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDoctorType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select doctor type'),
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

    // Get appointment fee
    final normalizedDoctorType =
        _selectedDoctorType?.toLowerCase().trim() == 'remote doctor'
        ? 'remote'
        : 'facility';
    final appointmentFee = await _getAppointmentFee(normalizedDoctorType);

    // Get wallet info to show balance
    final walletInfo = await _getWalletInfo(_selectedPatientId!);
    final walletBalance = walletInfo['balance'] as double;
    final walletType = walletInfo['walletType'] as String;

    // Check if balance is sufficient
    if (walletBalance < appointmentFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance in ${walletType == 'household' ? 'household' : 'individual'} wallet. Required: ₦${appointmentFee.toStringAsFixed(2)}, Available: ₦${walletBalance.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    // Get patient name for display
    final patientDoc = await FirebaseFirestore.instance
        .collection('facility_patients')
        .doc(_selectedPatientId)
        .get();
    final patientName = patientDoc.data()?['name'] ?? 'Patient';

    // Get doctor name
    String doctorName = 'Unknown';
    if (_selectedDoctorType == 'Facility Doctor') {
      final staffCollection =
          '${_facilityName!.toLowerCase().replaceAll(' ', '_')}_users';
      final doctorDoc = await FirebaseFirestore.instance
          .collection(staffCollection)
          .doc(_selectedDoctorId)
          .get();
      if (doctorDoc.exists) {
        doctorName = doctorDoc.data()?['fullName'] ?? 'Unknown';
      }
    } else {
      // Remote Doctor
      final doctorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_selectedDoctorId)
          .get();
      if (doctorDoc.exists) {
        doctorName = doctorDoc.data()?['name'] ?? 'Unknown';
      }
    }

    // Format time slot
    final timeSlot = _selectedTime != null
        ? _selectedTime!.format(context)
        : '';

    // Show confirmation dialog
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.confirmation_number, color: Colors.teal),
              const SizedBox(width: 8),
              const Expanded(child: Text('Confirm Appointment')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please confirm the appointment details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 16),
                _buildConfirmationRow('Patient', patientName),
                _buildConfirmationRow('Gender', _selectedGender ?? ''),
                _buildConfirmationRow(
                  'Appointment Type',
                  _selectedAppointmentType ?? '',
                ),
                if (_selectedAppointmentType == 'New Patient' &&
                    _selectedMainComplaint != null)
                  _buildConfirmationRow(
                    'Main Complaint',
                    _selectedMainComplaint == 'Other'
                        ? _customComplaintController.text.trim()
                        : _selectedMainComplaint ?? '',
                  ),
                _buildConfirmationRow('Department', _selectedDepartment ?? ''),
                _buildConfirmationRow('Doctor Type', _selectedDoctorType ?? ''),
                _buildConfirmationRow('Doctor', doctorName),
                _buildConfirmationRow(
                  'Appointment Date',
                  _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : '',
                ),
                _buildConfirmationRow('Time Slot', timeSlot),
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: normalizedDoctorType == 'remote'
                        ? Colors.orange.shade50
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: normalizedDoctorType == 'remote'
                          ? Colors.orange.shade200
                          : Colors.teal.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: normalizedDoctorType == 'remote'
                                ? Colors.orange.shade700
                                : Colors.teal.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Payment Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: normalizedDoctorType == 'remote'
                                  ? Colors.orange.shade900
                                  : Colors.teal.shade900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Appointment Fee: ₦${appointmentFee.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Wallet Type: ${walletType == 'household' ? 'Household Wallet' : 'Individual Wallet'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Current Balance: ₦${walletBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Balance After: ₦${(walletBalance - appointmentFee).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: normalizedDoctorType == 'remote'
                              ? Colors.orange.shade100
                              : Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              normalizedDoctorType == 'remote'
                                  ? Icons.schedule
                                  : Icons.check_circle,
                              size: 16,
                              color: normalizedDoctorType == 'remote'
                                  ? Colors.orange.shade900
                                  : Colors.teal.shade900,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                normalizedDoctorType == 'remote'
                                    ? 'Payment will be processed after doctor completes consultation'
                                    : 'Payment will be processed immediately',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: normalizedDoctorType == 'remote'
                                      ? Colors.orange.shade900
                                      : Colors.teal.shade900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm & Book'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _bookAppointment();
    }
  }

  Widget _buildConfirmationRow(String label, String value) {
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
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date of birth'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a department'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDoctorType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select doctor type'),
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

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get patient details
      final patientDoc = await FirebaseFirestore.instance
          .collection('facility_patients')
          .doc(_selectedPatientId)
          .get();

      if (!patientDoc.exists) {
        throw Exception('Patient not found');
      }

      final patientData = patientDoc.data()!;
      final patientName = patientData['fullName'] ?? 'Unknown';

      // Normalize doctor type
      final normalizedDoctorType = _selectedDoctorType == 'Remote Doctor'
          ? 'remote'
          : 'facility';

      // Get appointment fee based on doctor type
      final appointmentFee = await _getAppointmentFee(normalizedDoctorType);

      // Get wallet info and check balance
      final walletInfo = await _getWalletInfo(_selectedPatientId!);
      final walletBalance = walletInfo['balance'] as double;

      // Check if balance is sufficient
      if (walletBalance < appointmentFee) {
        if (mounted) {
          final walletType = walletInfo['walletType'] as String;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient ${walletType == 'household' ? 'household' : 'individual'} wallet balance!\n'
                'Required: ₦${appointmentFee.toStringAsFixed(2)}\n'
                'Available: ₦${walletBalance.toStringAsFixed(2)}\n'
                'Please fund the wallet before booking an appointment.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Get doctor details based on doctor type
      String doctorName = 'Unknown';
      String doctorProfession = 'Doctor';

      if (_selectedDoctorType == 'Facility Doctor') {
        final staffCollection =
            '${_facilityName!.toLowerCase().replaceAll(' ', '_')}_users';
        final doctorDoc = await FirebaseFirestore.instance
            .collection(staffCollection)
            .doc(_selectedDoctorId)
            .get();

        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data()!;
          doctorName = doctorData['fullName'] ?? 'Unknown';
          doctorProfession = doctorData['profession'] ?? 'Doctor';
        }
      } else {
        // Remote Doctor
        final doctorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_selectedDoctorId)
            .get();

        if (doctorDoc.exists) {
          final doctorData = doctorDoc.data()!;
          doctorName = doctorData['name'] ?? 'Unknown';
          doctorProfession = 'Remote Doctor';
        }
      }

      // Determine the main complaint to save (use custom text if "Other" is selected)
      final mainComplaintToSave = _selectedMainComplaint == 'Other'
          ? _customComplaintController.text.trim()
          : _selectedMainComplaint;

      // Create appointment
      final appointmentRef = await FirebaseFirestore.instance.collection('appointments').add({
        'patientId': _selectedPatientId,
        'patientName': patientName,
        'dateOfBirth': Timestamp.fromDate(_dateOfBirth!),
        'age': _calculatedAge,
        'gender': _selectedGender,
        'appointmentType': _selectedAppointmentType,
        'mainComplaint':
            mainComplaintToSave, // Will be null for follow-up appointments, custom text for "Other"
        'doctorId': _selectedDoctorId,
        'providerId':
            _selectedDoctorId, // Required for doctor dashboard to query appointments
        'doctorName': doctorName,
        'assignedStaffName':
            doctorName, // For remote consultation screen compatibility
        'doctorProfession': doctorProfession,
        'doctorType': normalizedDoctorType,
        'department': _selectedDepartment,
        'facilityId': widget.facilityId,
        'facilityName': _facilityName,
        'appointmentDate': DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        ).toIso8601String(), // Store as ISO string for remote consultation screen
        'appointmentTime': _selectedTime!.format(context),
        'reason': _reasonController.text.trim(),
        'appointmentFee': appointmentFee,
        'paymentStatus': normalizedDoctorType == 'facility'
            ? 'paid'
            : 'pending', // Facility = paid immediately, Remote = pending until consultation
        'status':
            'pending', // All appointments start as 'pending' for doctor approval
        'consultationStatus': normalizedDoctorType == 'remote'
            ? 'pending'
            : null, // Remote appointments need consultation status
        'bookedBy': 'medical_records',
        'bookedById': widget.facilityId,
        'walletType':
            walletInfo['walletType'], // Required for payment processing
        'walletId': walletInfo['walletId'], // Required for payment processing
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Process payment based on doctor type
      if (normalizedDoctorType == 'facility') {
        // For facility appointments: Deduct from patient wallet and credit facility immediately
        await _processFacilityAppointmentPayment(
          patientId: _selectedPatientId!,
          patientName: patientName,
          walletInfo: walletInfo,
          appointmentFee: appointmentFee,
          appointmentId: appointmentRef.id,
        );
      }
      // For remote appointments: Payment will be processed after consultation note is saved
      // The wallet balance has been verified, but money won't be deducted yet

      if (mounted) {
        final paymentMessage = normalizedDoctorType == 'facility'
            ? '₦${appointmentFee.toStringAsFixed(2)} deducted from ${walletInfo['walletType']} wallet'
            : '₦${appointmentFee.toStringAsFixed(2)} will be charged after consultation';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Appointment booked successfully!\n$paymentMessage',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingFacility
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.teal),
                                const SizedBox(width: 8),
                                Text(
                                  'Appointment Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Patient Selection
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('facility_patients')
                                  .where(
                                    'facilityId',
                                    isEqualTo: widget.facilityId,
                                  )
                                  .snapshots(),
                              builder: (context, snapshot) {
                                print(
                                  '👥 [Patients] Querying with facilityId: ${widget.facilityId}',
                                );
                                print(
                                  '👥 [Patients] Connection state: ${snapshot.connectionState}',
                                );
                                print(
                                  '👥 [Patients] Has data: ${snapshot.hasData}',
                                );
                                print(
                                  '👥 [Patients] Doc count: ${snapshot.data?.docs.length ?? 0}',
                                );

                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const LinearProgressIndicator();
                                }

                                if (snapshot.hasError) {
                                  print(
                                    '❌ [Patients] Error: ${snapshot.error}',
                                  );
                                  return Text(
                                    'Error loading patients: ${snapshot.error}',
                                  );
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('No patients available'),
                                      Text(
                                        'Facility ID: ${widget.facilityId}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                final patients = snapshot.data!.docs;
                                print(
                                  '✅ [Patients] Found ${patients.length} patients',
                                );

                                return DropdownButtonFormField<String>(
                                  value: _selectedPatientId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Patient *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  items: patients.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      child: Text(
                                        data['fullName'] ?? 'Unknown',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPatientId = value;
                                    });
                                  },
                                  validator: (value) =>
                                      value == null ? 'Required' : null,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            // Date of Birth Selection
                            InkWell(
                              onTap: () => _selectDateOfBirth(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date of Birth *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.cake),
                                ),
                                child: Text(
                                  _dateOfBirth == null
                                      ? 'Select date of birth'
                                      : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Age Display (Auto-calculated)
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Age',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                _calculatedAge == null
                                    ? 'Will be calculated from date of birth'
                                    : '$_calculatedAge years',
                                style: TextStyle(
                                  color: _calculatedAge == null
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontWeight: _calculatedAge != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Gender Selection
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              items: _genderOptions.map((gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value;
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            // Appointment Type Selection
                            DropdownButtonFormField<String>(
                              value: _selectedAppointmentType,
                              decoration: const InputDecoration(
                                labelText: 'Appointment Type *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.medical_services),
                              ),
                              items: _appointmentTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedAppointmentType = value;
                                  // Reset main complaint when switching appointment type
                                  if (value != 'New Patient') {
                                    _selectedMainComplaint = null;
                                  }
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            // Main Complaint (Only for New Patients)
                            if (_selectedAppointmentType == 'New Patient') ...[
                              DropdownButtonFormField<String>(
                                value: _selectedMainComplaint,
                                decoration: const InputDecoration(
                                  labelText: 'Main Complaint *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.health_and_safety),
                                ),
                                items: _mainComplaints.map((complaint) {
                                  return DropdownMenuItem<String>(
                                    value: complaint,
                                    child: Text(complaint),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMainComplaint = value;
                                    // Clear custom complaint if switching away from "Other"
                                    if (value != 'Other') {
                                      _customComplaintController.clear();
                                    }
                                  });
                                },
                                validator: (value) =>
                                    _selectedAppointmentType == 'New Patient' &&
                                        value == null
                                    ? 'Required for new patients'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              // Custom Complaint Field (Only when "Other" is selected)
                              if (_selectedMainComplaint == 'Other') ...[
                                TextFormField(
                                  controller: _customComplaintController,
                                  decoration: const InputDecoration(
                                    labelText: 'Specify Complaint *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit_note),
                                    hintText: 'Enter the main complaint',
                                  ),
                                  maxLines: 2,
                                  validator: (value) =>
                                      _selectedMainComplaint == 'Other' &&
                                          (value == null ||
                                              value.trim().isEmpty)
                                      ? 'Please specify the complaint'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
                            // Department Selection
                            DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              decoration: const InputDecoration(
                                labelText: 'Select Department *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.business),
                              ),
                              items: _departments.map((dept) {
                                return DropdownMenuItem<String>(
                                  value: dept,
                                  child: Text(dept),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDepartment = value;
                                  _selectedDoctorId =
                                      null; // Reset doctor selection when department changes
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            // Doctor Type Selection
                            DropdownButtonFormField<String>(
                              value: _selectedDoctorType,
                              decoration: const InputDecoration(
                                labelText: 'Select Doctor Type *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _doctorTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDoctorType = value;
                                  _selectedDoctorId =
                                      null; // Reset doctor selection
                                });
                              },
                              validator: (value) =>
                                  value == null ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            // Helper text when department not selected (only for Facility Doctors)
                            if (_selectedDoctorType == 'Facility Doctor' &&
                                _selectedDepartment == null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Please select a department first to see available facility doctors',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Doctor Selection (Dynamic based on type and department)
                            if (_selectedDoctorType == 'Facility Doctor' &&
                                _selectedDepartment != null)
                              StreamBuilder<QuerySnapshot>(
                                stream: _facilityName == null
                                    ? null
                                    : FirebaseFirestore.instance
                                          .collection(
                                            '${_facilityName!.toLowerCase().replaceAll(' ', '_')}_users',
                                          )
                                          .snapshots(), // Get all staff first, then filter by department
                                builder: (context, snapshot) {
                                  print(
                                    '🏥 [FacilityDoctors] Querying all staff for facility',
                                  );
                                  print(
                                    '🏥 [FacilityDoctors] Selected department: $_selectedDepartment',
                                  );
                                  print(
                                    '🏥 [FacilityDoctors] Collection: ${_facilityName!.toLowerCase().replaceAll(' ', '_')}_users',
                                  );
                                  print(
                                    '🏥 [FacilityDoctors] Connection state: ${snapshot.connectionState}',
                                  );

                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const LinearProgressIndicator();
                                  }

                                  if (snapshot.hasError) {
                                    print(
                                      '❌ [FacilityDoctors] Error: ${snapshot.error}',
                                    );
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        'Error loading doctors: ${snapshot.error}',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    );
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    print(
                                      '⚠️ [FacilityDoctors] No staff found in facility',
                                    );
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: const Text(
                                        'No staff found in this facility',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }

                                  // First, filter by department (case-insensitive match)
                                  final allDocs = snapshot.data!.docs;
                                  print(
                                    '🔍 [FacilityDoctors] Total staff in facility: ${allDocs.length}',
                                  );

                                  // Log all departments to see what's in the database
                                  final allDepartments = allDocs.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return data['department'] ?? 'N/A';
                                  }).toSet();
                                  print(
                                    '📋 [FacilityDoctors] All departments in database: $allDepartments',
                                  );

                                  final staffInDepartment = allDocs.where((
                                    doc,
                                  ) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final staffDept = (data['department'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .trim();
                                    final selectedDept = _selectedDepartment!
                                        .toLowerCase()
                                        .trim();
                                    return staffDept == selectedDept;
                                  }).toList();

                                  print(
                                    '👥 [FacilityDoctors] Staff in $_selectedDepartment: ${staffInDepartment.length}',
                                  );

                                  // Then filter by profession (doctors only)
                                  final doctors = staffInDepartment.where((
                                    doc,
                                  ) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final profession =
                                        (data['profession'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    return profession == 'doctor' ||
                                        profession == 'surgeon' ||
                                        profession == 'dentist' ||
                                        profession == 'specialist';
                                  }).toList();

                                  print(
                                    '✅ [FacilityDoctors] Found ${doctors.length} doctors in $_selectedDepartment',
                                  );

                                  if (doctors.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'No doctors available in $_selectedDepartment department',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Staff members found: ${allDocs.length}, but none with doctor profession.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      _selectedDepartment,
                                    ), // Reset when department changes
                                    value:
                                        doctors.any(
                                          (doc) => doc.id == _selectedDoctorId,
                                        )
                                        ? _selectedDoctorId
                                        : null, // Only use saved value if it exists in current list
                                    decoration: InputDecoration(
                                      labelText: 'Select Facility Doctor *',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(
                                        Icons.medical_services,
                                      ),
                                      helperText:
                                          '${doctors.length} doctor(s) available in $_selectedDepartment',
                                    ),
                                    items: doctors.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      return DropdownMenuItem<String>(
                                        value: doc.id,
                                        child: Text(
                                          '${data['fullName'] ?? 'Unknown'} (${data['profession'] ?? 'Doctor'})',
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDoctorId = value;
                                      });
                                    },
                                    validator: (value) =>
                                        value == null ? 'Required' : null,
                                  );
                                },
                              )
                            else if (_selectedDoctorType == 'Remote Doctor')
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .where('role', isEqualTo: 'doctor')
                                    .where('isApproved', isEqualTo: true)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  print(
                                    '🌐 [RemoteDoctors] Querying remote doctors',
                                  );
                                  print(
                                    '🌐 [RemoteDoctors] Connection state: ${snapshot.connectionState}',
                                  );
                                  print(
                                    '🌐 [RemoteDoctors] Note: Remote doctors are not department-specific',
                                  );

                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const LinearProgressIndicator();
                                  }

                                  if (snapshot.hasError) {
                                    print(
                                      '❌ [RemoteDoctors] Error: ${snapshot.error}',
                                    );
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        'Error loading remote doctors: ${snapshot.error}',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    );
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty) {
                                    print(
                                      '⚠️ [RemoteDoctors] No remote doctors found',
                                    );
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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

                                  // Show all remote doctors - they are not department-specific
                                  final doctors = snapshot.data!.docs;
                                  print(
                                    '✅ [RemoteDoctors] Found ${doctors.length} remote doctors',
                                  );

                                  return DropdownButtonFormField<String>(
                                    key: const ValueKey('remote_doctors'),
                                    value: _selectedDoctorId,
                                    decoration: const InputDecoration(
                                      labelText: 'Remote Doctor *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: doctors.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      return DropdownMenuItem<String>(
                                        value: doc.id,
                                        child: Text(
                                          'Dr. ${data['name'] ?? data['fullName'] ?? 'Unknown'} - ${data['specialization'] ?? 'General'}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      print(
                                        '🔄 [RemoteDoctors] Doctor selected: $value',
                                      );
                                      setState(() {
                                        _selectedDoctorId = value;
                                        print(
                                          '✅ [RemoteDoctors] _selectedDoctorId updated to: $_selectedDoctorId',
                                        );
                                      });
                                    },
                                    validator: (value) =>
                                        value == null ? 'Required' : null,
                                  );
                                },
                              ),
                            const SizedBox(height: 16),
                            // Date Selection
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Appointment Date *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _selectedDate == null
                                      ? 'Select date'
                                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Time Selection
                            InkWell(
                              onTap: () => _selectTime(context),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Appointment Time *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(
                                  _selectedTime == null
                                      ? 'Select time'
                                      : _selectedTime!.format(context),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Reason
                            TextFormField(
                              controller: _reasonController,
                              decoration: const InputDecoration(
                                labelText: 'Reason for Visit *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.notes),
                              ),
                              maxLines: 3,
                              validator: (value) =>
                                  value?.trim().isEmpty ?? true
                                  ? 'Required'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _showBookingConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Book Appointment',
                              style: TextStyle(
                                fontSize: 16,
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
}
