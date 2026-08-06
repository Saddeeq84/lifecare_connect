// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print, unused_import, unused_element, use_key_in_widget_constructors, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/data/services/consultation_service.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/data/models/appointment.dart';
import '../../../shared/helpers/chw_message_helper.dart';
import '../../../../core/services/fee_config_service.dart';

class CHWAppointmentsScreen extends StatelessWidget {
  final int initialTab;
  const CHWAppointmentsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final chwUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab > 1 ? 1 : initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CHW Appointments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending Requests'),
              Tab(text: 'Approved Appointments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Pending Requests Tab
            _buildAppointmentsList(context, chwUid, 'pending'),
            // Approved Appointments Tab
            _buildAppointmentsList(context, chwUid, 'approved'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: Icon(Icons.add),
          label: Text('Book Appointment'),
          backgroundColor: Colors.teal,
          onPressed: () async {
            // Navigate to the doctor search screen, filtered to doctors only
            // Reuse NewConversationScreen with doctor filter, or a similar doctor selector
            final selectedDoctor = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _DoctorSelectorForBooking(),
              ),
            );
            if (selectedDoctor != null) {
              // After doctor is selected, navigate to the booking flow
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      _BookAppointmentWithDoctorScreen(doctor: selectedDoctor),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// Move these widget classes to top-level
class _DoctorSelectorForBooking extends StatefulWidget {
  @override
  State<_DoctorSelectorForBooking> createState() =>
      _DoctorSelectorForBookingState();
}

class _DoctorSelectorForBookingState extends State<_DoctorSelectorForBooking> {
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = false;
  final _searchController = TextEditingController();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _searchDoctors();
  }

  Future<void> _searchDoctors() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor');
      final snapshot = await query.get();
      final searchTerm = _searchController.text.trim().toLowerCase();
      final doctors = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final isApproved = data['isApproved'] == null
                ? true
                : data['isApproved'] == true;
            final isRejected = data['isRejected'] == true;
            return {
              'id': doc.id,
              'name':
                  data['fullName'] ??
                  data['name'] ??
                  '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
              'role': data['role'] ?? 'doctor',
              'email': data['email'] ?? '',
              'phone': data['phone'] ?? '',
              'isApproved': isApproved,
              'isRejected': isRejected,
            };
          })
          .where(
            (doctor) =>
                doctor['isApproved'] == true && doctor['isRejected'] == false,
          )
          .where((doctor) {
            if (doctor['id'] == _currentUserId) return false;
            if (searchTerm.isEmpty) return true;
            final name = (doctor['name'] ?? '').toLowerCase();
            final email = (doctor['email'] ?? '').toLowerCase();
            final phone = (doctor['phone'] ?? '').toLowerCase();
            return name.contains(searchTerm) ||
                email.contains(searchTerm) ||
                phone.contains(searchTerm);
          })
          .toList();
      debugPrint('Doctor list loaded: count = ���[33m${doctors.length}���[0m');
      if (doctors.isEmpty) {
        debugPrint('No doctors found. Check isApproved field in Firestore.');
      }
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching doctors: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Doctor'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => _searchDoctors(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _doctors.isEmpty
                ? Center(child: Text('No doctors found.'))
                : ListView.separated(
                    itemCount: _doctors.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doctor = _doctors[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            doctor['name'].isNotEmpty
                                ? doctor['name'][0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(doctor['name']),
                        subtitle: Text(doctor['role'].toString().toUpperCase()),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () => Navigator.pop(context, doctor),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BookAppointmentWithDoctorScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;
  const _BookAppointmentWithDoctorScreen({required this.doctor});

  @override
  State<_BookAppointmentWithDoctorScreen> createState() =>
      _BookAppointmentWithDoctorScreenState();
}

class _BookAppointmentWithDoctorScreenState
    extends State<_BookAppointmentWithDoctorScreen> {
  String? _selectedPatientId;
  String? _selectedPatientName;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoadingPatients = false;
  int? _freeAppointmentsLeft;
  int _chwFreeQuota = 3; // Default value
  double _chwBookingFee = 2000.0; // Default value

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _checkFreeAppointments();
    _loadFeeConfig();
  }

  Future<void> _loadFeeConfig() async {
    try {
      final quota = await FeeConfigService.getCHWFreeQuota();
      final fee = await FeeConfigService.getCHWDoctorBookingFee();
      setState(() {
        _chwFreeQuota = quota;
        _chwBookingFee = fee;
      });
    } catch (e) {
      print('Error loading fee config: $e');
    }
  }

  Future<void> _checkFreeAppointments() async {
    final chw = FirebaseAuth.instance.currentUser;
    if (chw == null) return;
    try {
      // Get dynamic CHW free quota
      final quota = await FeeConfigService.getCHWFreeQuota();

      // Count appointments created by this CHW (where patientId == chwUid)
      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: chw.uid)
          .get();
      final count = snapshot.docs.length;
      setState(() {
        _freeAppointmentsLeft = count < quota ? quota - count : 0;
      });
    } catch (e) {
      print('Error checking free appointments: $e');
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoadingPatients = true;
    });
    try {
      final chw = FirebaseAuth.instance.currentUser;
      if (chw == null) return;
      final Set<String> patientIds = <String>{};

      // 1. Patients registered by this CHW
      final registered = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where('createdBy', isEqualTo: chw.uid)
          .get();
      for (final doc in registered.docs) {
        patientIds.add(doc.id);
      }

      // 2. Patients from appointments approved/consulted by this CHW
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: chw.uid)
          .where('status', whereIn: ['approved', 'completed'])
          .get();
      for (final doc in appointments.docs) {
        final data = doc.data();
        if (data['relatedPatientId'] != null) {
          patientIds.add(data['relatedPatientId']);
        }
        if (data['patientId'] != null) patientIds.add(data['patientId']);
      }

      // 3. Patients from referrals made by this CHW
      final referrals = await FirebaseFirestore.instance
          .collection('referrals')
          .where('referredById', isEqualTo: chw.uid)
          .get();
      for (final doc in referrals.docs) {
        final data = doc.data();
        if (data['patientId'] != null) patientIds.add(data['patientId']);
      }

      // 4. Patients from consultations by this CHW
      final consultations = await FirebaseFirestore.instance
          .collection('consultations')
          .where('createdBy', isEqualTo: chw.uid)
          .get();
      for (final doc in consultations.docs) {
        final data = doc.data();
        if (data['patientId'] != null) patientIds.add(data['patientId']);
      }

      // If no interactions found, return empty result
      if (patientIds.isEmpty) {
        setState(() {
          _patients = [];
          _isLoadingPatients = false;
        });
        return;
      }

      // Get all patients that match these IDs
      final List<Map<String, dynamic>> patients = [];
      const int batchSize = 10;
      final idsList = patientIds.toList();
      for (int i = 0; i < idsList.length; i += batchSize) {
        final batch = idsList.sublist(
          i,
          i + batchSize > idsList.length ? idsList.length : i + batchSize,
        );
        final batchQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in batchQuery.docs) {
          final data = doc.data();
          patients.add({
            'id': doc.id,
            'name':
                data['fullName'] ??
                data['name'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          });
        }
      }
      setState(() {
        _patients = patients;
        _isLoadingPatients = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPatients = false;
      });
    }
  }

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  // Patient demographic fields (for walk-in patients not in the system)
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  String? _patientSex;

  // Pre-consultation checklist fields
  // Main Reason for Appointment (dropdown list like patient form)
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

  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  String? _severity;
  final TextEditingController _medicationsTakenController =
      TextEditingController();
  final TextEditingController _triggersController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicalHistoryController =
      TextEditingController();

  // Payment variables
  double? _calculatedFee;
  String? _paymentStatus;
  String? _paymentMethod;

  @override
  void dispose() {
    _reasonController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _symptomsController.dispose();
    _durationController.dispose();
    _medicationsTakenController.dispose();
    _triggersController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _calculateFee() async {
    final chw = FirebaseAuth.instance.currentUser;
    if (chw == null) return;

    // Get dynamic quota and fee
    final quota = await FeeConfigService.getCHWFreeQuota();

    // Check free appointments count
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: chw.uid)
        .get();
    final count = snapshot.docs.length;

    if (count < quota) {
      _calculatedFee = 0.0;
      _paymentStatus = 'free';
      _paymentMethod = 'none';
    } else {
      _calculatedFee = await FeeConfigService.getCHWDoctorBookingFee();
      _paymentStatus = 'pending';
      _paymentMethod = 'wallet';
    }
  }

  Future<bool> _processPayment() async {
    if (_calculatedFee == null || _calculatedFee! <= 0) {
      _paymentStatus = 'free';
      _paymentMethod = 'none';
      return true;
    }

    final chw = FirebaseAuth.instance.currentUser;
    if (chw == null) return false;

    try {
      // Check wallet balance
      final walletRef = FirebaseFirestore.instance
          .collection('wallets')
          .doc(chw.uid);
      final walletDoc = await walletRef.get();

      double currentBalance = 0.0;
      if (walletDoc.exists && walletDoc.data() != null) {
        final balanceValue = walletDoc.data()!['balance'];
        if (balanceValue is num) {
          currentBalance = balanceValue.toDouble();
        }
      }

      if (currentBalance < _calculatedFee!) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Insufficient balance: ₦${currentBalance.toStringAsFixed(2)} < ₦${_calculatedFee!.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Fund Wallet',
                onPressed: () {
                  // Navigate to wallet screen if available
                },
              ),
            ),
          );
        }
        return false;
      }

      // Deduct from CHW wallet and hold in escrow (pendingPayments)
      final totalAmount = _calculatedFee!;
      final providerId = widget.doctor['id'];

      // Use dynamic revenue share calculation
      final shares = await FeeConfigService.calculateShares(totalAmount);
      final providerShare = shares['providerShare']!;
      final adminShare = shares['adminShare']!;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final walletSnapshot = await transaction.get(walletRef);
        final walletData = walletSnapshot.data() ?? {};
        final balance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;

        if (balance < totalAmount) {
          throw Exception('Insufficient funds');
        }

        List<dynamic> transactions = List.from(
          walletData['transactions'] ?? [],
        );
        transactions.add({
          'type': 'deduct',
          'amount': totalAmount,
          'description': 'Appointment booking',
          'timestamp': DateTime.now().toIso8601String(),
          'providerId': providerId,
        });

        transaction.update(walletRef, {
          'balance': balance - totalAmount,
          'updatedAt': FieldValue.serverTimestamp(),
          'transactions': transactions,
        });
      });

      // Store in pendingPayments for release after consultation
      await FirebaseFirestore.instance.collection('pendingPayments').add({
        'patientId': chw.uid,
        'providerId': providerId,
        'totalAmount': totalAmount,
        'providerShare': providerShare,
        'adminShare': adminShare,
        'status': 'held',
        'createdAt': FieldValue.serverTimestamp(),
        'paymentDate': DateTime.now().toIso8601String(),
        'description':
            'CHW appointment booking - awaiting consultation completion',
      });

      _paymentStatus = 'paid';
      _paymentMethod = 'wallet';
      return true;
    } catch (e) {
      print('Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate main reason selection
    if (_selectedMainReason == null ||
        (_selectedMainReason == 'Other' && _otherMainReason.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select or specify the main reason for appointment',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select date and time')));
      return;
    }
    final chw = FirebaseAuth.instance.currentUser;
    if (chw == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Calculate fee
      await _calculateFee();

      // Process payment if required
      if (_calculatedFee! > 0) {
        final paymentSuccess = await _processPayment();
        if (!paymentSuccess) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final appointmentDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Prepare main complaint (from dropdown or "Other" text input)
      String? mainComplaint;
      if (_selectedMainReason != null) {
        mainComplaint = _selectedMainReason == 'Other'
            ? _otherMainReason.trim()
            : _selectedMainReason;
      }

      // Prepare pre-consultation data
      final preConsultationData = {
        if (mainComplaint != null && mainComplaint.isNotEmpty)
          'mainComplaint': mainComplaint,
        if (_symptomsController.text.trim().isNotEmpty)
          'symptoms': _symptomsController.text.trim(),
        if (_durationController.text.trim().isNotEmpty)
          'duration': _durationController.text.trim(),
        if (_severity != null) 'severity': _severity,
        if (_medicationsTakenController.text.trim().isNotEmpty)
          'medicationsTaken': _medicationsTakenController.text.trim(),
        if (_triggersController.text.trim().isNotEmpty)
          'triggers': _triggersController.text.trim(),
        if (_allergiesController.text.trim().isNotEmpty)
          'allergies': _allergiesController.text.trim(),
        if (_medicalHistoryController.text.trim().isNotEmpty)
          'medicalHistory': _medicalHistoryController.text.trim(),
      };

      // Prepare patient demographics (for walk-in patients)
      final patientDemographics = {
        if (_patientNameController.text.trim().isNotEmpty)
          'name': _patientNameController.text.trim(),
        if (_patientAgeController.text.trim().isNotEmpty)
          'age': _patientAgeController.text.trim(),
        if (_patientSex != null) 'sex': _patientSex,
      };

      final appointmentData = {
        'patientId': chw.uid,
        'patientName': chw.displayName ?? 'CHW',
        'patientUid': chw.uid,
        'providerId': widget.doctor['id'],
        'providerName': widget.doctor['name'],
        'providerType': 'doctor',
        'status': 'pending',
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'appointmentType': 'Doctor Consultation',
        'reason': _reasonController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'amount': _calculatedFee ?? 0.0,
        'paymentStatus': _paymentStatus ?? 'free',
        'paymentMethod': _paymentMethod ?? 'none',
        if (preConsultationData.isNotEmpty)
          'preConsultationData': preConsultationData,
        if (patientDemographics.isNotEmpty)
          'walkInPatientData': patientDemographics,
        if (_selectedPatientId != null) ...{
          'relatedPatientId': _selectedPatientId,
          'relatedPatientName': _selectedPatientName,
        },
      };

      final appointmentRef = await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      // Link payment to appointment if paid
      if (_calculatedFee! > 0 && _paymentStatus == 'paid') {
        final pendingPayments = await FirebaseFirestore.instance
            .collection('pendingPayments')
            .where('patientId', isEqualTo: chw.uid)
            .where('providerId', isEqualTo: widget.doctor['id'])
            .where('status', isEqualTo: 'held')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        if (pendingPayments.docs.isNotEmpty) {
          await pendingPayments.docs.first.reference.update({
            'appointmentId': appointmentRef.id,
            'linkedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Send in-app notification to doctor about new CHW appointment request
      try {
        final patientDisplayName =
            _selectedPatientName ??
            patientDemographics['name'] ??
            'Walk-in Patient';

        await MessageService.notifyDoctorOfCHWAppointment(
          appointmentId: appointmentRef.id,
          doctorId: widget.doctor['id'],
          chwId: chw.uid,
          patientName: patientDisplayName,
          appointmentDate: appointmentDate,
          reason: _reasonController.text.trim().isNotEmpty
              ? _reasonController.text.trim()
              : mainComplaint ?? 'General consultation',
        );
        print('✅ Doctor notified about CHW appointment request');
      } catch (e) {
        print('⚠️ Could not notify doctor: $e');
        // Don't fail appointment creation if notification fails
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _calculatedFee! > 0
                  ? 'Appointment booked! ₦${_calculatedFee!.toStringAsFixed(0)} paid from wallet.'
                  : 'Free appointment booked successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('Error creating appointment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Appointment'),
        backgroundColor: Colors.teal,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Booking with Dr. ${widget.doctor['name']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),

              // Free appointments indicator
              if (_freeAppointmentsLeft != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _freeAppointmentsLeft! > 0
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _freeAppointmentsLeft! > 0
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _freeAppointmentsLeft! > 0
                            ? Icons.celebration
                            : Icons.payment,
                        color: _freeAppointmentsLeft! > 0
                            ? Colors.green
                            : Colors.orange,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _freeAppointmentsLeft! > 0
                              ? 'Free appointments left: $_freeAppointmentsLeft of $_chwFreeQuota'
                              : 'Payment required: ₦${_chwBookingFee.toStringAsFixed(0)} per appointment',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 16),

              // Related Patient Selector
              Text(
                'Patient Selection',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 8),
              _isLoadingPatients
                  ? Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedPatientId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select registered patient (optional)',
                        helperText:
                            'Choose if booking for a registered patient. Leave empty for walk-in patients.',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Walk-in patient (not registered)'),
                        ),
                        ..._patients.map(
                          (p) => DropdownMenuItem<String>(
                            value: p['id'],
                            child: Text(
                              p['fullName'] ?? p['name'] ?? 'Unnamed Patient',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedPatientId = val;
                          _selectedPatientName = val != null
                              ? _patients.firstWhere(
                                      (p) => p['id'] == val,
                                      orElse: () => {
                                        'fullName': null,
                                        'name': null,
                                      },
                                    )['fullName'] ??
                                    _patients.firstWhere(
                                      (p) => p['id'] == val,
                                      orElse: () => {
                                        'fullName': null,
                                        'name': null,
                                      },
                                    )['name'] ??
                                    'Unnamed Patient'
                              : null;
                        });
                      },
                    ),
              SizedBox(height: 20),

              // Walk-in Patient Demographics (only if no patient selected)
              if (_selectedPatientId == null) ...[
                Text(
                  'Walk-in Patient Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _patientNameController,
                  decoration: InputDecoration(
                    labelText: 'Patient Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: _selectedPatientId == null
                      ? (v) => v == null || v.trim().isEmpty
                            ? 'Please enter patient name'
                            : null
                      : null,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _patientAgeController,
                        decoration: InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        keyboardType: TextInputType.number,
                        validator: _selectedPatientId == null
                            ? (v) => v == null || v.trim().isEmpty
                                  ? 'Enter age'
                                  : null
                            : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _patientSex,
                        decoration: InputDecoration(
                          labelText: 'Sex',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.wc),
                        ),
                        items: [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                        ],
                        onChanged: (val) => setState(() => _patientSex = val),
                        validator: _selectedPatientId == null
                            ? (v) => v == null ? 'Select sex' : null
                            : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],

              // Pre-Consultation Checklist
              Text(
                'Pre-Consultation Checklist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Main Reason for Appointment *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              SizedBox(height: 8),
              ..._mainReasons.map((reason) {
                if (reason == 'Other') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RadioListTile<String>(
                        title: const Text('Other (please specify):'),
                        value: 'Other',
                        groupValue: _selectedMainReason,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
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
                            right: 8,
                          ),
                          child: TextFormField(
                            initialValue: _otherMainReason,
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
                  dense: true,
                  contentPadding: EdgeInsets.zero,
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
                  padding: EdgeInsets.only(left: 8.0, top: 4, bottom: 8),
                  child: Text(
                    'Please select a main reason',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                controller: _symptomsController,
                decoration: InputDecoration(
                  labelText: 'Symptoms',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sick),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Duration (e.g., 3 days, 1 week)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning),
                ),
                items: [
                  DropdownMenuItem(value: 'Mild', child: Text('Mild')),
                  DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                  DropdownMenuItem(value: 'Severe', child: Text('Severe')),
                ],
                onChanged: (val) => setState(() => _severity = val),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _medicationsTakenController,
                decoration: InputDecoration(
                  labelText: 'Medications Taken (if any)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _allergiesController,
                decoration: InputDecoration(
                  labelText: 'Known Allergies',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.warning_amber),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _triggersController,
                decoration: InputDecoration(
                  labelText: 'Triggers / What Makes it Worse',
                  hintText:
                      'Any activities, foods, or situations that worsen the condition',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flash_on),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _medicalHistoryController,
                decoration: InputDecoration(
                  labelText: 'Relevant Medical History',
                  hintText:
                      'Previous surgeries, chronic conditions, family history',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.history),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),

              // Appointment Reason
              Text(
                'Appointment Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Additional Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),

              // Date and Time Selection
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      ),
                      onPressed: _pickDate,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.access_time),
                      label: Text(
                        _selectedTime == null
                            ? 'Select Time'
                            : _selectedTime!.format(context),
                      ),
                      onPressed: _pickTime,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Submit Button
              Center(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : submit,
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Book Appointment',
                          style: TextStyle(fontSize: 16),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildAppointmentsList(
  BuildContext context,
  String chwUid,
  String status,
) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('appointments')
        .where('providerId', isEqualTo: chwUid)
        .where('status', isEqualTo: status)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }
      final appointments = snapshot.data?.docs ?? [];
      if (appointments.isEmpty) {
        String label;
        if (status == 'pending') {
          label = 'pending requests';
        } else if (status == 'approved') {
          label = 'approved appointments';
        } else if (status == 'completed') {
          label = 'completed appointments';
        } else {
          label = 'appointments';
        }
        return Center(child: Text('No $label'));
      }
      return ListView.builder(
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final doc = appointments[index];
          final data = doc.data() as Map<String, dynamic>;
          final appointmentDate = (data['appointmentDate'] as Timestamp)
              .toDate();
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _getStatusColor(status),
            child: ExpansionTile(
              title: Text(data['patientName'] ?? 'Unknown Patient'),
              subtitle: Text(
                'Date: ${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}',
              ),
              children: [
                if (data['preConsultationData'] != null)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.assignment_turned_in,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pre-Consultation Information Available',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patient has submitted pre-consultation information. Review it before making a decision.',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text(
                            'Review Checklist',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () => _showPreConsultationDetails(
                            context,
                            data['preConsultationData'] as Map<String, dynamic>,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 12,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please review the patient\'s pre-consultation checklist (if submitted) before approving or declining this appointment.',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending') ...[
                      ElevatedButton(
                        onPressed: () => _showApproveDialog(context, doc.id),
                        child: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showRescheduleDialog(context, doc),
                        child: const Text('Reschedule'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showDenyDialog(context, doc.id),
                        child: const Text('Deny'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'approved') ...[
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showRescheduleDialog(context, doc),
                      ),
                    ],
                    if (status == 'completed')
                      Icon(Icons.check_circle, color: Colors.blue),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildInfoCard(String label, String value) {
  // Icon mapping for different fields
  IconData getIcon(String label) {
    if (label.contains('Type')) return Icons.category;
    if (label.contains('Date')) return Icons.calendar_today;
    if (label.contains('Method') || label.contains('Channel')) {
      return Icons.phone_in_talk;
    }
    if (label.contains('Complaint') || label.contains('Main')) {
      return Icons.healing;
    }
    if (label.contains('Symptom')) return Icons.sick;
    if (label.contains('Duration')) return Icons.access_time;
    if (label.contains('Severity')) return Icons.priority_high;
    if (label.contains('Medication')) return Icons.medication;
    if (label.contains('Allerg')) return Icons.warning;
    if (label.contains('History')) return Icons.history;
    if (label.contains('Trigger')) return Icons.flash_on;
    if (label.contains('Note')) return Icons.note;
    if (label.contains('Name')) return Icons.person;
    if (label.contains('Age')) return Icons.cake;
    if (label.contains('Sex')) return Icons.wc;
    return Icons.info;
  }

  // Color mapping for different fields
  MaterialColor getColor(String label) {
    if (label.contains('Type')) return Colors.purple;
    if (label.contains('Date')) return Colors.blue;
    if (label.contains('Method') || label.contains('Channel')) {
      return Colors.teal;
    }
    if (label.contains('Complaint') || label.contains('Main')) {
      return Colors.red;
    }
    if (label.contains('Symptom')) return Colors.orange;
    if (label.contains('Duration')) return Colors.indigo;
    if (label.contains('Severity')) return Colors.deepOrange;
    if (label.contains('Medication')) return Colors.green;
    if (label.contains('Allerg')) return Colors.amber;
    if (label.contains('History')) return Colors.blueGrey;
    if (label.contains('Trigger')) return Colors.pink;
    if (label.contains('Note')) return Colors.grey;
    if (label.contains('Name')) return Colors.cyan;
    if (label.contains('Age')) return Colors.lime;
    if (label.contains('Sex')) return Colors.lightBlue;
    return Colors.blue;
  }

  final color = getColor(label);
  final icon = getIcon(label);

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3), width: 1.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color.shade800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

String _formatAppointmentDate(dynamic dateValue) {
  if (dateValue == null) return '';

  try {
    DateTime date;

    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is DateTime) {
      date = dateValue;
    } else if (dateValue is String) {
      // Try to parse string date
      date = DateTime.parse(dateValue);
    } else {
      return dateValue.toString();
    }

    // Format as "30th Dec, 2025"
    final day = date.day;
    final suffix = _getDaySuffix(day);
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[date.month - 1];
    final year = date.year;

    return '$day$suffix $month, $year';
  } catch (e) {
    return dateValue.toString();
  }
}

String _getDaySuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

void _showPreConsultationDetails(
  BuildContext context,
  Map<String, dynamic> checklistData,
) {
  // Support both top-level and nested (healthAssessment/data) structures
  Map<String, dynamic> data = checklistData;
  if (data.containsKey('healthAssessment') &&
      data['healthAssessment'] is Map<String, dynamic>) {
    data = {...data, ...data['healthAssessment']};
  } else if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
    data = {...data, ...data['data']};
    if (data.containsKey('healthAssessment') &&
        data['healthAssessment'] is Map<String, dynamic>) {
      data = {...data, ...data['healthAssessment']};
    }
  }

  final fields = <String, String?>{
    'Appointment Type': data['appointmentType'] ?? data['type'],
    'Appointment Date': _formatAppointmentDate(data['appointmentDate']),
    'Consultation Method': data['consultationChannel'] ?? data['channel'],
    'Main Complaint': data['mainComplaint'] ?? data['reason'],
    'Symptoms': data['symptoms'],
    'Duration': data['duration'],
    'Severity': data['severity'],
    'Current Medications':
        data['medications'] ??
        data['currentMedications'] ??
        data['medicationsTaken'],
    'Allergies': data['allergies'],
    'Medical History': data['medicalHistory'],
    'Triggers': data['triggers'],
    'Additional Notes':
        data['additionalNotes'] ?? data['notes'] ?? data['reason'],
    'Patient Name': data['patientName'] ?? data['name'],
    'Patient Age': data['patientAge'] ?? data['age'],
    'Patient Sex': data['patientSex'] ?? data['sex'],
  };

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.medical_information,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pre-Consultation Checklist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: fields.entries
                        .where(
                          (entry) =>
                              entry.value != null &&
                              entry.value.toString().trim().isNotEmpty,
                        )
                        .map((entry) => _buildInfoCard(entry.key, entry.value!))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

List<Widget> _buildPreConsultationDetails(Map<String, dynamic> checklist) {
  final List<Widget> items = [];
  checklist.forEach((key, value) {
    if (value != null && value.toString().isNotEmpty) {
      items.add(Text('$key: $value', style: TextStyle(fontSize: 13)));
    }
  });
  return items;
}

void _showApproveDialog(BuildContext context, String appointmentId) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Approve Appointment'),
      content: const Text('Are you sure you want to approve this appointment?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _approveAppointment(context, appointmentId);
            Navigator.pop(context);
            // ...existing code...
          },
          child: const Text('Approve'),
        ),
      ],
    ),
  );
}

void _showDenyDialog(BuildContext context, String appointmentId) {
  final reasonController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Deny Appointment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please provide a reason for denial:'),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _denyAppointment(
              context,
              appointmentId,
              reasonController.text.trim(),
            );
            Navigator.pop(context);
            // Message to patient about denial is already handled in _denyAppointment
          },
          child: const Text('Deny'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ],
    ),
  );
}

void _showRescheduleDialog(BuildContext context, QueryDocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  DateTime selectedDate = (data['appointmentDate'] as Timestamp).toDate();
  TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reschedule Appointment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _rescheduleAppointment(
                  context,
                  doc.id,
                  selectedDate,
                  selectedTime,
                ),
                child: const Text('Reschedule'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _rescheduleAppointment(
  BuildContext context,
  String appointmentId,
  DateTime date,
  TimeOfDay time,
) async {
  final newDateTime = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );

  try {
    // Fetch appointment details for notification
    final appointmentDoc = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get();

    final appointmentData = appointmentDoc.data();

    // Update appointment date
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({
          'appointmentDate': Timestamp.fromDate(newDateTime),
          'rescheduledAt': FieldValue.serverTimestamp(),
          'rescheduledBy': 'chw',
        });

    // Notify patient about reschedule
    if (appointmentData != null && appointmentData['patientId'] != null) {
      final dateStr =
          '${newDateTime.day}/${newDateTime.month}/${newDateTime.year}';
      final timeStr =
          '${newDateTime.hour.toString().padLeft(2, '0')}:${newDateTime.minute.toString().padLeft(2, '0')}';

      await CHWMessageHelper.sendPatientMessageToId(
        appointmentData['patientId'],
        appointmentId,
        '🔄 Your appointment has been RESCHEDULED by the Community Health Worker.\n\n'
        '📅 New Date & Time: $dateStr at $timeStr\n\n'
        '⏰ PLEASE BE PUNCTUAL: Join the consultation ON TIME at the new scheduled time.\n\n'
        '📱 HOW TO JOIN:\n'
        '1. Go to "Appointments" tab\n'
        '2. Find your appointment under "Pending Consultations"\n'
        '3. Click on the Video 📹, Audio 🎤, or Chat 💬 icon at the scheduled time\n\n'
        'If this time doesn\'t work for you, please book a new appointment.\n\n'
        'Thank you for your understanding!',
      );
    }

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment rescheduled and patient notified'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rescheduling: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _approveAppointment(
  BuildContext context,
  String appointmentId,
) async {
  try {
    // Update appointment status to approved
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'approved'});

    // Fetch appointment details
    final appointmentDoc = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get();
    if (!appointmentDoc.exists) throw Exception('Appointment not found');
    final appointment = Appointment.fromFirestore(appointmentDoc);

    // Create consultation if not already exists for this appointment
    final existingConsultations = await FirebaseFirestore.instance
        .collection('consultations')
        .where('appointmentId', isEqualTo: appointmentId)
        .get();
    if (existingConsultations.docs.isEmpty) {
      await ConsultationService.createConsultation(
        patientId: appointment.patientId,
        patientName: appointment.patientName,
        doctorId: appointment.providerId,
        doctorName: appointment.providerName,
        facilityId: appointment.facilityId,
        facilityName: appointment.facilityName,
        type: appointment.appointmentType,
        reason: appointment.reason,
        chiefComplaint: appointment.notes,
        scheduledDateTime: appointment.appointmentDate,
        estimatedDurationMinutes: 30,
        priority: 'routine',
        referralId: null,
        appointmentId: appointment.id,
        notes: appointment.notes,
        createdBy: appointment.providerId,
      );
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment approved'),
          backgroundColor: Colors.green,
        ),
      );
    }
    // Always send message to patient about approval
    // Format appointment date and time
    String appointmentInfo = '';
    try {
      final dateStr =
          '${appointment.appointmentDate.day}/${appointment.appointmentDate.month}/${appointment.appointmentDate.year}';
      final timeStr =
          '${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}';
      appointmentInfo = ' scheduled for $dateStr at $timeStr';
    } catch (e) {
      print('Could not format appointment date: $e');
    }

    await CHWMessageHelper.sendPatientMessageToId(
      appointment.patientId,
      appointmentId,
      '✅ Your appointment request has been APPROVED by the Community Health Worker$appointmentInfo.\n\n'
      '⏰ PLEASE BE PUNCTUAL: Join the consultation ON TIME to avoid any delays. '
      'Punctuality helps us serve you better and maintain the schedule for other patients.\n\n'
      '📱 HOW TO JOIN YOUR CONSULTATION:\n'
      '1. Go to "Appointments" tab\n'
      '2. Find your approved appointment under "Pending Consultations"\n'
      '3. Click on the Video 📹, Audio 🎤, or Chat 💬 icon to start the consultation\n\n'
      'Choose your preferred method and connect with your healthcare provider at the scheduled time.\n\n'
      'Thank you for your cooperation!',
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> _markComplete(BuildContext context, String appointmentId) async {
  try {
    // Example Firestore update to mark appointment as completed
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'completed'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment marked as completed'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Future<void> _denyAppointment(
  BuildContext context,
  String appointmentId,
  String reason,
) async {
  try {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .update({'status': 'denied', 'denialReason': reason});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment denied'),
          backgroundColor: Colors.red,
        ),
      );
    }
    // Fetch patientId and appointment details for message
    final doc = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId)
        .get();
    final data = doc.data();
    final patientId = data != null ? data['patientId'] : null;

    if (patientId != null) {
      // Format appointment date and time
      String appointmentInfo = '';
      if (data!['appointmentDate'] != null) {
        try {
          final appointmentDate = (data['appointmentDate'] as Timestamp)
              .toDate();
          final dateStr =
              '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}';
          final timeStr =
              '${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}';
          appointmentInfo = ' for $dateStr at $timeStr';
        } catch (e) {
          print('Could not format appointment date: $e');
        }
      }

      await CHWMessageHelper.sendPatientMessageToId(
        patientId,
        appointmentId,
        '❌ Your appointment request$appointmentInfo has been DECLINED by the Community Health Worker.\n\n'
        '📋 Reason: $reason\n\n'
        '🔄 WHAT TO DO NEXT:\n'
        '• You can book a new appointment with a different healthcare provider or time slot\n'
        '• Go to "Book Appointment" to schedule another consultation\n'
        '• If you have questions, please contact support\n\n'
        'We apologize for any inconvenience and look forward to serving you.',
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange.shade100;
    case 'approved':
      return Colors.green.shade100;
    case 'denied':
      return Colors.red.shade100;
    case 'completed':
      return Colors.blue.shade100;
    case 'cancelled':
      return Colors.grey.shade100;
    default:
      return Colors.orange.shade100;
  }
}

Color _getStatusTextColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange.shade800;
    case 'approved':
      return Colors.green.shade800;
    case 'denied':
      return Colors.red.shade800;
    case 'completed':
      return Colors.blue.shade800;
    case 'cancelled':
      return Colors.grey.shade800;
    default:
      return Colors.orange.shade800;
  }
}
