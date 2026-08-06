import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  final codeController = TextEditingController();
  bool codeSent = false;
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
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Enter phone number';
                        }
                        // Accept any 11-digit starting with 0, 13-digit starting with 234, or 14-digit starting with +234
                        final regex = RegExp(
                          r'^(0\d{10}|234\d{10}|\+234\d{10})$',
                        );
                        if (!regex.hasMatch(val)) {
                          return 'Enter a valid Nigerian phone number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!isPhoneMode) ...[
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (val) => val != null && val.contains('@')
                            ? null
                            : 'Enter a valid email',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (val) => val != null && val.length >= 6
                            ? null
                            : 'Minimum 6 characters',
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                        ),
                        validator: (val) => val != passwordController.text
                            ? 'Passwords do not match'
                            : null,
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
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                        ),
                        child: Text(
                          selectedDate == null
                              ? 'Select date'
                              : '${selectedDate!.toLocal()}'.split(' ')[0],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['Male', 'Female', 'Other']
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => selectedGender = val),
                      validator: (val) => val == null ? 'Select gender' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter address' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emergencyContactController,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact (optional)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isPhoneMode && !codeSent) ...[
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
                                    title: const Text(
                                      'Confirm Account Creation',
                                    ),
                                    content: const Text(
                                      'A verification code will be sent to your phone. Proceed?',
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
                                if (confirmed != true) return;
                                if (!formKey.currentState!.validate()) return;
                                setState(() => isLoading = true);
                                // Normalize phone number
                                final inputPhone = phoneController.text.trim();
                                String normalizedPhone = inputPhone;
                                if (inputPhone.startsWith('0')) {
                                  normalizedPhone =
                                      '+234${inputPhone.substring(1)}';
                                } else if (inputPhone.startsWith('234')) {
                                  normalizedPhone =
                                      '+234${inputPhone.substring(3)}';
                                }
                                // Query Firestore for existing phone
                                final existing = await FirebaseFirestore
                                    .instance
                                    .collection('users')
                                    .where('phone', isEqualTo: normalizedPhone)
                                    .get();
                                if (existing.docs.isNotEmpty) {
                                  setState(() => isLoading = false);
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Phone Number Already Used',
                                      ),
                                      content: const Text(
                                        'This phone number is already registered by someone. Please use a different number.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                                // Send OTP via Termii
                                try {
                                  print(
                                    '📞 Sending registration OTP to: $normalizedPhone',
                                  );

                                  final callable = FirebaseFunctions.instance
                                      .httpsCallable('sendPatientOTP');
                                  final result = await callable.call({
                                    'phoneNumber': normalizedPhone,
                                    'name': nameController.text.trim(),
                                  });

                                  final data =
                                      result.data as Map<String, dynamic>;
                                  print('✅ OTP send result: $data');

                                  if (data['success'] == true) {
                                    setState(() {
                                      codeSent = true;
                                      isLoading = false;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ Verification code sent to $normalizedPhone',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    setState(() => isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to send OTP: ${data['message'] ?? 'Unknown error'}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isLoading = false);
                                  print('❌ Error sending OTP: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error sending OTP: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Create Account'),
                      ),
                    ],
                    if (isPhoneMode && codeSent) ...[
                      TextFormField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter verification code',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.verified_user),
                        onPressed: isLoading
                            ? null
                            : () async {
                                setState(() => isLoading = true);
                                try {
                                  // Normalize phone number
                                  String normalizedPhone = phoneController.text
                                      .trim();
                                  if (normalizedPhone.startsWith('0')) {
                                    normalizedPhone =
                                        '+234${normalizedPhone.substring(1)}';
                                  } else if (normalizedPhone.startsWith(
                                    '234',
                                  )) {
                                    normalizedPhone = '+$normalizedPhone';
                                  } else if (!normalizedPhone.startsWith('+')) {
                                    normalizedPhone = '+234$normalizedPhone';
                                  }

                                  print(
                                    '🔍 Verifying OTP for: $normalizedPhone with code: ${codeController.text.trim()}',
                                  );

                                  // Verify OTP via Termii and create user account
                                  final callable = FirebaseFunctions.instance
                                      .httpsCallable('verifyPatientOTP');
                                  final result = await callable.call({
                                    'phoneNumber': normalizedPhone,
                                    'code': codeController.text.trim(),
                                    'userData': {
                                      'fullName': nameController.text.trim(),
                                      'address': addressController.text.trim(),
                                      'emergencyContact':
                                          emergencyContactController.text
                                              .trim(),
                                      'gender': selectedGender ?? '',
                                      'dateOfBirth': selectedDate
                                          ?.toIso8601String(),
                                    },
                                  });

                                  final data =
                                      result.data as Map<String, dynamic>;
                                  print('✅ OTP verification result: $data');

                                  if (data['success'] == true &&
                                      data['valid'] == true) {
                                    // OTP verified and user created successfully
                                    // Clear form fields
                                    nameController.clear();
                                    phoneController.clear();
                                    emailController.clear();
                                    addressController.clear();
                                    emergencyContactController.clear();
                                    passwordController.clear();
                                    confirmPasswordController.clear();
                                    codeController.clear();

                                    setState(() {
                                      selectedGender = null;
                                      selectedDate = null;
                                      codeSent = false;
                                      verificationId = '';
                                      isLoading = false;
                                    });

                                    if (mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Success'),
                                          content: const Text(
                                            '✅ Patient account created successfully!',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text(
                                                'Proceed to Login',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } else {
                                    setState(() => isLoading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          data['message'] ?? 'Invalid OTP',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isLoading = false);
                                  print('❌ OTP verification error: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Verification failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        label: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                    if (!isPhoneMode) ...[
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
                                    title: const Text(
                                      'Confirm Account Creation',
                                    ),
                                    content: const Text(
                                      'Are you sure you want to create this patient account?',
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
                                  handleEmailRegister();
                                }
                              },
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Create Account'),
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

  Future<void> handleEmailRegister() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }
    if (selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
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
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Account Created'),
            content: const Text(
              'Your account was created successfully! Please verify your email using the link sent to your inbox. If you do not see the email, check your spam folder.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    }
    setState(() => isLoading = false);
  }

  Future<void> verifyPhoneAndRegister() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => isLoading = true);
    // Normalize phone number
    final inputPhone = phoneController.text.trim();
    String normalizedPhone = inputPhone;
    if (inputPhone.startsWith('0')) {
      normalizedPhone = '+234${inputPhone.substring(1)}';
    } else if (inputPhone.startsWith('234')) {
      normalizedPhone = '+$inputPhone';
    } else if (!inputPhone.startsWith('+')) {
      normalizedPhone = '+234$inputPhone';
    }

    // Query Firestore for existing phone
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: normalizedPhone)
        .get();
    if (existing.docs.isNotEmpty) {
      setState(() => isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Already Used'),
          content: const Text(
            'This phone number is already registered by someone. Please use a different number.',
          ),
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

    // Send OTP via Termii (not Firebase Auth)
    // The OTP sending and verification is handled by the buttons in the UI
    setState(() => isLoading = false);
  }
}

/// Patient registration screen supporting email and phone registration modes.
