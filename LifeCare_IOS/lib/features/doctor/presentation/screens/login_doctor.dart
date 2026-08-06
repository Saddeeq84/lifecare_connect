import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doctor_create_account.dart';
import 'package:go_router/go_router.dart';
import 'package:lifecare_connect/features/admin/services/auto_repair_missing_users_service.dart';

class LoginDoctorScreen extends StatefulWidget {
  const LoginDoctorScreen({super.key});

  @override
  State<LoginDoctorScreen> createState() => _LoginDoctorScreenState();
}

class _LoginDoctorScreenState extends State<LoginDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _autoRepair = AutoRepairMissingUsersService();

  bool loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        // Auto-dismiss after 10 seconds
        Future.delayed(const Duration(seconds: 10), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Login Failed'),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      // CRITICAL: Clear any previous facility staff session data from SharedPreferences
      // This prevents conflicts when the same email is used for both doctor and facility staff
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('staff_id');
      await prefs.remove('staff_name');
      await prefs.remove('staff_profession');
      await prefs.remove('facility_id');
      await prefs.remove('facility_name');
      await prefs.remove('facility_type');

      // Step 1: Authenticate with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Step 2: Check approval status in Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        // AUTO-REPAIR: Attempt to create missing Firestore document

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account data missing. Attempting automatic repair...',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }

        final repaired = await _autoRepair.repairMissingUser(
          emailController.text.trim(),
          userCredential.user!.uid,
        );

        if (repaired) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account repaired successfully! Please log in again.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }

          await _auth.signOut();
          setState(() => loading = false);
          return;
        } else {
          await _auth.signOut();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account data not found and repair failed. Please contact admin.',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() => loading = false);
          return;
        }
      }

      final userData = userDoc.data()!;
      final isApproved = userData['isApproved'] ?? false;
      final isRejected = userData['isRejected'] ?? false;

      // Step 3: Check if account is rejected
      if (isRejected) {
        await _auth.signOut();
        final rejectionReason =
            userData['rejectionReason'] ?? 'No reason provided';
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Rejected'),
              content: Text(
                'Your account has been rejected by admin.\n\nReason: $rejectionReason\n\nPlease contact admin for more information.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() => loading = false);
        return;
      }

      // Step 4: Check if account is approved
      if (!isApproved) {
        await _auth.signOut();
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Account Pending Approval'),
              content: const Text(
                'Your account is awaiting admin approval. You will receive an email notification once your account is approved.\n\nPlease check back later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        setState(() => loading = false);
        return;
      }

      // Step 5: Account approved - navigate to dashboard
      if (mounted) {
        context.go('/doctor_dashboard');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Wrong email/password, please try again';
        if (e.code == 'network-request-failed') {
          message = 'Network error. Please check your connection and try again';
        } else if (e.code == 'too-many-requests') {
          message = 'Too many failed attempts. Please try again later';
        }
        _showErrorDialog(message);
      }
      setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An unexpected error occurred. Please try again');
      }
      setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset email sent. Check your inbox.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reset email: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doctor Login',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.teal,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  child: const Text(
                    'Welcome back, Doctor!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Minimum 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            minimumSize: const Size.fromHeight(45),
                          ),
                          onPressed: loading ? null : handleLogin,
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DoctorCreateAccountScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Don't have an account? Create Doctor account",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
