
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emergencyContactController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  String? selectedGender;
  DateTime? selectedDate;

  String verificationId = '';
  bool isPhoneMode = false; // Always default to email mode
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  void switchMode(bool usePhone) {
    setState(() => isPhoneMode = usePhone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        centerTitle: true,
        title: const Text('Register as Patient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ToggleButtons(
                isSelected: [!isPhoneMode, isPhoneMode],
                onPressed: (index) => switchMode(index == 1),
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
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (val) => val == null || val.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. 08012345678, 08123456789, 2348012345678, +2348012345678',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter phone number';
                        // Accept 080..., 081..., 090..., 070..., 23480..., +23480..., etc.
                        final regex = RegExp(r'^(0[789][01]\d{8}|234[789][01]\d{8}|\+234[789][01]\d{8})$');
                        if (!regex.hasMatch(val)) return 'Enter a valid Nigerian phone number.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!isPhoneMode) ...[
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (val) => val != null && val.contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (val) => val != null && val.length >= 6 ? null : 'Minimum 6 characters',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        validator: (val) => val != passwordController.text ? 'Passwords do not match' : null,
                      ),
                    ],
                    // Add DOB, Gender, Address, Emergency Contact for both tabs
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => selectedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date of Birth'),
                        child: Text(selectedDate == null ? 'Select date' : '${selectedDate!.toLocal()}'.split(' ')[0]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) => setState(() => selectedGender = val),
                      validator: (val) => val == null ? 'Select gender' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (val) => val == null || val.isEmpty ? 'Enter address' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emergencyContactController,
                      decoration: const InputDecoration(labelText: 'Emergency Contact (optional)'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: isLoading
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
                                isPhoneMode
                                  ? verifyPhoneAndRegister()
                                  : handleEmailRegister();
                              }
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Create Account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> handleEmailRegister() async {
  if (!formKey.currentState!.validate()) return;
  if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }
  if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }
  if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
  setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = credential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullName': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'emergencyContact': emergencyContactController.text.trim(),
          'dateOfBirth': selectedDate,
          'gender': selectedGender,
          'role': 'patient',
          'createdBy': 'self',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Patient account created! Please verify your email.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    }
  setState(() => isLoading = false);
  }

  Future<void> verifyPhoneAndRegister() async {
  if (!formKey.currentState!.validate()) return;
  setState(() => isLoading = true);
  // Check for duplicate phone number
  final inputPhone = phoneController.text.trim();
  String normalizedPhone = inputPhone;
  if (inputPhone.startsWith('0')) {
    normalizedPhone = '+234' + inputPhone.substring(1);
  } else if (inputPhone.startsWith('234')) {
    normalizedPhone = '+234' + inputPhone.substring(3);
  }
  // Query Firestore for existing phone
  final existing = await FirebaseFirestore.instance.collection('users')
    .where('phone', isEqualTo: normalizedPhone)
    .get();
  if (existing.docs.isNotEmpty) {
    setState(() => isLoading = false);
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
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _savePatientToFirestorePhone();
        if (mounted) Navigator.pop(context);
      },
      verificationFailed: (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      },
      codeSent: (verificationId, _) {
        setState(() => isLoading = false);
        _showCodeDialog(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  } catch (e) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
  }

  void _showCodeDialog(String verificationId) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter Verification Code'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => isLoading = true);
              try {
                final credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: codeController.text.trim(),
                );
                await FirebaseAuth.instance.signInWithCredential(credential);
                await _savePatientToFirestorePhone();
                Navigator.pop(context); // close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Phone verification successful')),
                );
                setState(() => isLoading = false);
                Navigator.pop(context); // back to login/home
              } catch (e) {
                setState(() => isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Verification failed: $e')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatientToFirestorePhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fullName': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'role': 'patient',
      'createdBy': 'self',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
/// Patient registration screen supporting email and phone registration modes.