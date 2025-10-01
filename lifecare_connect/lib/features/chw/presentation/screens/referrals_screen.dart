// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/shared_referral_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referrals'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const _MakeReferralForm(role: 'chw'),
                ),
              );
            },
          ),
        ],
      ),
      body: const SharedReferralWidget(role: 'chw'),
    );
  }
}

class _MakeReferralForm extends StatefulWidget {
  final String role;
  
  const _MakeReferralForm({required this.role});

  @override
  State<_MakeReferralForm> createState() => _MakeReferralFormState();
}

class _MakeReferralFormState extends State<_MakeReferralForm> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _patientIdController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedDoctorId;
  String? _selectedDoctorName;
  
  bool _isLoading = false;
  String? _selectedUrgency;
  String? _selectedSpecialty;
  DateTime? _selectedDate;

  final List<String> _urgencyLevels = ['Low', 'Medium', 'High', 'Emergency'];
  final List<String> _specialties = [
    'General Practice',
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Surgery',
    'Other'
  ];

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientIdController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitReferral() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select referral date')),
      );
      return;
    }
    if (_selectedUrgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select urgency level')),
      );
      return;
    }
    if (_selectedSpecialty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select specialty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance.collection('referrals').add({
        'patient_name': _patientNameController.text.trim(),
        'patient_id': _patientIdController.text.trim(),
        'referring_provider': user.uid,
        'referring_provider_role': widget.role,
        'reason': _reasonController.text.trim(),
        'notes': _notesController.text.trim(),
        'doctor_id': _selectedDoctorId,
        'doctor_name': _selectedDoctorName,
        'urgency': _selectedUrgency,
        'specialty': _selectedSpecialty,
        'referral_date': Timestamp.fromDate(_selectedDate!),
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit referral: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Make Referral'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Patient Information
              Text(
                'Patient Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'Patient Name *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Please enter patient name' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _patientIdController,
                decoration: const InputDecoration(
                  labelText: 'Patient ID/Number',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Referral Details
              Text(
                'Referral Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
          .collection('users')
          .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No doctors found');
                  }
                  final doctors = snapshot.data!.docs;
                  // Filter client-side for any role containing 'doctor' (case-insensitive)
                  final filteredDoctors = doctors.where((doc) {
                    final role = (doc['role'] ?? '').toString().toLowerCase();
                    return role.contains('doctor');
                  }).toList();
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedDoctorId,
                    decoration: const InputDecoration(
                      labelText: 'Select Doctor *',
                      prefixIcon: Icon(Icons.local_hospital),
                      border: OutlineInputBorder(),
                    ),
                    items: filteredDoctors.map((doc) {
                      final name = doc['name'] ?? doc['fullName'] ?? 'Doctor';
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      final selected = filteredDoctors.firstWhere((doc) => doc.id == value);
                      setState(() {
                        _selectedDoctorId = value;
                        _selectedDoctorName = selected['name'] ?? selected['fullName'] ?? 'Doctor';
                      });
                    },
                    validator: (value) => value == null ? 'Please select a doctor' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedSpecialty,
                decoration: const InputDecoration(
                  labelText: 'Specialty *',
                  prefixIcon: Icon(Icons.medical_services),
                  border: OutlineInputBorder(),
                ),
                items: _specialties.map((specialty) {
                  return DropdownMenuItem(value: specialty, child: Text(specialty));
                }).toList(),
                onChanged: (value) => setState(() => _selectedSpecialty = value),
                validator: (value) => value == null ? 'Please select specialty' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedUrgency,
                decoration: const InputDecoration(
                  labelText: 'Urgency Level *',
                  prefixIcon: Icon(Icons.priority_high),
                  border: OutlineInputBorder(),
                ),
                items: _urgencyLevels.map((urgency) {
                  return DropdownMenuItem(
                    value: urgency,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: urgency == 'Emergency' 
                              ? Colors.red 
                              : urgency == 'High' 
                                  ? Colors.orange 
                                  : urgency == 'Medium' 
                                      ? Colors.yellow[700] 
                                      : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(urgency),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedUrgency = value),
                validator: (value) => value == null ? 'Please select urgency level' : null,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Preferred Referral Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedDate == null 
                        ? 'Select date'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: TextStyle(
                      color: _selectedDate == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for Referral *',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  hintText: 'Describe the medical condition or reason for referral',
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Please enter reason for referral' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                  hintText: 'Any additional information or special instructions',
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitReferral,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Referral',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),

              // Cancel Button
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
