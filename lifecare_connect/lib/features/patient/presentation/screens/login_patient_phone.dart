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
    // Always convert 11-digit local Nigerian numbers to E.164 format
    if (RegExp(r'^0\d{10}$').hasMatch(phone)) {
      phone = '+234${phone.substring(1)}';
    } else if (RegExp(r'^234\d{10}$').hasMatch(phone)) {
      phone = '+234${phone.substring(3)}';
    }
    // If already in E.164 format, keep as is
    // If not valid, return as is (Firebase will reject invalid format)
    print('DEBUG: Sending phone number to Firebase: $phone');
    return phone;
  }
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;

  void _verifyPhone() async {
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formatPhoneNumber(_phoneController.text.trim()),
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        // Wait for auth state to emit a non-null user before navigating
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null && mounted) {
            Navigator.pushReplacementNamed(context, '/patient_dashboard');
          }
        });
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
    if (_verificationId == null || _verificationId!.isEmpty) {
      debugPrint('[LOGIN] Verification ID is null or empty.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: Verification code not sent or expired. Please try again.')),
      );
      return;
    }

    final smsCode = _codeController.text.trim();
    if (smsCode.isEmpty) {
      debugPrint('[LOGIN] SMS code is empty.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the verification code.')),
      );
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    try {
      debugPrint('[LOGIN] Attempting signInWithCredential for verificationId=$_verificationId, smsCode=$smsCode');
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('[LOGIN] signInWithCredential result: $userCredential');
      final user = userCredential.user;
      if (user == null) {
        debugPrint('[LOGIN] FirebaseAuth returned null user for credential.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: No user found for this phone number. (Auth user is null)')),
        );
        return;
      }
      debugPrint('[LOGIN] Authenticated user UID: ${user.uid}, phone: ${user.phoneNumber}');
      // Fetch user role from Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        debugPrint('[LOGIN] Firestore userDoc.exists: ${userDoc.exists}');
        Map<String, dynamic>? userData;
        if (!userDoc.exists) {
          debugPrint('[LOGIN] No Firestore profile found for UID: ${user.uid}. Attempting phone lookup...');
          // Try to find user by phone number in E.164 format
          final phone = user.phoneNumber ?? '';
          final phoneQuery = await FirebaseFirestore.instance.collection('users')
              .where('phone', isEqualTo: phone)
              .limit(1)
              .get();
          if (phoneQuery.docs.isNotEmpty) {
            userData = phoneQuery.docs.first.data();
            debugPrint('[LOGIN] Found Firestore user by phone: $userData');
            // Optionally, migrate this user to correct UID
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userData);
          } else {
            debugPrint('[LOGIN] No Firestore profile found for phone: $phone');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: No profile found for this user in Firestore. UID: ${user.uid}, phone: $phone. Please contact support.')),
            );
            return;
          }
        } else {
          userData = userDoc.data();
          if (userData == null) {
            debugPrint('[LOGIN] Firestore user data is null for UID: ${user.uid}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: Firestore user data is null for UID: ${user.uid}.')),
            );
            return;
          }
          debugPrint('[LOGIN] Firestore user data: $userData');
        }
      // Defensive: fallback to 'patient' if role is missing or null
      String role = (userData['role'] ?? 'patient').toString().toLowerCase();
      if (role.isEmpty) role = 'patient';
      debugPrint('[LOGIN] Resolved role: $role');
      // Save role to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);
      debugPrint('[LOGIN] Saved role to SharedPreferences: $role');
      // Redirect based on role
      if (mounted) {
        debugPrint('[LOGIN] Redirecting user to dashboard for role: $role');
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
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Login failed: ';
      if (e.code == 'invalid-verification-code') {
        errorMsg += 'Invalid verification code. Please check and try again.';
      } else if (e.code == 'session-expired') {
        errorMsg += 'Session expired. Please request a new code.';
      } else {
        errorMsg += e.message ?? e.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
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
