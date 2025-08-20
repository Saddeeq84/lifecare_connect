// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:cloud_functions/cloud_functions.dart";

class PatientRegistrationScreen extends StatelessWidget {
  final bool isCHW;
  
  const PatientRegistrationScreen({super.key, this.isCHW = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isCHW ? 'Register New Patient' : 'Create Account'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
      ),
      body: SafeArea(
        child: _PatientRegistrationForm(isCHW: isCHW),
      ),
    );
  }
}

class _PatientRegistrationForm extends StatefulWidget {
  final bool isCHW;
  
  const _PatientRegistrationForm({required this.isCHW});

  @override
  State<_PatientRegistrationForm> createState() => _PatientRegistrationFormState();
}

class _PatientRegistrationFormState extends State<_PatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  TextEditingController? _passwordController;
  TextEditingController? _confirmPasswordController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedGender;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    if (!widget.isCHW) {
      _passwordController = TextEditingController();
      _confirmPasswordController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    if (_passwordController != null) _passwordController!.dispose();
    if (_confirmPasswordController != null) _confirmPasswordController!.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _registerPatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isCHW) {
        // CHW: Only create Firestore record, do not create Firebase Auth user
        await FirebaseFirestore.instance.collection('pending_patients').add({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
          'dateOfBirth': Timestamp.fromDate(_selectedDate!),
          'gender': _selectedGender,
          'role': 'patient',
          'isApproved': false,
          'registeredBy': 'CHW',
          'createdBy': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });
        // Call Firebase Cloud Function to send invitation email
        try {
          // Call the function in the correct region to avoid CORS/region errors
          await FirebaseFunctions.instanceFor(region: 'europe-west2')
            .httpsCallable('sendPatientInviteEmail')
            .call({
              'email': _emailController.text.trim(),
              'name': _nameController.text.trim(),
            });
        } catch (e) {
          // Optionally handle errors, but don't block registration
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'patient');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient registered! Invitation email sent.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Self-registration: create Firebase Auth user as before
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController!.text.trim(),
        );
        if (credential.user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .set({
            'uid': credential.user!.uid,
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'emergencyContact': _emergencyContactController.text.trim(),
            'dateOfBirth': Timestamp.fromDate(_selectedDate!),
            'gender': _selectedGender,
            'role': 'patient',
            'isApproved': true,
            'registeredBy': 'self',
            'createdBy': credential.user!.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'emailVerified': false,
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', 'patient');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString()}'),
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
            // Header
            if (widget.isCHW) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Registering a new patient in the healthcare system',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Personal Information
            Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Please enter full name' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) return 'Please enter email';
                if (!value!.contains('@')) return 'Please enter valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Please enter phone number' : null,
            ),
            const SizedBox(height: 16),

            // Date of Birth
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of Birth *',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedDate == null 
                      ? 'Select date of birth'
                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null ? Colors.grey : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gender
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                prefixIcon: Icon(Icons.people),
                border: OutlineInputBorder(),
              ),
              items: ['Male', 'Female', 'Other'].map((gender) {
                return DropdownMenuItem(value: gender, child: Text(gender));
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
              validator: (value) => value == null ? 'Please select gender' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emergencyContactController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact',
                prefixIcon: Icon(Icons.emergency),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Account Information
            Text(
              'Account Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (!widget.isCHW) ...[
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Please enter password';
                  if (value!.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) return 'Please confirm password';
                  if (value != _passwordController!.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 32),
            ],

            // Register Button
            ElevatedButton(
              onPressed: _isLoading ? null : _registerPatient,
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
                  : Text(
                      widget.isCHW ? 'Register Patient' : 'Create Account',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
