// ignore_for_file: use_build_context_synchronously, avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../shared/data/services/user_service.dart';
import 'chw_create_account.dart';

class CHWLoginScreen extends StatefulWidget {
  const CHWLoginScreen({super.key});

  @override
  State<CHWLoginScreen> createState() => _CHWLoginScreenState();
}

class _CHWLoginScreenState extends State<CHWLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      _showSnackBar('Firebase init failed: $e');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final user = await _authService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (user == null) {
        _showSnackBar('Login failed. Try again.');
        setState(() => isLoading = false);
        return;
      }

      // CHWs don't need email verification - skip this check
      // if (!user.emailVerified) {
      //   _showSnackBar('Please verify your email before logging in.');
      //   setState(() => isLoading = false);
      //   return;
      // }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        _showSnackBar('No user profile found. Contact admin.');
        setState(() => isLoading = false);
        return;
      }

      final data = doc.data()!;
      final role = data['role'];
      final isApproved = data['isApproved'] ?? false;

      if (role == null || role.toString().trim().isEmpty) {
        _showSnackBar('No role assigned to this account. Contact admin.');
        setState(() => isLoading = false);
        return;
      }

      if (['chw', 'doctor', 'facility'].contains(role) && !isApproved) {
        _showSnackBar('Your account is pending admin approval.');
        setState(() => isLoading = false);
        return;
      }

      print('✅ CHW role detected: $role');
      await _userService.saveUserRole(role);
      await _userService.navigateBasedOnRole(context);
    } catch (e) {
      _showSnackBar('Login failed: ${_extractMessage(e)}');
      setState(() => isLoading = false);
    }
  }

  Future<void> handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};
      final role = data['role'];
      final isApproved = data['isApproved'] ?? false;

      if (role == null || role.toString().trim().isEmpty) {
        _showSnackBar('No role assigned to this account. Contact admin.');
        setState(() => isLoading = false);
        return;
      }

      if (['chw', 'doctor', 'facility'].contains(role) && !isApproved) {
        _showSnackBar('Your account is pending admin approval.');
        await _authService.signOut();
        setState(() => isLoading = false);
        return;
      }

      print('✅ Google login role: $role');
      await _userService.saveUserRole(role);
      await _userService.navigateBasedOnRole(context);
    } catch (e) {
      _showSnackBar('Google sign-in failed: ${_extractMessage(e)}');
      setState(() => isLoading = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (!email.contains('@')) {
      _showSnackBar('Enter a valid email address');
      return;
    }

    try {
      await _authService.sendPasswordReset(email);
      _showSnackBar('Password reset email sent.');
    } catch (e) {
      _showSnackBar('Failed to send reset email: ${_extractMessage(e)}');
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final user = _authService.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnackBar('Verification email sent.');
      } else {
        _showSnackBar('Email is already verified or not signed in.');
      }
    } catch (e) {
      _showSnackBar('Could not send verification email: ${_extractMessage(e)}');
    }
  }

  String _extractMessage(dynamic e) {
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Removed unused height variable

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('CHW Login', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'LifeCare Connect',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'CHW Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator: (value) =>
                          value == null || !value.contains('@')
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? 'Enter 6+ character password'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: isLoading ? null : handleLogin,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: isLoading ? null : resetPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : handleGoogleSignIn,
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in with Google'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CHWCreateAccountScreen(),
                          ),
                        );
                      },
                child: const Text(
                  "Don't have an account? Create CHW account",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
