import 'package:flutter/foundation.dart';
// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_patient_register.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
// // import '../sharedScreen/register_role_selection.dart'; // Broken import // Broken import

class LoginPatientPhone extends StatefulWidget {
  const LoginPatientPhone({super.key});

  @override
  State<LoginPatientPhone> createState() => _LoginPatientPhoneState();
}

class _LoginPatientPhoneState extends State<LoginPatientPhone> {
  final _phoneController = TextEditingController();
  String formatPhoneNumber(String input) {
    String phone = input.replaceAll(RegExp(r'\s+|-'), '');
    if (phone.startsWith('0') && phone.length == 11) {
      return '+234${phone.substring(1)}';
    }
    return phone;
  }
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;

  void _verifyPhone() async {
    setState(() => _loading = true);
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formatPhoneNumber(_phoneController.text.trim()),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        if (mounted) Navigator.pushReplacementNamed(context, '/patient_dashboard');
      },
      verificationFailed: (e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  void _signInWithCode() async {
    if (_verificationId == null) return;

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _codeController.text.trim(),
    );

    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        // Fetch user role from Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        String role = 'patient';
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          role = userData['role']?.toString().toLowerCase() ?? 'patient';
        }
        // Save role to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', role);
        // Redirect based on role
        if (mounted) {
          switch (role) {
            case 'admin':
              Navigator.pushReplacementNamed(context, '/admin_dashboard');
              break;
            case 'doctor':
              Navigator.pushReplacementNamed(context, '/doctor_dashboard');
              break;
            case 'chw':
              Navigator.pushReplacementNamed(context, '/chw_dashboard');
              break;
            case 'facility':
              Navigator.pushReplacementNamed(context, '/facility_dashboard');
              break;
            case 'patient':
            default:
              Navigator.pushReplacementNamed(context, '/patient_dashboard');
              break;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For web reCAPTCHA container
    final recaptchaWidget = kIsWeb ? Container(
      key: const ValueKey('recaptcha-container'),
      child: const SizedBox.shrink(),
    ) : const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Patient Phone Login"),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              recaptchaWidget,
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Text(
                      'LifeCare Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Connecting communities to quality healthcare',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _codeSent ? _buildCodeInput() : _buildPhoneInput(),
              const SizedBox(height: 30),
              const Divider(thickness: 1.2),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientRegisterScreen()),
                ),
                child: const Text(
                  "Don't have an account? Create one",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Enter phone number",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.send),
          onPressed: _loading ? null : _verifyPhone,
          label: _loading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
              : const Text("Send Verification Code"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Column(
      children: [
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
          onPressed: _signInWithCode,
          label: const Text("Verify Code"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
