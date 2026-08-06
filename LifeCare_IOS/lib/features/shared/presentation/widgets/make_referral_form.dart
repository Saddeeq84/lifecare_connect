import 'package:flutter/material.dart';
import 'searchable_patient_selector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MakeReferralForm extends StatefulWidget {
  final String role;
  const MakeReferralForm({required this.role, super.key});

  @override
  State<MakeReferralForm> createState() => _MakeReferralFormState();
}

class _MakeReferralFormState extends State<MakeReferralForm> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPatientId;
  String? _selectedPatientName;
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
    'Other',
  ];

  @override
  void dispose() {
    // No need to dispose _selectedPatientId/_selectedPatientName
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
    if (_selectedPatientId == null || _selectedPatientName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a patient')));
      return;
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select specialty')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await FirebaseFirestore.instance.collection('referrals').add({
        'patientName': _selectedPatientName,
        'patientId': _selectedPatientId,
        'fromProviderId': user.uid,
        'fromProviderName':
            'Provider', // You might want to get the actual provider name
        'fromProviderType': widget.role.toUpperCase(),
        'toProviderId': _selectedDoctorId,
        'toProviderName': _selectedDoctorName,
        'toProviderType': 'DOCTOR',
        'reason': _reasonController.text.trim(),
        'notes': _notesController.text.trim(),
        'urgency': _selectedUrgency?.toLowerCase() ?? 'medium',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // Patient Information
            Text(
              'Patient Information',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SearchablePatientSelector(
              selectedPatientId: _selectedPatientId,
              selectedPatientName: _selectedPatientName,
              currentUserRole: widget.role,
              onPatientSelected: (id, name) {
                setState(() {
                  _selectedPatientId = id;
                  _selectedPatientName = name;
                });
              },
              isRequired: true,
              hintText: 'Select Patient *',
            ),
            const SizedBox(height: 24),

            // Doctor Selection (always visible, with error handling)
            Text(
              'Select Target Doctor',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'doctor')
                  .where('isApproved', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Error loading doctors. Please try again.',
                        style: TextStyle(color: Colors.red),
                      ),
                      Text(
                        'Error: \\${snapshot.error}',
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No approved doctors found in Firestore.'),
                      Text(
                        'Debug: doctors count = \\${snapshot.data?.docs.length ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  );
                }
                final users = snapshot.data!.docs;
                if (users.isEmpty) {
                  return const Text('No approved doctors found.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedDoctorId,
                      decoration: const InputDecoration(
                        labelText: 'Select Doctor *',
                        prefixIcon: Icon(Icons.local_hospital),
                        border: OutlineInputBorder(),
                      ),
                      items: users.map((doc) {
                        final name = doc['name'] ?? doc['fullName'] ?? 'Doctor';
                        final role = doc['role'] ?? '';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text('$name  (role: $role)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final selected = users.firstWhere(
                          (doc) => doc.id == value,
                        );
                        setState(() {
                          _selectedDoctorId = value;
                          _selectedDoctorName =
                              selected['name'] ??
                              selected['fullName'] ??
                              'Doctor';
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a doctor' : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Debug: All users are shown as doctors for troubleshooting. Please check user roles in Firestore.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Referral Details
            Text(
              'Referral Details',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedSpecialty,
              decoration: const InputDecoration(
                labelText: 'Specialty *',
                prefixIcon: Icon(Icons.medical_services),
                border: OutlineInputBorder(),
              ),
              items: _specialties.map((specialty) {
                return DropdownMenuItem(
                  value: specialty,
                  child: Text(specialty),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedSpecialty = value),
              validator: (value) =>
                  value == null ? 'Please select specialty' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedUrgency,
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
              validator: (value) =>
                  value == null ? 'Please select urgency level' : null,
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
                hintText:
                    'Describe the medical condition or reason for referral',
              ),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Please enter reason for referral'
                  : null,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
    );
  }
}
