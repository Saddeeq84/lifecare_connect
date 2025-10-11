// Facility Login Screen
// Handles authentication and navigation for facility users only.

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'owner_register_facility_screen.dart';

class FacilityLoginScreen extends StatefulWidget {
  const FacilityLoginScreen({super.key});

  @override
  State<FacilityLoginScreen> createState() => _FacilityLoginScreenState();
}

class _FacilityLoginScreenState extends State<FacilityLoginScreen> {
  Future<void> handleStaffLogin() async {
    setState(() => loading = true);
    final staffId = staffIdController.text.trim();
    final password = staffPasswordController.text.trim();
    const facilityName =
        'chana health center'; // TODO: Replace with actual selected facility
    final collection =
        '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';
    try {
      final query = await FirebaseFirestore.instance
          .collection(collection)
          .where('staffId', isEqualTo: staffId)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff not found or not approved.')),
        );
        return;
      }
      final staff = query.docs.first.data();
      if (staff['password'] != password) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect password.')));
        return;
      }
      // Save role and staff info to SharedPreferences if needed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'facility_staff');
      await prefs.setString('staff_id', staffId);
      // Navigate to staff dashboard
      Navigator.pushNamed(context, '/facility_staff_dashboard');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  bool isAdminLogin = true;
  final staffIdController = TextEditingController();
  final staffPasswordController = TextEditingController();
  // Firebase authentication instance
  final _auth = FirebaseAuth.instance;

  // Form key for login validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for email and password input fields
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // UI state variables
  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    // Dispose controllers to free resources
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Handles login logic and navigation for facility users
  Future<void> handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (credential.user != null) {
        await _navigateBasedOnRole(credential.user!.uid);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Navigates facility user to the dashboard and caches role
  Future<void> _navigateBasedOnRole(String uid) async {
    try {
      String role = 'facility';
      String route = '/facility_dashboard';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);

      if (mounted) {
        context.go(route);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error determining user role: $e')),
        );
      }
    }
  }

  // Sends password reset email to the entered address
  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
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
        title: const Text("Facility Login"),
        backgroundColor: Colors.teal.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Admin Login'),
                  selected: isAdminLogin,
                  onSelected: (v) => setState(() => isAdminLogin = true),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Staff Login'),
                  selected: !isAdminLogin,
                  onSelected: (v) => setState(() => isAdminLogin = false),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isAdminLogin)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
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
                        labelText: "Password",
                        border: const OutlineInputBorder(),
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
                    ElevatedButton.icon(
                      onPressed: loading ? null : handleLogin,
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.login),
                      label: const Text("Login"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade800,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: loading ? null : resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const OwnerRegisterFacilityScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        "Don't have an account? Register Facility",
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  TextFormField(
                    controller: staffIdController,
                    decoration: const InputDecoration(
                      labelText: "Staff ID",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: staffPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: loading ? null : handleStaffLogin,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: const Text("Login as Staff"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
