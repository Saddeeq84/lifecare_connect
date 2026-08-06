// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'login_patient_register.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LoginPatientPhone extends StatefulWidget {
  const LoginPatientPhone({super.key});

  @override
  State<LoginPatientPhone> createState() => _LoginPatientPhoneState();
}

class _LoginPatientPhoneState extends State<LoginPatientPhone> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

  String formatPhoneNumber(String input) {
    String phone = input.replaceAll(RegExp(r'\s+|-'), '');
    // Always convert 11-digit local Nigerian numbers to E.164 format
    if (RegExp(r'^0\d{10}$').hasMatch(phone)) {
      phone = '+234${phone.substring(1)}';
    } else if (RegExp(r'^234\d{10}$').hasMatch(phone)) {
      phone = '+234${phone.substring(3)}';
    }
    return phone;
  }

  void _verifyPhone() async {
    final phoneNumber = formatPhoneNumber(_phoneController.text.trim());

    // Validate phone format
    if (!RegExp(r'^\+234\d{10}$').hasMatch(phoneNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid Nigerian phone number')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Call Termii Login OTP Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('sendLoginOTP');
      final result = await callable.call({'phoneNumber': phoneNumber});

      if (result.data['success'] == true) {
        setState(() {
          _codeSent = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login code sent! Valid for 10 minutes.')),
        );
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send code. Please try again.')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _signInWithCode() async {
    final phoneNumber = formatPhoneNumber(_phoneController.text.trim());
    final smsCode = _codeController.text.trim();

    if (smsCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the verification code.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      print('🔍 Verifying OTP for: $phoneNumber with code: $smsCode');

      // Verify OTP with Termii
      final verifyCallable = FirebaseFunctions.instance.httpsCallable(
        'verifyLoginOTP',
      );
      final verifyResult = await verifyCallable.call({
        'phoneNumber': phoneNumber,
        'code': smsCode,
      });

      print('✅ OTP verification result: ${verifyResult.data}');

      if (verifyResult.data['valid'] != true) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verifyResult.data['message'] ?? 'Invalid code'),
          ),
        );
        return;
      }

      print('🔍 Looking up user with phone: $phoneNumber');

      // OTP verified! Now find and sign in the user
      // Try multiple phone field names (phone, phoneNumber, contact)
      QuerySnapshot phoneQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      // If not found with 'phone', try 'phoneNumber'
      if (phoneQuery.docs.isEmpty) {
        print('🔍 Trying phoneNumber field...');
        phoneQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: phoneNumber)
            .limit(1)
            .get();
      }

      // If still not found, try 'contact'
      if (phoneQuery.docs.isEmpty) {
        print('🔍 Trying contact field...');
        phoneQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('contact', isEqualTo: phoneNumber)
            .limit(1)
            .get();
      }

      print('📝 Found ${phoneQuery.docs.length} users');

      if (phoneQuery.docs.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No account found with this phone number. Please register first.',
            ),
          ),
        );
        return;
      }

      // Get user data and ID
      final userData = phoneQuery.docs.first.data() as Map<String, dynamic>?;
      final userId = phoneQuery.docs.first.id;

      print('👤 User found: $userId, role: ${userData?['role']}');

      // Get user role, fallback to 'patient'
      String role = (userData?['role'] ?? 'patient').toString().toLowerCase();
      if (role.isEmpty) role = 'patient';

      // Save session info to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      await prefs.setString('user_phone', phoneNumber);
      await prefs.setString('user_role', role);

      // Ensure SharedPreferences is flushed to disk
      await prefs.reload();

      print('💾 Session saved. Redirecting to: $role dashboard');
      print('💾 Saved user_id: ${prefs.getString('user_id')}');
      print('💾 Saved user_role: ${prefs.getString('user_role')}');

      setState(() => _loading = false);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login successful! Redirecting...')),
        );
      }

      // Small delay to ensure SharedPreferences is saved before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      // Redirect based on role
      if (mounted) {
        switch (role) {
          case 'admin':
            context.go('/admin_dashboard');
            break;
          case 'doctor':
            context.go('/doctor_dashboard');
            break;
          case 'chw':
            context.go('/chw_dashboard');
            break;
          case 'facility':
            context.go('/facility_dashboard');
            break;
          case 'patient':
          default:
            context.go('/patient_dashboard');
            break;
        }
      }
    } catch (e) {
      print('❌ Login error: $e');
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}')));
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
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
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
                  MaterialPageRoute(
                    builder: (_) => const PatientRegisterScreen(),
                  ),
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
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
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
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: "Enter verification code",
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: _loading
              ? const SizedBox.shrink()
              : const Icon(Icons.verified_user),
          onPressed: _loading ? null : _signInWithCode,
          label: _loading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text("Verify Code"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          onPressed: _loading
              ? null
              : () {
                  setState(() {
                    _codeSent = false;
                    _codeController.clear();
                  });
                },
          label: const Text("Request New Code"),
          style: TextButton.styleFrom(foregroundColor: Colors.teal),
        ),
      ],
    );
  }
}
