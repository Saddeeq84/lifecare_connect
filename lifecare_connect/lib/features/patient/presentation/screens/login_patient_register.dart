
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
  bool isPhoneMode = false;
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
                    child: Text('Use Email'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Use Phone'),
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
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                      validator: (val) => val != null && val.length >= 10 ? null : 'Enter a valid phone number',
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
                        // Add toggle for password visibility if needed
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        validator: (val) => val != passwordController.text ? 'Passwords do not match' : null,
                        // Add toggle for confirm password visibility if needed
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size.fromHeight(45),
                      ),
            onPressed: isLoading
              ? null
              : () => isPhoneMode
                ? verifyPhoneAndRegister()
                : handleEmailRegister(),
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
        await FirebaseFirestore.instance.collection('user').doc(user.uid).set({
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
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneController.text.trim(),
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
    await FirebaseFirestore.instance.collection('user').doc(user.uid).set({
      'fullName': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'role': 'patient',
      'createdBy': 'self',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
/// Patient registration screen supporting email and phone registration modes.