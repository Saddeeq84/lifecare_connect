// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isPhoneMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _verificationId;
  bool _codeSent = false;
  final _codeController = TextEditingController();

  void _switchMode(bool usePhone) {
    setState(() => _isPhoneMode = usePhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _codeController.dispose();
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

  Future<void> _handleEmailRegister() async {
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
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isLoading = true);
    // Normalize phone number
    final inputPhone = _phoneController.text.trim();
    String normalizedPhone = inputPhone;
    if (inputPhone.startsWith('0')) {
      normalizedPhone = '+234${inputPhone.substring(1)}';
    } else if (inputPhone.startsWith('234')) {
      normalizedPhone = '+234${inputPhone.substring(3)}';
    }
    // Check for duplicate phone number
    final existing = await FirebaseFirestore.instance.collection('users')
      .where('phone', isEqualTo: normalizedPhone)
      .get();
    if (existing.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Already Used'),
          content: const Text('This phone number is already registered by someone. Please use a different number.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': normalizedPhone,
          'address': _addressController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
          'dateOfBirth': Timestamp.fromDate(_selectedDate!),
          'gender': _selectedGender,
          'role': 'patient',
          'isApproved': true,
          'registeredBy': 'self',
          'createdAt': FieldValue.serverTimestamp(),
          'emailVerified': false,
        });
        await user.sendEmailVerification();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'patient');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please verify your email before logging in.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handlePhoneRegister() async {
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
    // Normalize Nigerian phone numbers to E.164 format
    String phone = _phoneController.text.trim().replaceAll(' ', '');
    final localPattern = RegExp(r'^0([789][01]\d{8})$');
    final intlPattern = RegExp(r'^\+234[789][01]\d{8}$');
    if (localPattern.hasMatch(phone)) {
      phone = '+234' + phone.substring(1);
    }
    if (!intlPattern.hasMatch(phone)) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Phone Number'),
          content: const Text('Please enter a valid Nigerian phone number in the format +23470..., 070..., or 081...'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    // Check for duplicate phone number
    final existing = await FirebaseFirestore.instance.collection('users')
      .where('phone', isEqualTo: phone)
      .limit(1)
      .get();
    if (existing.docs.isNotEmpty) {
      setState(() => _isLoading = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Exists'),
          content: const Text('This phone number is already registered. Please use a different number.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    // Use Firebase Phone Auth for OTP verification
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        setState(() => _isLoading = false);
        await _completeRegistration(phone);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Phone verification failed: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _submitCode() async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() => _isLoading = false);
      await _completeRegistration(_phoneController.text.trim());
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying code: $e')),
      );
    }
  }

  Future<void> _completeRegistration(String phone) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final patientUser = currentUser;
    if (patientUser != null) {
      final patientData = {
        'uid': patientUser.uid,
        'name': _nameController.text.trim(),
        'phone': phone,
        'role': 'patient',
        'createdAt': FieldValue.serverTimestamp(),
        'isApproved': true,
        'registeredBy': 'self',
      };
      await FirebaseFirestore.instance.collection('users').doc(patientUser.uid).set(patientData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please login.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // close dialog
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: No user found.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        centerTitle: true,
        title: const Text('Create Patient Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ToggleButtons(
                isSelected: [!_isPhoneMode, _isPhoneMode],
                onPressed: (index) => _switchMode(index == 1),
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: Colors.teal,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Email Registration'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Phone Registration'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. 07012345678, +2347012345678',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter phone number';
                        final localPattern = RegExp(r'^(0[789][01]\d{8})$');
                        final intlPattern = RegExp(r'^\+234[789][01]\d{8}$');
                        if (!localPattern.hasMatch(val) && !intlPattern.hasMatch(val)) {
                          return 'Enter a valid Nigerian phone number (e.g. 070..., +23470...)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!_isPhoneMode) ...[
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (val) => val != null && val.length >= 6 ? null : 'Minimum 6 characters',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        validator: (val) => val != _passwordController.text ? 'Passwords do not match' : null,
                      ),
                    ],
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
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
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Male', 'Female', 'Other'].map((gender) {
                        return DropdownMenuItem(value: gender, child: Text(gender));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedGender = value),
                      validator: (value) => value == null ? 'Please select gender' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _emergencyContactController,
                      decoration: const InputDecoration(labelText: 'Emergency Contact (optional)'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Account Creation'),
                                  content: const Text('Are you sure you want to create this patient account?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                _isPhoneMode
                                  ? await _handlePhoneRegister()
                                  : await _handleEmailRegister();
                              }
                            },
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 20),
                    // In phone registration mode, show code input after code is sent
                    if (_isPhoneMode && _codeSent) ...[
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Enter verification code",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.verified_user),
                        onPressed: _isLoading ? null : _submitCode,
                        label: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text("Verify Code"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
