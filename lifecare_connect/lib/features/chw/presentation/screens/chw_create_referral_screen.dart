// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/data/services/referral_service.dart';
import '../../../shared/data/services/appointment_service.dart';
import '../../../shared/helpers/chw_message_helper.dart';
import '../../../shared/presentation/widgets/searchable_patient_selector.dart';

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

  bool _didAutoSelect = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
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

      // 1. Fetch all active doctors
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Filter client-side for role containing 'doctor' (case-insensitive), isActive, and isApproved
      final allDoctorsSnapshot = allUsersSnapshot.docs.where((doc) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString().toLowerCase();
        final isApproved = data['isApproved'] == true;
        return role.contains('doctor') && isApproved;
      }).toList();

      // 2. Fetch interacted doctor IDs (from referrals, appointments, health_records)
      final Set<String> interactedDoctorIds = <String>{};

      // Referrals made by this CHW
      final referrals = await FirebaseFirestore.instance
          .collection('referrals')
          .where('referredById', isEqualTo: currentUser.uid)
          .get();
      for (final doc in referrals.docs) {
        final data = doc.data();
        if (data['toProviderId'] != null &&
            data['toProviderType'] == 'DOCTOR') {
          interactedDoctorIds.add(data['toProviderId']);
        }
      }

      // Appointments with doctors
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isNotEqualTo: currentUser.uid)
          .where('status', whereIn: ['completed', 'attended'])
          .get();
      for (final doc in appointments.docs) {
        final data = doc.data();
        if (data['providerId'] != null && data['providerRole'] == 'doctor') {
          interactedDoctorIds.add(data['providerId']);
        }
      }

      // Health records (if any, e.g. consultations with doctors)
      final healthRecords = await FirebaseFirestore.instance
          .collection('health_records')
          .where('providerId', isNotEqualTo: currentUser.uid)
          .get();
      for (final doc in healthRecords.docs) {
        final data = doc.data();
        if (data['providerId'] != null && data['providerRole'] == 'doctor') {
          interactedDoctorIds.add(data['providerId']);
        }
      }

      // 3. Build doctor list, marking interacted ones
      // Only include doctors that actually exist in the current snapshot
      List<Map<String, dynamic>> allDoctors = allDoctorsSnapshot.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name':
              data['fullName'] ??
              data['name'] ??
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'specialization': data['specialization'] ?? 'General Practice',
          'facility': data['facility'] ?? 'Unknown Facility',
          'interacted': interactedDoctorIds.contains(doc.id),
        };
      }).toList();

      // 4. Sort: interacted doctors first, then by name
      allDoctors.sort((a, b) {
        if (a['interacted'] == b['interacted']) {
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        return a['interacted'] ? -1 : 1;
      });

      setState(() {
        _doctors = allDoctors;
      });
    } catch (e) {
      debugPrint('Error loading doctors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load doctors'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onPatientSelected(String? patientId, String? patientName) {
    setState(() {
      selectedPatientId = patientId;
      selectedPatientName = patientName;
    });
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
            SearchablePatientSelector(
              selectedPatientId: selectedPatientId,
              selectedPatientName: selectedPatientName,
              onPatientSelected: _onPatientSelected,
              currentUserRole: 'chw',
              hintText: 'Select patient to refer',
            ),

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
                  hint: const Text('Select a doctor to refer to'),
                  value: selectedDoctorId,
                  onChanged: (String? newValue) {
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
                      child: Row(
                        children: [
                          if (doctor['interacted'] == true)
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 18,
                            ),
                          if (doctor['interacted'] == true)
                            const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  doctor['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: doctor['interacted'] == true
                                        ? Colors.orange.shade800
                                        : null,
                                  ),
                                ),
                                Text(
                                  '${doctor['specialization']} • ${doctor['facility']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

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
