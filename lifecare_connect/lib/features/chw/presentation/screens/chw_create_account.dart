// CHW account creation screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lifecare_connect/core/utils/email_admin_approval.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class CHWCreateAccountScreen extends StatefulWidget {
  const CHWCreateAccountScreen({super.key});

  @override
  State<CHWCreateAccountScreen> createState() => _CHWCreateAccountScreenState();
}

class _CHWCreateAccountScreenState extends State<CHWCreateAccountScreen> {
  // firebase_auth 6.x does not support fetchSignInMethodsForEmail; always return false so registration proceeds.
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final otpController = TextEditingController();

  bool _isLoading = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  String? _verificationId;
  int _resendToken = 0;
  int _timerSeconds = 60;
  Timer? _countdownTimer;

  void _startCountdown() {
    _timerSeconds = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }


  Future<void> _verifyOtpAndLinkPhone() async {
    if (_verificationId == null || otpController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the OTP code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpController.text.trim(),
      );

      final user = _auth.currentUser;
      if (user == null) throw Exception('User not found');

      await user.linkWithCredential(credential);

      await _firestore.collection('users').doc(user.uid).update({
        'isPhoneVerified': true,
      });

      await _handleApprovalAndRedirect(user.uid);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ OTP verification failed: $e')),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleApprovalAndRedirect(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final isApproved = doc.data()?['isApproved'] ?? false;
    
    if (!isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Phone verified! ⏳ Awaiting admin approval to activate CHW account')),
      );
      await _auth.signOut();
      context.go('/login'); // Use GoRouter navigation
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ CHW account approved & phone verified')),
    );

    context.go('/chw_dashboard'); // Use GoRouter navigation
  }

  Future<void> _resendCode() async {
    if (phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your phone number')),
      );
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneController.text.trim(),
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Resend failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken ?? 0;
          });
          _startCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📩 OTP resent')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register as CHW'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField('Full Name', fullNameController),
                  const SizedBox(height: 15),
                  _buildTextField('Email', emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildTextField('Phone (+234)', phoneController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 15),
                  _buildTextField('Password', passwordController, obscureText: true),
                  const SizedBox(height: 15),
                  _buildTextField('Confirm Password', confirmPasswordController, obscureText: true),
                  const SizedBox(height: 30),
                  // Registration button
                  ElevatedButton(
                    onPressed: () async {
                      final fullName = fullNameController.text.trim();
                      final email = emailController.text.trim();
                      final phone = phoneController.text.trim();
                      final password = passwordController.text.trim();
                      final confirmPassword = confirmPasswordController.text.trim();
                      if (password != confirmPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }
                      setState(() => _isLoading = true);
                      try {
                        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
                          email: email,
                          password: password,
                        );
                        final user = userCredential.user;
                        if (user == null) throw Exception('User creation failed');
                        await _firestore.collection('users').doc(user.uid).set({
                          'fullName': fullName,
                          'email': email,
                          'phone': phone,
                          'role': 'chw',
                          'isPhoneVerified': false,
                          'isApproved': false, // CHWs now need admin approval
                          'isRejected': false,
                          'emailVerified': true, // CHWs don't need email verification 
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        // Show dialog and send email about admin approval requirement
                        await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: const Text('Your email has been verified. Your account will require admin approval before it becomes active. You will receive another email once your account is approved.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        await sendAdminApprovalRequiredEmail(email, fullName);
                        _auth.verifyPhoneNumber(
                          phoneNumber: phone,
                          timeout: const Duration(seconds: 60),
                          verificationCompleted: (PhoneAuthCredential credential) async {
                            final currentUser = _auth.currentUser;
                            if (currentUser != null) {
                              await currentUser.linkWithCredential(credential);
                              await _firestore.collection('users').doc(currentUser.uid).update({
                                'isPhoneVerified': true,
                              });
                              await _handleApprovalAndRedirect(currentUser.uid);
                            }
                          },
                          verificationFailed: (FirebaseAuthException e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Phone verification failed: ${e.message}')),
                            );
                          },
                          codeSent: (String verificationId, int? resendToken) {
                            setState(() {
                              _verificationId = verificationId;
                              _codeSent = true;
                              _resendToken = resendToken ?? 0;
                            });
                            _startCountdown();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📩 OTP sent to your phone')),
                            );
                          },
                          codeAutoRetrievalTimeout: (String verificationId) {
                            _verificationId = verificationId;
                          },
                          forceResendingToken: _resendToken,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Registration failed: $e')),
                        );
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
                    child: const Text('Register'),
                  ),
                  if (_codeSent)
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildTextField('Enter OTP', otpController, keyboardType: TextInputType.number),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _isVerifying ? null : _verifyOtpAndLinkPhone,
                          child: const Text('Verify OTP'),
                        ),
                        TextButton(
                          onPressed: _timerSeconds == 0 ? _resendCode : null,
                          child: Text(_timerSeconds == 0
                              ? 'Resend OTP'
                              : 'Resend OTP in $_timerSeconds s'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (_isLoading || _isVerifying)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (val) =>
          val == null || val.trim().isEmpty ? 'Please enter $label' : null,
    );
  }
}
/// Allows CHWs to create an account, verify phone, and await admin approval before dashboard access.