// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/services/referral_service.dart';
import '../../../shared/data/services/appointment_service.dart';
import '../../../shared/helpers/chw_message_helper.dart';

class CHWCreateReferralScreen extends StatefulWidget {
  const CHWCreateReferralScreen({super.key});

  @override
  State<CHWCreateReferralScreen> createState() =>
      _CHWCreateReferralScreenState();
}

class _CHWCreateReferralScreenState extends State<CHWCreateReferralScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  String? selectedPatientId;
  String? selectedPatientName;
  String? selectedDoctorId;
  String? selectedDoctorName;
  String selectedUrgency = 'medium';
  bool _isLoading = false;
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _facilityPatients = [];
  List<Map<String, dynamic>> _registeredPatients = [];
  String _patientListType = 'facility'; // 'facility' or 'registered'

  bool _didAutoSelect = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadPatients();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoSelect) {
      final extra = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.extra;
      if (extra is Map) {
        if (extra['patientId'] != null) {
          setState(() {
            selectedPatientId = extra['patientId'] as String?;
          });
        }
        if (extra['patientName'] != null) {
          setState(() {
            selectedPatientName = extra['patientName'] as String?;
          });
        }
      }
      _didAutoSelect = true;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Fetch all approved doctors
      final doctorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isApproved', isEqualTo: true)
          .get();

      // Filter for doctors client-side
      final doctors = doctorsSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final role = (data['role'] ?? '').toString().toLowerCase();
            return role.contains('doctor');
          })
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name':
                  data['fullName'] ??
                  data['name'] ??
                  '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
              'specialization': data['specialization'] ?? 'General Practice',
              'facility': data['facility'] ?? 'Unknown Facility',
            };
          })
          .toList();

      // Sort by name
      doctors.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      setState(() {
        _doctors = doctors;
      });
    } catch (e) {
      debugPrint('Error loading doctors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load doctors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPatients() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load facility patients (from appointments and health records)
      final Set<String> facilityPatientIds = <String>{};

      // From health records
      final healthRecords = await FirebaseFirestore.instance
          .collection('health_records')
          .where('providerId', isEqualTo: currentUser.uid)
          .get();
      for (final doc in healthRecords.docs) {
        final data = doc.data();
        if (data['patientUid'] != null) {
          facilityPatientIds.add(data['patientUid']);
        }
      }

      // From appointments - fetch all and filter client-side to avoid index
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: currentUser.uid)
          .get();
      for (final doc in appointments.docs) {
        final data = doc.data();
        final status = data['status'];
        // Filter client-side for completed, attended, or approved appointments
        if (status == 'completed' ||
            status == 'attended' ||
            status == 'approved') {
          final patientId = data['patientUid'] ?? data['patientId'];
          if (patientId != null && patientId.toString().isNotEmpty) {
            facilityPatientIds.add(patientId);
          }
        }
      }

      // Load registered patients (from chw_patients collection)
      final registeredPatientsSnapshot = await FirebaseFirestore.instance
          .collection('chw_patients')
          .where('registeredBy', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .get();

      // Fetch facility patient details from users collection
      final List<Map<String, dynamic>> facilityPatients = [];
      if (facilityPatientIds.isNotEmpty) {
        // Filter out empty IDs
        final validPatientIds = facilityPatientIds
            .where((id) => id.isNotEmpty)
            .toList();

        if (validPatientIds.isNotEmpty) {
          const int batchSize = 10;
          for (int i = 0; i < validPatientIds.length; i += batchSize) {
            final batch = validPatientIds.sublist(
              i,
              i + batchSize > validPatientIds.length
                  ? validPatientIds.length
                  : i + batchSize,
            );
            final batchSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            for (final doc in batchSnapshot.docs) {
              final data = doc.data();
              facilityPatients.add({
                'id': doc.id,
                'name': data['fullName'] ?? data['name'] ?? 'Unnamed Patient',
                'email': data['email'] ?? '',
                'phone': data['phone'] ?? '',
              });
            }
          }
        }
      }

      // Process registered patients from chw_patients collection
      final List<Map<String, dynamic>> registeredPatients = [];
      for (final doc in registeredPatientsSnapshot.docs) {
        final data = doc.data();
        // In chw_patients, the name is stored as 'fullName'
        final name = data['fullName'] ?? 'Unnamed Patient';

        registeredPatients.add({
          'id': doc.id,
          'name': name,
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'gender': data['gender'] ?? '',
          'address': data['address'] ?? '',
        });
      }

      // Sort both lists alphabetically
      facilityPatients.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
      registeredPatients.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );

      if (mounted) {
        setState(() {
          _facilityPatients = facilityPatients;
          _registeredPatients = registeredPatients;
        });
      }

      debugPrint(
        'Loaded ${facilityPatients.length} facility patients and ${registeredPatients.length} registered patients',
      );
    } catch (e) {
      debugPrint('Error loading patients: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load patients: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createReferral() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a patient'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get CHW details
      final chwDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final chwData = chwDoc.data();
      if (chwData == null) {
        throw Exception('CHW profile not found');
      }

      // Create referral
      await ReferralService.createReferral(
        patientId: selectedPatientId!,
        patientName: selectedPatientName!,
        fromProviderId: currentUser.uid,
        fromProviderName: chwData['name'] ?? 'Unknown CHW',
        fromProviderType: 'CHW',
        toProviderId: selectedDoctorId!,
        toProviderName: selectedDoctorName!,
        toProviderType: 'DOCTOR',
        reason: _reasonController.text.trim(),
        urgency: selectedUrgency,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      // If this referral is from a consultation/appointment, update appointment status to 'referred'
      final extra = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.extra;
      String? appointmentId;
      if (extra is Map && extra['appointmentId'] != null) {
        appointmentId = extra['appointmentId'] as String?;
      }
      if (appointmentId != null) {
        try {
          await AppointmentService.updateAppointmentStatus(
            appointmentId: appointmentId,
            status: 'referred',
          );
          // Fetch the updated appointment status
          final updatedDoc = await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentId)
              .get();
          final updatedData = updatedDoc.data();
          final status = updatedData?['status'] ?? 'unknown';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Appointment $appointmentId status after referral: $status',
                ),
                backgroundColor: status == 'referred'
                    ? Colors.green
                    : Colors.red,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update appointment status: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      // Automated notification to doctor, patient, and CHW about referral, using names
      final patientId = selectedPatientId!;
      final doctorId = selectedDoctorId!;
      final chwId = currentUser.uid;
      final firestore = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();

      // Defensive: ensure selectedDoctorName is set
      String doctorNameForMessage = selectedDoctorName ?? '';
      if (doctorNameForMessage.isEmpty) {
        final docObj = _doctors.firstWhere(
          (d) => d['id'] == doctorId,
          orElse: () => {'name': doctorId},
        );
        doctorNameForMessage = docObj['name'] ?? doctorId;
      }

      // Defensive: ensure selectedPatientName is set
      String patientNameForMessage = selectedPatientName ?? '';
      if (patientNameForMessage.isEmpty) {
        patientNameForMessage = patientId;
      }

      // Defensive: ensure CHW name is set
      String chwNameForMessage =
          chwData['name'] ??
          chwData['fullName'] ??
          chwData['firstName'] ??
          chwId;

      // Debug output
      debugPrint(
        'DEBUG: Sending referral notification. patientId=$patientId, doctorId=$doctorId, doctorName=$doctorNameForMessage, patientName=$patientNameForMessage, chwName=$chwNameForMessage',
      );

      // Message to doctor (personalized)
      final doctorMessage =
          'Dr. $doctorNameForMessage, you have received a new referral for patient $patientNameForMessage from $chwNameForMessage. Please review and act.';
      await firestore.collection('messages').add({
        'to': doctorId,
        'from': chwId,
        'message': doctorMessage,
        'timestamp': now,
        'type': 'referral',
        'patientId': patientId,
        'doctorId': doctorId,
      });

      // Message to patient (personalized, always includes doctor name)
      final patientMessage =
          '$patientNameForMessage, you have been referred to Dr. $doctorNameForMessage for further care by $chwNameForMessage. Please await further instructions from Dr. $doctorNameForMessage.';
      try {
        await CHWMessageHelper.sendReferralMessageToPatient(
          patientId,
          patientMessage,
        );
      } catch (e) {
        debugPrint('Error sending referral message to patient: $e');
      }

      // Message to CHW (self, confirmation, optional)
      // Optionally, you can uncomment to send a confirmation to CHW
      // final chwMessage = '$chwNameForMessage, you have successfully referred $patientNameForMessage to Dr. $doctorNameForMessage.';
      // await firestore.collection('messages').add({
      //   'to': chwId,
      //   'from': chwId,
      //   'message': chwMessage,
      //   'timestamp': now,
      //   'type': 'referral_confirmation',
      //   'patientId': patientId,
      //   'doctorId': doctorId,
      // });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating referral: $e'),
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
        title: const Text('Create Patient Referral'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Refer a patient to a specialist for further care',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Patient Selection
            const Text(
              'Select Patient',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Patient List Type Selector
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Facility Patients'),
                    subtitle: Text('${_facilityPatients.length} patients'),
                    value: 'facility',
                    groupValue: _patientListType,
                    onChanged: (value) {
                      setState(() {
                        _patientListType = value!;
                        selectedPatientId = null;
                        selectedPatientName = null;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('My Registered'),
                    subtitle: Text('${_registeredPatients.length} patients'),
                    value: 'registered',
                    groupValue: _patientListType,
                    onChanged: (value) {
                      setState(() {
                        _patientListType = value!;
                        selectedPatientId = null;
                        selectedPatientName = null;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Patient Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(
                    (_patientListType == 'facility'
                        ? (_facilityPatients.isEmpty
                              ? 'No facility patients found'
                              : 'Select from facility patients')
                        : (_registeredPatients.isEmpty
                              ? 'No registered patients found'
                              : 'Select from registered patients')),
                  ),
                  value: selectedPatientId,
                  onChanged:
                      (_patientListType == 'facility'
                          ? _facilityPatients.isEmpty
                          : _registeredPatients.isEmpty)
                      ? null
                      : (String? newValue) {
                          if (newValue != null) {
                            final patients = _patientListType == 'facility'
                                ? _facilityPatients
                                : _registeredPatients;
                            final patient = patients.firstWhere(
                              (p) => p['id'] == newValue,
                            );
                            setState(() {
                              selectedPatientId = newValue;
                              selectedPatientName = patient['name'];
                            });
                          }
                        },
                  items:
                      (_patientListType == 'facility'
                              ? _facilityPatients
                              : _registeredPatients)
                          .map<DropdownMenuItem<String>>((patient) {
                            return DropdownMenuItem<String>(
                              value: patient['id'],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    patient['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (patient['phone'] != null &&
                                      patient['phone'].toString().isNotEmpty)
                                    Text(
                                      patient['phone'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                ),
              ),
            ),

            // Show info message if no patients available
            if (_patientListType == 'facility' &&
                _facilityPatients.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No facility patients found. These are patients from completed appointments or consultations.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_patientListType == 'registered' &&
                _registeredPatients.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No registered patients found. Register patients from "My Registered Patients" in the dashboard.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (selectedPatientId != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected: $selectedPatientName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              _patientListType == 'facility'
                                  ? 'From facility patients list'
                                  : 'From my registered patients',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Doctor Selection
            const Text(
              'Select Doctor/Specialist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(
                    _doctors.isEmpty
                        ? 'Loading doctors...'
                        : 'Select a doctor to refer to',
                  ),
                  value: selectedDoctorId,
                  onChanged: _doctors.isEmpty
                      ? null
                      : (String? newValue) {
                          if (newValue != null) {
                            final doctor = _doctors.firstWhere(
                              (d) => d['id'] == newValue,
                            );
                            setState(() {
                              selectedDoctorId = newValue;
                              selectedDoctorName = doctor['name'];
                            });
                          }
                        },
                  items: _doctors.map<DropdownMenuItem<String>>((doctor) {
                    return DropdownMenuItem<String>(
                      value: doctor['id'],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            doctor['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            doctor['specialization'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          if (doctor['facility'] != null &&
                              doctor['facility'] != 'Unknown Facility')
                            Text(
                              doctor['facility'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            if (selectedDoctorId != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Doctor: $selectedDoctorName',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            if (_doctors.isNotEmpty)
                              Builder(
                                builder: (context) {
                                  final doctor = _doctors.firstWhere(
                                    (d) => d['id'] == selectedDoctorId,
                                    orElse: () => {},
                                  );
                                  if (doctor.isNotEmpty) {
                                    return Text(
                                      '${doctor['specialization']} - ${doctor['facility']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade600,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Reason for Referral
            const Text(
              'Reason for Referral',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText:
                    'Describe the medical condition or reason for referral',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason for the referral';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Urgency Level
            const Text(
              'Urgency Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedUrgency,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedUrgency = newValue;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.blue, size: 12),
                          SizedBox(width: 8),
                          Text('Low Priority - Routine care'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.orange, size: 12),
                          SizedBox(width: 8),
                          Text('Medium Priority - Within a week'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 12),
                          SizedBox(width: 8),
                          Text('High Priority - Within 24-48 hours'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'critical',
                      child: Row(
                        children: [
                          Icon(Icons.circle, color: Colors.purple, size: 12),
                          SizedBox(width: 8),
                          Text('Critical - Immediate attention required'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Additional Notes
            const Text(
              'Additional Notes (Optional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Any additional information that might be helpful',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Submit Button
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Referral'),
                              content: const Text(
                                'Are you sure you want to create this referral?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            _createReferral();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Create Referral'),
                      ),
                      const SizedBox(height: 16),

                      // Important Notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'The referring doctor will be notified and can approve or reject this referral. The patient will be able to view the referral status.',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
