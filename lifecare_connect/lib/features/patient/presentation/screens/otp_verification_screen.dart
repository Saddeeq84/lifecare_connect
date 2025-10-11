// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phone;

  const OTPVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  int _retryCount = 0;
  bool _otpBlocked = false;
  bool loading = false;
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;
  late String _verificationId;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() => _canResend = true);
        _timer?.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> verifyOTP() async {
    if (_otpBlocked) return;

    final otp = otpController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      UserCredential userCred = await FirebaseAuth.instance
          .signInWithCredential(credential);

      // Link email if valid and not already linked
      if (email.isNotEmpty && password.length >= 6) {
        try {
          final emailCred = EmailAuthProvider.credential(
            email: email,
            password: password,
          );
          if (userCred.user != null) {
            await userCred.user!.linkWithCredential(emailCred);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User not found. Cannot link credentials.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          // email already linked or weak password
        }
      }

      // Save user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user?.uid ?? '')
          .set({
            'uid': userCred.user?.uid ?? '',
            'phone': userCred.user?.phoneNumber ?? '',
            'email': email.isNotEmpty ? email : null,
            'role': 'patient',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      Navigator.pushReplacementNamed(context, '/patient_dashboard');
    } on FirebaseAuthException catch (e) {
      _retryCount++;
      if (_retryCount >= 3) {
        setState(() => _otpBlocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many failed attempts. Resend OTP.'),
          ),
        );
      } else {
        String msg = e.message ?? 'OTP verification failed';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> resendOTP() async {
    setState(() {
      _canResend = false;
      _secondsRemaining = 60;
      _otpBlocked = false;
      _retryCount = 0;
    });

    _startTimer();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pushReplacementNamed(context, '/patient_dashboard');
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Resend failed')));
      },
      codeSent: (String newVerificationId, int? resendToken) {
        setState(() => _verificationId = newVerificationId);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('📩 OTP resent')));
      },
      codeAutoRetrievalTimeout: (String newVerificationId) {
        setState(() => _verificationId = newVerificationId);
      },
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Verify OTP'),
            backgroundColor: Colors.teal,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Enter OTP sent to ${widget.phone}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_otpBlocked,
                  decoration: const InputDecoration(labelText: 'OTP'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Link Email (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Create Password (min 6 chars)',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: loading || _otpBlocked ? null : verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size.fromHeight(45),
                  ),
                  child: const Text('Verify'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _canResend ? resendOTP : null,
                  child: Text(
                    _canResend
                        ? 'Resend OTP'
                        : 'Resend in $_secondsRemaining seconds',
                  ),
                ),
              ],
            ),
          ),
        ),
        if (loading)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}
