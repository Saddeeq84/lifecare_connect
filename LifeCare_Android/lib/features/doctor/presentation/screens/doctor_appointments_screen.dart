import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/data/services/message_service.dart';

class DoctorAppointmentsTabView extends StatelessWidget {
  final String userId;
  const DoctorAppointmentsTabView({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending Approval'),
              Tab(text: 'Approved Appointments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DoctorAppointmentsList(userId: userId, status: 'pending'),

            DoctorAppointmentsList(userId: userId, status: 'approved'),
          ],
        ),
      ),
    );
  }
}

class DoctorAppointmentsList extends StatelessWidget {
  final String userId;
  final String status;
  const DoctorAppointmentsList({
    super.key,
    required this.userId,
    required this.status,
  });

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

  Future<void> _showPreConsultationDetails(
    BuildContext context,
    Map<String, dynamic> checklistData, {
    Map<String, dynamic>? appointmentData,
  }) async {
    // Support both top-level and nested (healthAssessment/data) structures
    Map<String, dynamic> data = checklistData;
    if (data.containsKey('healthAssessment') &&
        data['healthAssessment'] is Map<String, dynamic>) {
      data = {...data, ...data['healthAssessment']};
    } else if (data.containsKey('data') &&
        data['data'] is Map<String, dynamic>) {
      data = {...data, ...data['data']};
      if (data.containsKey('healthAssessment') &&
          data['healthAssessment'] is Map<String, dynamic>) {
        data = {...data, ...data['healthAssessment']};
      }
    }

    // Fetch patient phone from users collection
    String? patientPhone;
    String? patientAge;
    String? patientGender;

    if (appointmentData != null) {
      try {
        final patientUid =
            appointmentData['patientUid'] ?? appointmentData['patientId'];
        if (patientUid != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(patientUid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;

            // Get phone number
            patientPhone =
                userData['phone'] ??
                userData['phoneNumber'] ??
                userData['contact'];

            // Get age
            if (userData['age'] != null) {
              patientAge = userData['age'].toString();
            } else if (userData['dateOfBirth'] != null) {
              try {
                final dob = (userData['dateOfBirth'] as Timestamp).toDate();
                final age = DateTime.now().difference(dob).inDays ~/ 365;
                patientAge = age.toString();
              } catch (e) {
                print('Error calculating age: $e');
              }
            }

            // Get gender
            patientGender = userData['gender'] ?? userData['sex'];
          }
        }
      } catch (e) {
        print('Error fetching patient info: $e');
      }

      // Fallback to appointment data if user fetch failed
      patientPhone ??=
          appointmentData['phone'] ?? appointmentData['patientPhone'];
      patientAge ??= appointmentData['age']?.toString();
      patientGender ??= appointmentData['gender'] ?? appointmentData['sex'];
    }

    final fields = <String, String?>{
      // Patient Information (from users collection)
      if (appointmentData != null) ...{
        'Patient Name': appointmentData['patientName'],
        'Patient Phone': patientPhone,
        'Patient Age': patientAge,
        'Patient Gender': patientGender,
      },
      // Checklist Information
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
      'Additional Notes': data['additionalNotes'] ?? data['notes'],
    };

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                          .map(
                            (entry) => _buildInfoCard(entry.key, entry.value!),
                          )
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

  Widget _buildInfoCard(String label, String value) {
    // Icon mapping for different fields
    IconData getIcon(String label) {
      if (label.contains('Name')) return Icons.person;
      if (label.contains('Phone')) return Icons.phone;
      if (label.contains('Age')) return Icons.cake;
      if (label.contains('Gender')) return Icons.wc;
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
      if (label.contains('Note')) return Icons.note;
      return Icons.info;
    }

    // Color mapping for different fields
    MaterialColor getColor(String label) {
      if (label.contains('Name')) return Colors.indigo;
      if (label.contains('Phone')) return Colors.cyan;
      if (label.contains('Age')) return Colors.pink;
      if (label.contains('Gender')) return Colors.deepPurple;
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
      if (label.contains('Note')) return Colors.grey;
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

  Future<void> _handleApprove(
    BuildContext context,
    DocumentSnapshot appointmentDoc,
  ) async {
    final data = appointmentDoc.data() as Map<String, dynamic>;
    try {
      await appointmentDoc.reference.update(<String, dynamic>{
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': userId,
      });

      final consultationsCollection = FirebaseFirestore.instance.collection(
        'consultations',
      );
      await consultationsCollection.add({
        'appointmentId': appointmentDoc.id,
        'patientUid': data['patientUid'],
        'patientName': data['patientName'] ?? 'Patient',
        'providerId': userId,
        'providerName': data['providerName'] ?? 'Doctor',
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'type': data['type'] ?? 'general',
        'reason': data['reason'] ?? '',
      });

      // Format appointment date and time
      String appointmentInfo = '';
      if (data['appointmentDate'] != null) {
        try {
          final appointmentDate = (data['appointmentDate'] as Timestamp)
              .toDate();
          final dateStr =
              '${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}';
          final timeStr =
              '${appointmentDate.hour.toString().padLeft(2, '0')}:${appointmentDate.minute.toString().padLeft(2, '0')}';
          appointmentInfo = ' scheduled for $dateStr at $timeStr';
        } catch (e) {
          print('Could not format appointment date: $e');
        }
      }

      await _sendPatientMessage(
        patientId: data['patientUid'],
        patientName: data['patientName'] ?? 'Patient',
        content:
            '✅ Your appointment request has been APPROVED by the doctor$appointmentInfo.\n\n'
            '⏰ PLEASE BE PUNCTUAL: Join the consultation ON TIME to avoid any delays. '
            'Punctuality helps us serve you better and maintain the schedule for other patients.\n\n'
            '📱 HOW TO JOIN YOUR CONSULTATION:\n'
            '1. Go to "Appointments" tab\n'
            '2. Find your approved appointment under "Pending Consultations"\n'
            '3. Click on the Video 📹, Audio 🎤, or Chat 💬 icon to start the consultation\n\n'
            'Choose your preferred method and connect with your healthcare provider at the scheduled time.\n\n'
            'Thank you for your cooperation!',
      );

      // If this appointment was booked by CHW for a registered patient, notify them too
      if (data['relatedPatientId'] != null &&
          data['relatedPatientId'].toString().isNotEmpty) {
        await _sendPatientMessage(
          patientId: data['relatedPatientId'],
          patientName: data['relatedPatientName'] ?? 'Patient',
          content:
              '✅ Your appointment (booked by CHW) has been APPROVED by the doctor$appointmentInfo.\n\n'
              '⏰ PLEASE BE PUNCTUAL: Join the consultation ON TIME to avoid any delays. '
              'Punctuality helps us serve you better and maintain the schedule for other patients.\n\n'
              '📱 HOW TO JOIN YOUR CONSULTATION:\n'
              '1. Go to "Appointments" tab\n'
              '2. Find your approved appointment under "Pending Consultations"\n'
              '3. Click on the Video 📹, Audio 🎤, or Chat 💬 icon to start the consultation\n\n'
              'Choose your preferred method and connect with your healthcare provider at the scheduled time.\n\n'
              'Thank you for your cooperation!',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment approved and patient notified.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve appointment: $e')),
      );
    }
  }

  Future<void> _handleDeny(
    BuildContext context,
    DocumentSnapshot appointmentDoc,
  ) async {
    final data = appointmentDoc.data() as Map<String, dynamic>;
    String? reason = await _showDenyReasonDialog(context);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await appointmentDoc.reference.update(<String, dynamic>{
        'status': 'denied',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': userId,
        'denialReason': reason.trim(),
      });
      // Format appointment date and time
      String appointmentInfo = '';
      if (data['appointmentDate'] != null) {
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

      await _sendPatientMessage(
        patientId: data['patientUid'],
        patientName: data['patientName'] ?? 'Patient',
        content:
            '❌ Your appointment request$appointmentInfo has been DECLINED by the doctor.\n\n'
            '📋 Reason: $reason\n\n'
            '🔄 WHAT TO DO NEXT:\n'
            '• You can book a new appointment with a different doctor or time slot\n'
            '• Go to "Book Appointment" to schedule another consultation\n'
            '• If you have questions, please contact support\n\n'
            'We apologize for any inconvenience and look forward to serving you.',
      );

      // If this appointment was booked by CHW for a registered patient, notify them too
      if (data['relatedPatientId'] != null &&
          data['relatedPatientId'].toString().isNotEmpty) {
        await _sendPatientMessage(
          patientId: data['relatedPatientId'],
          patientName: data['relatedPatientName'] ?? 'Patient',
          content:
              '❌ Your appointment (booked by CHW)$appointmentInfo has been DECLINED by the doctor.\n\n'
              '📋 Reason: $reason\n\n'
              '🔄 WHAT TO DO NEXT:\n'
              '• Your CHW can book a new appointment with a different doctor or time slot\n'
              '• Alternatively, you can book directly through "Book Appointment"\n'
              '• If you have questions, please contact support\n\n'
              'We apologize for any inconvenience and look forward to serving you.',
        );
      }

      // Notify CHW if they booked this appointment
      if (data['bookedBy'] == 'chw' && data['bookedById'] != null) {
        final chwId = data['bookedById'];
        final chwDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(chwId)
            .get();
        if (chwDoc.exists) {
          final chwData = chwDoc.data() as Map<String, dynamic>;
          final chwName =
              '${chwData['firstName'] ?? ''} ${chwData['lastName'] ?? ''}'
                  .trim();

          await _sendCHWMessage(
            chwId: chwId,
            chwName: chwName,
            content:
                '❌ Appointment Request DECLINED\n\n'
                'Patient: ${data['patientName'] ?? 'Unknown'}$appointmentInfo\n\n'
                '📋 Reason: $reason\n\n'
                '🔄 NEXT STEPS:\n'
                '• You can book a new appointment for this patient\n'
                '• Try a different time slot or doctor\n'
                '• Check "Appointments" tab to book again\n\n'
                'We apologize for any inconvenience.',
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment denied and patient notified.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to deny appointment: $e')));
    }
  }

  Future<bool?> _showApproveConfirmationDialog(
    BuildContext context,
    DocumentSnapshot appointmentDoc,
  ) async {
    final data = appointmentDoc.data() as Map<String, dynamic>;
    final patientName = data['patientName'] ?? 'Unknown Patient';

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Approval'),
        content: Text(
          'Are you sure you want to approve the appointment for $patientName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDenyConfirmationDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Denial'),
        content: const Text(
          'Are you sure you want to deny this appointment? You will be asked to provide a reason.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deny'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDenyReasonDialog(BuildContext context) async {
    String reason = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reason for Denial'),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            onChanged: (val) => reason = val,
            decoration: const InputDecoration(
              hintText: 'Enter reason for denial...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reason.trim().isNotEmpty) {
                  Navigator.of(context).pop(reason.trim());
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a reason for denial'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Deny'),
            ),
          ],
        );
      },
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
                    data,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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
    Map<String, dynamic> appointmentData,
  ) async {
    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    try {
      // Update appointment date
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'appointmentDate': Timestamp.fromDate(newDateTime),
            'rescheduledAt': FieldValue.serverTimestamp(),
            'rescheduledBy': 'doctor',
            'status': 'approved', // Auto-approve when rescheduling
          });

      // Notify patient about reschedule
      if (appointmentData['patientUid'] != null) {
        final dateStr =
            '${newDateTime.day}/${newDateTime.month}/${newDateTime.year}';
        final timeStr =
            '${newDateTime.hour.toString().padLeft(2, '0')}:${newDateTime.minute.toString().padLeft(2, '0')}';
        final doctorName = appointmentData['providerName'] ?? 'Doctor';

        await _sendPatientMessage(
          patientId: appointmentData['patientUid'],
          patientName: appointmentData['patientName'] ?? 'Patient',
          content:
              '🔄 Your appointment has been RESCHEDULED by $doctorName.\n\n'
              '📅 New Date & Time: $dateStr at $timeStr\n\n'
              '✅ Your appointment has been automatically APPROVED for the new time.\n\n'
              '⏰ PLEASE BE PUNCTUAL: Join the consultation ON TIME at the scheduled time.\n\n'
              '📱 HOW TO JOIN:\n'
              '1. Go to "Appointments" tab\n'
              '2. Find your appointment under "Pending Consultations"\n'
              '3. Click on the Video 📹, Audio 🎤, or Chat 💬 icon at the scheduled time\n\n'
              'If this new time doesn\'t work for you, please contact us to discuss alternative options or book a new appointment.\n\n'
              'We apologize for any inconvenience and thank you for your understanding!',
        );
      }

      // Notify CHW if they booked this appointment
      if (appointmentData['bookedBy'] == 'chw' &&
          appointmentData['bookedById'] != null) {
        final chwId = appointmentData['bookedById'];
        final chwDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(chwId)
            .get();
        if (chwDoc.exists) {
          final chwData = chwDoc.data() as Map<String, dynamic>;
          final chwName =
              '${chwData['firstName'] ?? ''} ${chwData['lastName'] ?? ''}'
                  .trim();
          final dateStr =
              '${newDateTime.day}/${newDateTime.month}/${newDateTime.year}';
          final timeStr =
              '${newDateTime.hour.toString().padLeft(2, '0')}:${newDateTime.minute.toString().padLeft(2, '0')}';

          await _sendCHWMessage(
            chwId: chwId,
            chwName: chwName,
            content:
                '🔄 Appointment RESCHEDULED by Doctor\n\n'
                'Patient: ${appointmentData['patientName'] ?? 'Unknown'}\n'
                '📅 New Date & Time: $dateStr at $timeStr\n\n'
                '✅ Automatically APPROVED for new time\n\n'
                '📋 ACTION REQUIRED:\n'
                '• Inform the patient about the new time\n'
                '• Ensure patient is available at the new time\n'
                '• Check "Appointments" tab for updated details\n\n'
                'Thank you for coordinating!',
          );
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Appointment rescheduled, auto-approved, and patient notified',
            ),
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

  Future<void> _sendCHWMessage({
    required String chwId,
    required String chwName,
    required String content,
  }) async {
    try {
      // Get current doctor info
      final doctorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doctorDoc.exists) {
        print('Doctor document not found');
        return;
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final doctorName =
          '${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}'
              .trim();
      final doctorRole = doctorData['role'] ?? 'doctor';

      // Create or get conversation with CHW
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: userId,
        user1Name: doctorName,
        user1Role: doctorRole,
        user2Id: chwId,
        user2Name: chwName,
        user2Role: 'chw',
        type: 'direct',
      );

      // Send message to CHW
      await MessageService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        senderName: doctorName,
        senderRole: doctorRole,
        receiverId: chwId,
        receiverName: chwName,
        receiverRole: 'chw',
        content: content,
        type: 'appointment_notification',
      );

      print('✅ Message sent to CHW: $chwId');
    } catch (e) {
      print('Error sending message to CHW: $e');
    }
  }

  Future<void> _sendPatientMessage({
    required String patientId,
    required String patientName,
    required String content,
  }) async {
    try {
      // Get current doctor info
      final doctorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doctorDoc.exists) {
        print('Doctor document not found');
        return;
      }

      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final doctorName =
          '${doctorData['firstName'] ?? ''} ${doctorData['lastName'] ?? ''}'
              .trim();
      final doctorRole = doctorData['role'] ?? 'doctor';

      // Create or get conversation with patient
      final conversationId = await MessageService.createOrGetConversation(
        user1Id: userId,
        user1Name: doctorName,
        user1Role: doctorRole,
        user2Id: patientId,
        user2Name: patientName,
        user2Role: 'patient',
        type: 'direct',
      );

      // Send the message within the conversation
      await MessageService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        senderName: doctorName,
        senderRole: doctorRole,
        receiverId: patientId,
        receiverName: patientName,
        receiverRole: 'patient',
        content: content,
        type: 'appointment_notification',
        priority: 'high',
      );

      print('✅ Message sent to patient successfully');
    } catch (e) {
      print('❌ Error sending message to patient: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // For pending status, include all pending-related statuses (facility routing)
    final Stream<QuerySnapshot> appointmentStream;

    if (status == 'pending') {
      // Include all pending variations for facility-affiliated doctors
      appointmentStream = FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: userId)
          .where(
            'status',
            whereIn: [
              'pending',
              'pending_opd_approval',
              'pending_specialist_approval',
            ],
          )
          .snapshots();
    } else {
      appointmentStream = FirebaseFirestore.instance
          .collection('appointments')
          .where('providerId', isEqualTo: userId)
          .where('status', isEqualTo: status)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: appointmentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: \\${snapshot.error}"));
        }
        final appointments = snapshot.data?.docs ?? [];
        if (appointments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No appointments found'),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final data = appointments[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['patientName'] ?? 'Unknown Patient',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (data['reason'] != null &&
                        data['reason'].isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.note, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['reason'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Check for pre-consultation data (show ONLY ONE checklist)
                    // Priority: Patient checklist (health_records) > CHW checklist (appointment)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('health_records')
                          .where(
                            'appointmentId',
                            isEqualTo: appointments[index].id,
                          )
                          .where('type', isEqualTo: 'preconsultation_checklist')
                          .limit(1)
                          .snapshots(),
                      builder: (context, checklistSnapshot) {
                        // Check if patient submitted preconsultation checklist in health_records
                        final hasPatientChecklist =
                            checklistSnapshot.hasData &&
                            checklistSnapshot.data!.docs.isNotEmpty;

                        // Check if CHW submitted preconsultation data in appointment
                        final hasCHWChecklist =
                            data['preConsultationData'] != null &&
                            (data['preConsultationData']
                                    as Map<String, dynamic>)
                                .isNotEmpty;

                        // Show ONLY ONE checklist (Patient takes priority)
                        if (hasPatientChecklist) {
                          // PATIENT Pre-Consultation Checklist (from health_records)
                          final checklistDoc =
                              checklistSnapshot.data!.docs.first;
                          final checklistData =
                              checklistDoc.data() as Map<String, dynamic>;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                                      Icons.assignment,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pre-Consultation Checklist Available',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade700,
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
                                    checklistData,
                                    appointmentData: data,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (hasCHWChecklist) {
                          // CHW Pre-Consultation Checklist (from appointment document)
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.medical_information,
                                      color: Colors.orange.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'CHW Pre-Consultation Checklist',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Community Health Worker has provided pre-consultation information.',
                                  style: TextStyle(
                                    color: Colors.orange.shade600,
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
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                  onPressed: () => _showPreConsultationDetails(
                                    context,
                                    data['preConsultationData']
                                        as Map<String, dynamic>,
                                    appointmentData: data,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          // No preconsultation checklist available
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
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

                    // Show pricing information for remote doctor appointments booked from facility
                    if (status == 'pending' &&
                        data['doctorType'] == 'remote' &&
                        data['bookedBy'] == 'medical_records' &&
                        data['appointmentFee'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade50,
                              Colors.green.shade100,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Appointment Fee Breakdown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.shade100,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.monetization_on,
                                            size: 18,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Patient charged:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₦${(data['appointmentFee'] as num).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 18,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Your earning (70%):',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₦${((data['appointmentFee'] as num) * 0.70).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.local_hospital,
                                            size: 18,
                                            color: Colors.orange.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Facility fee (30%):',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₦${((data['appointmentFee'] as num) * 0.30).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Payment will be processed after consultation note is saved',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade800,
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

                    if (status == 'pending')
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () async {
                              final confirm =
                                  await _showApproveConfirmationDialog(
                                    context,
                                    appointments[index],
                                  );
                              if (confirm == true) {
                                await _handleApprove(
                                  context,
                                  appointments[index],
                                );
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('Deny'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              final confirm = await _showDenyConfirmationDialog(
                                context,
                              );
                              if (confirm == true) {
                                await _handleDeny(context, appointments[index]);
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.schedule, size: 16),
                            label: const Text('Reschedule'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            onPressed: () {
                              _showRescheduleDialog(
                                context,
                                appointments[index],
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
