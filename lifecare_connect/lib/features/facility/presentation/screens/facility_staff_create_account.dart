import 'package:lifecare_connect/core/utils/send_staff_setup_password_email.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityStaffCreateAccountScreen extends StatefulWidget {
  final String facilityName;
  const FacilityStaffCreateAccountScreen({
    super.key,
    required this.facilityName,
  });

  @override
  State<FacilityStaffCreateAccountScreen> createState() =>
      _FacilityStaffCreateAccountScreenState();
}

class _FacilityStaffCreateAccountScreenState
    extends State<FacilityStaffCreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _dob;
  final _staffIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final List<String> _professions = [
    'Doctor',
    'Nurse',
    'Pharmacist',
    'Lab Scientist',
    'Laboratory Technician',
    'Pharmacy Technician',
    'Radiographer',
    'Physiotherapist',
    'Surgeon',
    'Dentist',
    'Midwife',
    'Nutritionist',
    'Medical Records Officer',
    'Public Health Officer',
    'Community Health Officer',
    'Community Health Extension Worker',
    'Scientific Officer',
    'Cleaner',
    'Security',
    'Receptionist',
    'Other',
  ];
  String? _selectedProfession;
  String? _customProfession;
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Staff Account'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Facility selection removed as per new requirements
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date of Birth'),
                  child: Text(
                    _dob == null
                        ? 'Select date'
                        : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _staffIdController,
                decoration: const InputDecoration(labelText: 'Staff ID'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedProfession,
                decoration: const InputDecoration(labelText: 'Profession'),
                items: _professions
                    .map(
                      (profession) => DropdownMenuItem(
                        value: profession,
                        child: Text(profession),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == 'Other') {
                    final custom = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String input = '';
                        return AlertDialog(
                          title: const Text('Enter Profession'),
                          content: TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Profession name',
                            ),
                            onChanged: (v) => input = v,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(input.trim()),
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                    if (custom != null && custom.isNotEmpty) {
                      setState(() {
                        _selectedProfession = 'Other';
                        _customProfession = custom;
                      });
                    } else {
                      setState(() {
                        _selectedProfession = null;
                        _customProfession = null;
                      });
                    }
                  } else {
                    setState(() {
                      _selectedProfession = value;
                      _customProfession = null;
                    });
                  }
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate() || _dob == null) {
                          return;
                        }
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm Registration'),
                            content: const Text(
                              'Are you sure you want to submit this staff registration?',
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
                        if (confirm != true) return;
                        setState(() => _isLoading = true);
                        final staffData = {
                          'fullName': _nameController.text.trim(),
                          'dateOfBirth': _dob,
                          'staffId': _staffIdController.text.trim(),
                          'department': _departmentController.text.trim(),
                          'profession': _selectedProfession == 'Other'
                              ? _customProfession
                              : _selectedProfession,
                          'phone': _phoneController.text.trim(),
                          'email': _emailController.text.trim(),
                          'status': 'pending',
                          'createdAt': DateTime.now(),
                        };
                        try {
                          final collection =
                              '${widget.facilityName.toLowerCase().replaceAll(' ', '_')}_users';
                          await FirebaseFirestore.instance
                              .collection(collection)
                              .add(staffData);
                          final setupLink =
                              'https://lifecare-connect.web.app/staff-setup?staffId=${_staffIdController.text.trim()}';
                          await sendStaffSetupPasswordEmail(
                            email: _emailController.text.trim(),
                            name: _nameController.text.trim(),
                            staffId: _staffIdController.text.trim(),
                            setupLink: setupLink,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Account request submitted. Staff will receive an email to set up their password.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                        setState(() => _isLoading = false);
                      },
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Registration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
