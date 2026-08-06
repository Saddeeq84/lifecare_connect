// Service Provider Login Screen
// For standalone service facilities: Pharmacy, Laboratory, Scan Center
// These are independent facilities that operate without hospital/clinic departments

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class ServiceProviderLoginScreen extends StatefulWidget {
  const ServiceProviderLoginScreen({super.key});

  @override
  State<ServiceProviderLoginScreen> createState() =>
      _ServiceProviderLoginScreenState();
}

class _ServiceProviderLoginScreenState
    extends State<ServiceProviderLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool loadingFacilities = false;
  bool isStaffLogin = false; // Toggle between owner/staff login
  List<Map<String, String>> facilities = [];
  String? facilityLoadError;

  @override
  void initState() {
    super.initState();
    _loadServiceProviderFacilities();
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Load only standalone service provider facilities
  Future<void> _loadServiceProviderFacilities() async {
    setState(() {
      loadingFacilities = true;
      facilityLoadError = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .where('isApproved', isEqualTo: true)
          .get();

      // Service types with their possible variations
      final serviceTypes = [
        'pharmacy',
        'laboratory',
        'scan center',
        'mental health center',
      ];
      final loadedFacilities = <Map<String, String>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        final type = data['type'] as String?;

        if (name != null && type != null) {
          // Only include standalone service facilities
          // Compare with lowercase for case-insensitive matching
          final normalizedType = type.toLowerCase().trim();
          if (serviceTypes.contains(normalizedType)) {
            loadedFacilities.add({'id': doc.id, 'name': name, 'type': type});
          } else {}
        }
      }

      // Sort alphabetically
      loadedFacilities.sort((a, b) => a['name']!.compareTo(b['name']!));

      setState(() {
        facilities = loadedFacilities;
        loadingFacilities = false;
      });
    } catch (e) {
      setState(() {
        facilityLoadError = 'Failed to load facilities. Please try again.';
        loadingFacilities = false;
      });
    }
  }

  Future<void> handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      if (isStaffLogin) {
        // Staff login using Staff ID and password
        await _handleStaffLogin();
      } else {
        // Owner login using email and password with Firebase Auth
        await _handleOwnerLogin();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Handle facility owner login using Firebase Auth
  Future<void> _handleOwnerLogin() async {
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      if (userCredential.user != null && mounted) {
        await _navigateBasedOnRole(userCredential.user!.uid);
      } else {}
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
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An unexpected error occurred. Please try again');
      }
    }
  }

  // Handle staff login using Staff ID and password (no Firebase Auth)
  Future<void> _handleStaffLogin() async {
    try {
      final staffId = emailController.text
          .trim(); // Using email field for staff ID
      final password = passwordController.text.trim();

      // Search for staff across all service provider facilities
      bool staffFound = false;
      Map<String, dynamic>? staffData;
      String? facilityId;
      String? facilityName;
      String? facilityType;

      for (final facility in facilities) {
        final fName = facility['name']!;
        final fId = facility['id']!;
        final fType = facility['type']!;
        final collection = '${fName.toLowerCase().replaceAll(' ', '_')}_users';

        final staffQuery = await FirebaseFirestore.instance
            .collection(collection)
            .where('staffId', isEqualTo: staffId)
            .limit(1)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          staffFound = true;
          staffData = staffQuery.docs.first.data();
          facilityId = fId;
          facilityName = fName;
          facilityType = fType;
          break;
        }
      }

      if (!staffFound || staffData == null) {
        if (mounted) {
          _showErrorDialog('Wrong Staff ID/password, please try again');
        }
        return;
      }

      final storedPassword = staffData['password'] as String?;

      if (storedPassword != password) {
        if (mounted) {
          _showErrorDialog('Wrong Staff ID/password, please try again');
        }
        return;
      }

      // Successful staff login - store credentials
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'service_provider_staff');
      await prefs.setString('facility_id', facilityId!);
      await prefs.setString('facility_name', facilityName!);
      await prefs.setString('facility_type', facilityType ?? '');
      await prefs.setString('staff_id', staffId);
      await prefs.setString(
        'staff_name',
        staffData['fullName'] ?? staffData['name'] ?? '',
      );
      await prefs.setString('staff_email', staffData['email'] ?? '');
      await prefs.setString('staff_profession', staffData['profession'] ?? '');
      await prefs.setString('staff_department', staffData['department'] ?? '');

      if (mounted) {
        context.go('/service_provider_dashboard');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An unexpected error occurred. Please try again');
      }
    }
  }

  // Navigates service provider user to the appropriate dashboard
  Future<void> _navigateBasedOnRole(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      // Check if user is a service provider facility owner/admin
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists && userDoc.data()?['role'] == 'facility') {
        final facilityType =
            (userDoc.data()?['type'] as String?)?.toLowerCase().trim() ?? '';
        final facilityName = userDoc.data()?['name'] as String? ?? '';

        // SECURITY: Validate that this is actually a service provider facility
        // Only allow: pharmacy, laboratory, scan center, mental health center
        final allowedServiceTypes = [
          'pharmacy',
          'laboratory',
          'scan center',
          'mental health center',
        ];

        if (!allowedServiceTypes.contains(facilityType)) {
          // This is a hospital/clinic trying to login via service provider screen
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Access denied. "$facilityName" is a $facilityType, not a service provider. '
                  'Please use the Facility Login screen instead.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 6),
              ),
            );
          }
          // Log out the user
          await FirebaseAuth.instance.signOut();
          return;
        }

        // No need to validate facility selection - auto-detected from user account

        // Store role and facility type
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'service_provider');
        await prefs.setString('facility_type', facilityType);

        if (mounted) {
          // Route to service provider dashboard
          context.go('/service_provider_dashboard');
        }
        return;
      }

      // If not found, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account not found. Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error determining user role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade700, Colors.teal.shade400],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.medical_services,
                      size: 60,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Service Provider Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'For Pharmacy, Laboratory & Scan Center',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Login Form Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Facility Selection Error
                            if (facilityLoadError != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            facilityLoadError!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: _loadServiceProviderFacilities,
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Loading Indicator
                            if (loadingFacilities)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Loading service facilities...'),
                                  ],
                                ),
                              ),

                            // No facility dropdown - auto-detected from credentials

                            // Login Type Toggle (Owner / Staff)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          isStaffLogin = false;
                                          emailController.clear();
                                          passwordController.clear();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: !isStaffLogin
                                              ? Colors.teal
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.admin_panel_settings,
                                              color: !isStaffLogin
                                                  ? Colors.white
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Admin',
                                              style: TextStyle(
                                                color: !isStaffLogin
                                                    ? Colors.white
                                                    : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          isStaffLogin = true;
                                          emailController.clear();
                                          passwordController.clear();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isStaffLogin
                                              ? Colors.teal
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.badge,
                                              color: isStaffLogin
                                                  ? Colors.white
                                                  : Colors.grey,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Staff',
                                              style: TextStyle(
                                                color: isStaffLogin
                                                    ? Colors.white
                                                    : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Email/Staff ID Field
                            TextFormField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: isStaffLogin ? "Staff ID" : "Email",
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  isStaffLogin ? Icons.badge : Icons.email,
                                ),
                              ),
                              keyboardType: isStaffLogin
                                  ? TextInputType.text
                                  : TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return isStaffLogin
                                      ? 'Enter your staff ID'
                                      : 'Enter your email';
                                }
                                if (!isStaffLogin && !value.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              decoration: InputDecoration(
                                labelText: "Password",
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock),
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
                              validator: (value) =>
                                  value == null || value.length < 6
                                  ? 'Enter 6+ character password'
                                  : null,
                            ),
                            const SizedBox(height: 24),

                            // Login Button
                            ElevatedButton(
                              onPressed: loading ? null : handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Help Text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Having trouble logging in?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Contact your service facility administrator\nfor login credentials and support',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
