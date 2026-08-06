import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CHWBookAppointmentScreen extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic> patientData;

  const CHWBookAppointmentScreen({
    super.key,
    required this.patientId,
    required this.patientData,
  });

  @override
  State<CHWBookAppointmentScreen> createState() =>
      _CHWBookAppointmentScreenState();
}

class _CHWBookAppointmentScreenState extends State<CHWBookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Appointment Details
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _appointmentTime = TimeOfDay.now();
  String? _appointmentType;
  String? _location;
  final _addressController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();

  // Reminder Settings
  bool _sendReminder = true;
  int _reminderHoursBefore = 24;

  final List<String> _appointmentTypes = [
    'Follow-up Visit',
    'ANC Visit',
    'PNC Visit',
    'Immunization',
    'Consultation',
    'Health Education Session',
    'Medication Review',
    'Chronic Disease Management',
    'Home Visit',
    'Other',
  ];

  final List<String> _locationOptions = [
    'Health Facility',
    'Patient Home',
    'Community Center',
    'CHW Office',
    'Other',
  ];

  final List<int> _reminderOptions = [
    1, // 1 hour before
    3, // 3 hours before
    6, // 6 hours before
    12, // 12 hours before
    24, // 1 day before
    48, // 2 days before
  ];

  @override
  void dispose() {
    _addressController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final chwId = FirebaseAuth.instance.currentUser?.uid;
      if (chwId == null) throw Exception('CHW not logged in');

      final serviceCost = await _getServiceCost('appointment');

      final walletDoc = await FirebaseFirestore.instance
          .collection('chw_patient_wallets')
          .doc(widget.patientId)
          .get();

      final balance = walletDoc.data()?['balance'] ?? 0.0;

      if (balance < serviceCost) {
        throw Exception(
          'Insufficient wallet balance. Required: ₦$serviceCost, Available: ₦$balance',
        );
      }

      // Combine date and time
      final appointmentDateTime = DateTime(
        _appointmentDate.year,
        _appointmentDate.month,
        _appointmentDate.day,
        _appointmentTime.hour,
        _appointmentTime.minute,
      );

      // Calculate reminder time
      DateTime? reminderDateTime;
      if (_sendReminder) {
        reminderDateTime = appointmentDateTime.subtract(
          Duration(hours: _reminderHoursBefore),
        );
      }

      final appointmentRef = FirebaseFirestore.instance
          .collection('chw_patient_records')
          .doc(widget.patientId)
          .collection('appointments')
          .doc();

      final appointmentData = {
        'appointmentId': appointmentRef.id,
        'patientId': widget.patientId,
        'chwId': chwId,
        'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
        'appointmentType': _appointmentType,
        'location': _location,
        'address': _addressController.text.trim(),
        'reason': _reasonController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': 'scheduled',
        'sendReminder': _sendReminder,
        'reminderHoursBefore': _reminderHoursBefore,
        'reminderDateTime': reminderDateTime != null
            ? Timestamp.fromDate(reminderDateTime)
            : null,
        'reminderSent': false,
        'serviceCost': serviceCost,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await appointmentRef.set(appointmentData);
      await _processServicePayment(serviceCost, chwId, 'Appointment Booking');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<double> _getServiceCost(String serviceType) async {
    final chwId = FirebaseAuth.instance.currentUser?.uid;
    final serviceDoc = await FirebaseFirestore.instance
        .collection('chw_services')
        .doc(chwId)
        .get();

    if (serviceDoc.exists) {
      final services = serviceDoc.data()?['services'] as Map<String, dynamic>?;
      return services?[serviceType]?.toDouble() ?? 100.0;
    }
    return 100.0;
  }

  Future<void> _processServicePayment(
    double amount,
    String chwId,
    String serviceType,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    final walletRef = FirebaseFirestore.instance
        .collection('chw_patient_wallets')
        .doc(widget.patientId);

    batch.update(walletRef, {
      'balance': FieldValue.increment(-amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    final chwAmount = amount * 0.7;
    final adminAmount = amount * 0.3;

    final chwWalletRef = FirebaseFirestore.instance
        .collection('chw_wallets')
        .doc(chwId);

    batch.set(chwWalletRef, {
      'balance': FieldValue.increment(chwAmount),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final adminEarningsRef = FirebaseFirestore.instance
        .collection('admin_earnings')
        .doc();

    batch.set(adminEarningsRef, {
      'amount': adminAmount,
      'source': 'chw_service',
      'chwId': chwId,
      'patientId': widget.patientId,
      'serviceType': serviceType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final transactionRef = FirebaseFirestore.instance
        .collection('chw_transactions')
        .doc();

    batch.set(transactionRef, {
      'type': 'service_payment',
      'patientId': widget.patientId,
      'chwId': chwId,
      'serviceType': serviceType,
      'totalAmount': amount,
      'chwAmount': chwAmount,
      'adminAmount': adminAmount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPatientInfo(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Appointment Details', Icons.event),
                    _buildAppointmentDetailsSection(),
                    const SizedBox(height: 24),

                    _buildSectionHeader(
                      'Reminder Settings',
                      Icons.notifications,
                    ),
                    _buildReminderSection(),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _bookAppointment,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Book Appointment',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPatientInfo() {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientData['fullName'] ?? 'Unknown',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Phone: ${widget.patientData['phone'] ?? 'N/A'}'),
            Text('Address: ${widget.patientData['address'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _appointmentType,
              decoration: const InputDecoration(
                labelText: 'Appointment Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _appointmentTypes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _appointmentType = val),
              validator: (val) => val == null ? 'Please select type' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Date',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(_appointmentDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _appointmentDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() => _appointmentDate = date);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Time',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    subtitle: Text(
                      _appointmentTime.format(context),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _appointmentTime,
                        );
                        if (time != null) {
                          setState(() => _appointmentTime = time);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _location,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              items: _locationOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _location = val),
              validator: (val) => val == null ? 'Please select location' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Specific Address (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.place),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Appointment',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (val) =>
                  val?.isEmpty ?? true ? 'Please enter reason' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                hintText: 'Any special instructions or preparations needed',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Send Reminder'),
              subtitle: const Text('Notify patient before appointment'),
              value: _sendReminder,
              onChanged: (val) => setState(() => _sendReminder = val),
            ),
            if (_sendReminder) ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Remind patient:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reminderOptions.map((hours) {
                  final selected = _reminderHoursBefore == hours;
                  String label;
                  if (hours < 24) {
                    label = '$hours hour${hours > 1 ? 's' : ''} before';
                  } else {
                    final days = hours ~/ 24;
                    label = '$days day${days > 1 ? 's' : ''} before';
                  }

                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _reminderHoursBefore = hours);
                    },
                    selectedColor: Colors.indigo.shade200,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
