// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print, unused_import, unused_element, use_key_in_widget_constructors, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/data/services/consultation_service.dart';
import '../../../shared/data/services/message_service.dart';
import '../../../shared/data/models/appointment.dart';
import '../../../shared/helpers/chw_message_helper.dart';


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
                  builder: (context) => _BookAppointmentWithDoctorScreen(doctor: selectedDoctor),
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
  State<_DoctorSelectorForBooking> createState() => _DoctorSelectorForBookingState();
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
    setState(() { _isLoading = true; });
    try {
      final query = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .where('isActive', isEqualTo: true);
      final snapshot = await query.get();
      final searchTerm = _searchController.text.trim().toLowerCase();
      final doctors = snapshot.docs.map((doc) {
        final data = doc.data();
        final isApproved = data['isApproved'] == null ? true : data['isApproved'] == true;
        return {
          'id': doc.id,
          'name': data['fullName'] ?? data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'role': data['role'] ?? 'doctor',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'isApproved': isApproved,
        };
      })
      .where((doctor) => doctor['isApproved'] == true)
      .where((doctor) {
        if (doctor['id'] == _currentUserId) return false;
        if (searchTerm.isEmpty) return true;
        final name = (doctor['name'] ?? '').toLowerCase();
        final email = (doctor['email'] ?? '').toLowerCase();
        final phone = (doctor['phone'] ?? '').toLowerCase();
        return name.contains(searchTerm) || email.contains(searchTerm) || phone.contains(searchTerm);
      }).toList();
      debugPrint('Doctor list loaded: count = ���[33m${doctors.length}���[0m');
      if (doctors.isEmpty) {
        debugPrint('No doctors found. Check isActive and isApproved fields in Firestore.');
      }
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching doctors: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Doctor'), backgroundColor: Colors.teal),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            leading: CircleAvatar(child: Text(doctor['name'].isNotEmpty ? doctor['name'][0].toUpperCase() : '?')),
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
  State<_BookAppointmentWithDoctorScreen> createState() => _BookAppointmentWithDoctorScreenState();
}

class _BookAppointmentWithDoctorScreenState extends State<_BookAppointmentWithDoctorScreen> {
  String? _selectedPatientId;
  String? _selectedPatientName;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoadingPatients = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() { _isLoadingPatients = true; });
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
        if (data['relatedPatientId'] != null) patientIds.add(data['relatedPatientId']);
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
        final batch = idsList.sublist(i, i + batchSize > idsList.length ? idsList.length : i + batchSize);
        final batchQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in batchQuery.docs) {
          final data = doc.data();
          patients.add({
            'id': doc.id,
            'name': data['fullName'] ?? data['name'] ?? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          });
        }
      }
      setState(() {
        _patients = patients;
        _isLoadingPatients = false;
      });
    } catch (e) {
      setState(() { _isLoadingPatients = false; });
    }
  }
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

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

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select date and time')),
      );
      return;
    }
    final chw = FirebaseAuth.instance.currentUser;
    if (chw == null) return;
    setState(() => _isSubmitting = true);
    final appointmentDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    try {
      await FirebaseFirestore.instance.collection('appointments').add({
        'patientId': chw.uid,
        'patientName': chw.displayName ?? 'CHW',
        'providerId': widget.doctor['id'],
        'providerName': widget.doctor['name'],
        'status': 'pending',
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'reason': _reasonController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        if (_selectedPatientId != null) ...{
          'relatedPatientId': _selectedPatientId,
          'relatedPatientName': _selectedPatientName,
        },
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Appointment requested!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
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
      appBar: AppBar(title: Text('Book Appointment'), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking with Dr. ${widget.doctor['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              // Optional patient selector
              _isLoadingPatients
                  ? Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedPatientId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Related Patient (optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._patients.map((p) => DropdownMenuItem<String>(
                              value: p['id'],
                              child: Text(p['name'] ?? 'Unnamed'),
                            )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedPatientId = val;
                          _selectedPatientName = _patients.firstWhere((p) => p['id'] == val, orElse: () => {'name': null})['name'];
                        });
                      },
                    ),
              SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for appointment',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a reason' : null,
                maxLines: 2,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null ? 'Select Date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                      onPressed: _pickDate,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.access_time),
                      label: Text(_selectedTime == null ? 'Select Time' : (_selectedTime != null ? _selectedTime!.format(context) : 'Select Time')),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : submit,
                  child: _isSubmitting ? CircularProgressIndicator(color: Colors.white) : Text('Book Appointment'),
                  style: ElevatedButton.styleFrom(minimumSize: Size(180, 48)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  Widget _buildAppointmentsList(BuildContext context, String chwUid, String status) {
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
            final appointmentDate = (data['appointmentDate'] as Timestamp).toDate();
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _getStatusColor(status),
              child: ExpansionTile(
                title: Text(data['patientName'] ?? 'Unknown Patient'),
                subtitle: Text('Date: ${appointmentDate.day}/${appointmentDate.month}/${appointmentDate.year}'),
                children: [
                  if (data['preConsultationData'] != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final checklist = data['preConsultationData'] as Map<String, dynamic>;
                              return AlertDialog(
                                title: const Text('Pre-Consultation Checklist'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final entry in checklist.entries)
                                        if (entry.value != null && entry.value.toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 15)),
                                          ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pre-Consultation Checklist:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ..._buildPreConsultationDetails(data['preConsultationData']),
                            Text('(Tap to view details)', style: TextStyle(fontSize: 12, color: Colors.teal)),
                          ],
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (status == 'pending') ...[
                        ElevatedButton(
                          onPressed: () => _showApproveDialog(context, doc.id),
                          child: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _showRescheduleDialog(context, doc),
                          child: const Text('Reschedule'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _showDenyDialog(context, doc.id),
                          child: const Text('Deny'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ],
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
              await _denyAppointment(context, appointmentId, reasonController.text.trim());
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
                    title: Text('Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
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
                  onPressed: () => _rescheduleAppointment(context, doc.id, selectedDate, selectedTime),
                  child: const Text('Reschedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _rescheduleAppointment(BuildContext context, String appointmentId, DateTime date, TimeOfDay time) async {
    final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    try {
      // Example Firestore update using newDateTime
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({'appointmentDate': Timestamp.fromDate(newDateTime)});

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rescheduled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rescheduling: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveAppointment(BuildContext context, String appointmentId) async {
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
          const SnackBar(content: Text('Appointment approved'), backgroundColor: Colors.green),
        );
      }
      // Always send message to patient about approval
      await CHWMessageHelper.sendPatientMessageToId(appointment.patientId, appointmentId, 'Your appointment has been approved by the CHW.');
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

  Future<void> _denyAppointment(BuildContext context, String appointmentId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'denied',
            'denialReason': reason,
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment denied'), backgroundColor: Colors.red),
        );
      }
      // Fetch patientId for message
      final doc = await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).get();
      final data = doc.data();
      final patientId = data != null ? data['patientId'] : null;
      if (patientId != null) {
        await CHWMessageHelper.sendPatientMessageToId(patientId, appointmentId, 'Your appointment was denied by the CHW. Reason: $reason');
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
