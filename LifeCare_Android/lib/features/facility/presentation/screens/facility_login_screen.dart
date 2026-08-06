// Facility Login Screen
// Handles authentication and navigation for facility users only.

// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'owner_register_facility_screen.dart';
import 'service_provider_login_screen.dart';

class _StaffLoginSearchResult {
  final bool staffIdExists;
  final Map<String, dynamic>? staffData;
  final String? facilityName;
  final String? facilityId;
  final String? documentId;

  const _StaffLoginSearchResult({
    required this.staffIdExists,
    this.staffData,
    this.facilityName,
    this.facilityId,
    this.documentId,
  });

  bool get staffFound =>
      staffData != null && facilityName != null && facilityId != null;
}

class FacilityLoginScreen extends StatefulWidget {
  const FacilityLoginScreen({super.key});

  @override
  State<FacilityLoginScreen> createState() => _FacilityLoginScreenState();
}

class _FacilityLoginScreenState extends State<FacilityLoginScreen> {
  String _generatePasswordResetToken() {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      48,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  Future<void> handleStaffLogin() async {
    // Validate staff ID
    if (staffIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Staff ID')),
      );
      return;
    }

    // Validate password
    if (staffPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() => loading = true);
    final staffId = staffIdController.text.trim();
    final password = staffPasswordController.text.trim();

    print('🔍 [StaffLogin] Staff ID: $staffId');
    print('🔍 [StaffLogin] Searching for staff account...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCollection = prefs.getString('staff_collection')?.trim();
      final cachedFacilityName = prefs.getString('facility_name')?.trim();
      final cachedFacilityId = prefs.getString('facility_id')?.trim();

      _StaffLoginSearchResult? cachedResult;
      if ((cachedCollection?.isNotEmpty ?? false) &&
          (cachedFacilityName?.isNotEmpty ?? false) &&
          (cachedFacilityId?.isNotEmpty ?? false)) {
        cachedResult = await _findStaffInFacilityCollection(
          collection: cachedCollection!,
          facilityName: cachedFacilityName!,
          facilityId: cachedFacilityId!,
          staffId: staffId,
          password: password,
        );
      }

      final _StaffLoginSearchResult searchResult;
      if (cachedResult?.staffFound == true) {
        searchResult = cachedResult!;
      } else {
        final routingResults = await _findStaffFromRoutingDocuments(
          staffId: staffId,
          password: password,
        );
        _StaffLoginSearchResult? routingMatch;
        for (final result in routingResults) {
          if (result.staffFound) {
            routingMatch = result;
            break;
          }
        }

        if (routingMatch != null) {
          searchResult = routingMatch;
        } else {
          if (facilities.isEmpty) {
            await _loadFacilities(showFeedback: false);
          }

          final remainingFacilities = facilities.where((facility) {
            final fId = facility['id'] as String? ?? '';
            return fId != cachedFacilityId;
          }).toList();

          final results =
              await Future.wait(
                remainingFacilities.map((facility) {
                  final fName = facility['name'] as String;
                  final fId = facility['id'] as String;
                  final collection =
                      '${fName.toLowerCase().replaceAll(' ', '_')}_users';
                  return _findStaffInFacilityCollection(
                    collection: collection,
                    facilityName: fName,
                    facilityId: fId,
                    staffId: staffId,
                    password: password,
                  );
                }),
              ).timeout(
                const Duration(seconds: 18),
                onTimeout: () => <_StaffLoginSearchResult>[],
              );

          final allResults = [?cachedResult, ...results];
          final matchingResults = [
            ...allResults,
            ...routingResults,
          ].where((result) => result.staffFound);
          searchResult = matchingResults.isNotEmpty
              ? matchingResults.first
              : _StaffLoginSearchResult(
                  staffIdExists: [
                    ...allResults,
                    ...routingResults,
                  ].any((result) => result.staffIdExists),
                );
        }
      }

      if (!searchResult.staffFound) {
        if (searchResult.staffIdExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Staff ID not found. Please check your credentials.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final staff = searchResult.staffData!;
      final facilityName = searchResult.facilityName!;
      final facilityId = searchResult.facilityId!;

      // Debug logging
      print('🔍 [Login] Staff data: $staff');
      print('🔍 [Login] emailVerified value: ${staff['emailVerified']}');
      print(
        '🔍 [Login] emailVerified type: ${staff['emailVerified'].runtimeType}',
      );
      print('🔍 [Login] status value: ${staff['status']}');

      // Check if email is verified FIRST (before password)
      if (staff['emailVerified'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please verify your email first. Check your inbox for the verification link.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Check password
      if (staff['password'] != password) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect password.')));
        return;
      }

      // Check if status is active (after email verification)
      if (staff['status'] != 'active' && staff['status'] != 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              staff['status'] == 'pending'
                  ? 'Account pending. Please verify your email first.'
                  : 'Account not approved. Contact your facility administrator.',
            ),
          ),
        );
        return;
      }

      print('✅ [StaffLogin] Credentials verified. Logging in...');

      // Staff login is now simplified - no Firebase Auth needed
      // Just verify Staff ID + Password from Firestore and log them in
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut().timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      }

      // Build collection name from detected facility
      final collection =
          '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';
      final staffName = staff['fullName'] ?? '';
      final staffProfession = staff['profession'] ?? '';
      final staffDepartment = staff['department'] ?? '';

      // Save role and staff info to SharedPreferences
      await prefs.setString('user_role', 'facility_staff');
      await prefs.setString('staff_id', staffId);
      await prefs.setString('facility_id', facilityId); // Save facility ID!
      await prefs.setString('facility_name', facilityName);
      await prefs.setString('staff_collection', collection);
      await prefs.setString('staff_document_id', searchResult.documentId ?? '');
      await prefs.setString('staff_email', staff['email'] ?? '');
      await prefs.setString('staff_name', staffName);
      await prefs.setString('staff_profession', staffProfession);
      await prefs.setString('staff_department', staffDepartment);
      final ipcTabAccess = (staff['ipcTabAccess'] as List<dynamic>? ?? [])
          .cast<String>();
      await prefs.setStringList('ipc_tab_access', ipcTabAccess);
      await prefs.setBool('ipc_tab_access_cached', true);

      print(
        '✅ [StaffLogin] Login successful! Routing to department dashboard...',
      );

      if (mounted) {
        if (_isIpcDashboardStaff(
          department: staffDepartment,
          profession: staffProfession,
        )) {
          context.go(
            '/infection_prevention_control',
            extra: {
              'facilityId': facilityId,
              'facilityName': facilityName,
              'staffId': staffId,
              'staffDocumentId': searchResult.documentId,
              'staffName': staffName,
            },
          );
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      print('❌ [StaffLogin] Login error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<_StaffLoginSearchResult> _findStaffInFacilityCollection({
    required String collection,
    required String facilityName,
    required String facilityId,
    required String staffId,
    required String password,
  }) async {
    try {
      print('🔍 [StaffLogin] Searching in: $collection');
      final query = await FirebaseFirestore.instance
          .collection(collection)
          .where('staffId', isEqualTo: staffId)
          .limit(5)
          .get()
          .timeout(const Duration(seconds: 10));

      if (query.docs.isEmpty) {
        return const _StaffLoginSearchResult(staffIdExists: false);
      }

      for (final doc in query.docs) {
        final data = doc.data();
        if (data['password'] == password) {
          print(
            '✅ [StaffLogin] Matching staff found in facility: $facilityName',
          );
          return _StaffLoginSearchResult(
            staffIdExists: true,
            staffData: data,
            facilityName: facilityName,
            facilityId: facilityId,
            documentId: doc.id,
          );
        }
      }

      return const _StaffLoginSearchResult(staffIdExists: true);
    } catch (error) {
      print('⚠️ [StaffLogin] Unable to search $collection: $error');
      return const _StaffLoginSearchResult(staffIdExists: false);
    }
  }

  Future<List<_StaffLoginSearchResult>> _findStaffFromRoutingDocuments({
    required String staffId,
    required String password,
  }) async {
    try {
      final routingDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('staffId', isEqualTo: staffId)
          .limit(10)
          .get()
          .timeout(const Duration(seconds: 10));

      final results = <_StaffLoginSearchResult>[];
      for (final doc in routingDocs.docs) {
        final data = doc.data();
        final facilityName = '${data['facilityName'] ?? data['name'] ?? ''}'
            .trim();
        final facilityId = '${data['facilityId'] ?? ''}'.trim();
        if (facilityName.isEmpty || facilityId.isEmpty) continue;
        final collection =
            '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';
        results.add(
          await _findStaffInFacilityCollection(
            collection: collection,
            facilityName: facilityName,
            facilityId: facilityId,
            staffId: staffId,
            password: password,
          ),
        );
      }
      return results;
    } catch (error) {
      print('⚠️ [StaffLogin] Unable to search staff routing documents: $error');
      return const <_StaffLoginSearchResult>[];
    }
  }

  bool _isIpcDashboardStaff({
    required String department,
    required String profession,
  }) {
    final values = [
      department,
      profession,
    ].map((value) => value.toLowerCase().trim());
    return values.any(
      (value) =>
          value.startsWith('ipc ') ||
          value.contains('infection prevention') ||
          value.contains('infection control'),
    );
  }

  bool isAdminLogin = true;
  final staffIdController = TextEditingController();
  final staffPasswordController = TextEditingController();

  // Facilities list for staff auto-detection
  List<Map<String, dynamic>> facilities = [];
  bool loadingFacilities = false;
  bool facilityLoadAttempted = false;

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
  void initState() {
    super.initState();
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

  Future<void> _loadFacilities({bool showFeedback = true}) async {
    if (mounted) {
      setState(() {
        loadingFacilities = true;
        facilityLoadAttempted = true;
      });
    }
    try {
      print('🔍 Loading facilities from Firestore...');
      final loadedFacilities = await _fetchLoginFacilities();
      facilities = loadedFacilities;
      await _cacheLoginFacilities(loadedFacilities);
      print('✅ Loaded ${facilities.length} healthcare facilities');
    } on TimeoutException catch (e, stackTrace) {
      print('❌ Facility loading timed out: $e');
      print('Stack trace: $stackTrace');
      final cached = await _loadCachedLoginFacilities();
      if (cached.isNotEmpty) {
        facilities = cached;
      }
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cached.isNotEmpty
                  ? 'Using saved facility list while the network is slow.'
                  : 'Facility list is taking longer than usual. Please check your internet connection and try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error loading facilities: $e');
      print('Stack trace: $stackTrace');
      final cached = await _loadCachedLoginFacilities();
      if (cached.isNotEmpty) {
        facilities = cached;
      }
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cached.isNotEmpty
                  ? 'Using saved facility list while online loading failed.'
                  : 'Error loading facilities: $e',
            ),
            backgroundColor: cached.isNotEmpty ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loadingFacilities = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLoginFacilities() async {
    final byId = <String, Map<String, dynamic>>{};

    try {
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 12));
      for (final doc in facilitiesSnapshot.docs) {
        final mapped = _facilityLoginMapFromData(doc.id, doc.data());
        if (mapped != null) byId[doc.id] = mapped;
      }
    } catch (error) {
      print('⚠️ Unable to load facilities collection: $error');
    }

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'facility')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    for (final doc in usersSnapshot.docs) {
      final data = doc.data();
      if (data['isApproved'] == false) continue;
      final mapped = _facilityLoginMapFromData(doc.id, data);
      if (mapped != null) byId[doc.id] = mapped;
    }

    final list = byId.values.toList();
    list.sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));
    return list;
  }

  Map<String, dynamic>? _facilityLoginMapFromData(
    String id,
    Map<String, dynamic> data,
  ) {
    const excludedTypes = ['pharmacy', 'laboratory', 'scan center'];
    final facilityType = '${data['type'] ?? ''}'.toLowerCase().trim();
    if (excludedTypes.contains(facilityType)) return null;
    final name = '${data['name'] ?? data['facilityName'] ?? ''}'.trim();
    if (name.isEmpty) return null;
    return {'id': id, 'name': name, 'type': data['type'] as String?};
  }

  Future<void> _cacheLoginFacilities(
    List<Map<String, dynamic>> facilities,
  ) async {
    if (facilities.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_facilities_cache', jsonEncode(facilities));
  }

  Future<List<Map<String, dynamic>>> _loadCachedLoginFacilities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('login_facilities_cache');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => '${item['id'] ?? ''}'.isNotEmpty)
          .where((item) => '${item['name'] ?? ''}'.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    staffIdController.dispose();
    staffPasswordController.dispose();
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
    } on FirebaseAuthException catch (e) {
      // If Firebase Auth login fails, check if it's an existing staff without Firebase Auth account
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-email') {
        final userCredential = await _migrateExistingStaff(
          emailController.text.trim(),
          passwordController.text.trim(),
        );
        if (userCredential != null && mounted) {
          // Successfully migrated and logged in
          await _navigateBasedOnRole(userCredential.user!.uid);
          if (mounted) setState(() => loading = false);
          return;
        }
      }

      if (mounted) {
        String message = 'Wrong email/password, please try again';
        if (e.code == 'network-request-failed') {
          message = 'Network error. Please check your connection and try again';
        } else if (e.code == 'too-many-requests') {
          message = 'Too many failed attempts. Please try again later';
        }
        _showErrorDialog(message);
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An unexpected error occurred. Please try again');
        setState(() => loading = false);
      }
    }
  }

  // Navigates facility user to the dashboard and caches role
  Future<void> _navigateBasedOnRole(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // First check if user is a facility admin
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists && userDoc.data()?['role'] == 'facility') {
        // Facility admin - validate that selected facility matches their actual facility
        final userFacilityId = userDoc.id; // The document ID is the facility ID
        final userData = userDoc.data()!;
        final facilityType =
            (userData['type'] as String?)?.toLowerCase().trim() ?? '';

        // Check if this is a standalone service provider (pharmacy, lab, scan center)
        final serviceProviderTypes = [
          'pharmacy',
          'laboratory',
          'scan center',
          'mental health center',
        ];
        if (serviceProviderTypes.contains(facilityType)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please login via the service provider screen.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          // Log out the user
          await FirebaseAuth.instance.signOut();
          return;
        }

        // No need to validate facility selection - auto-detected from user account

        // Facility admin - successful login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role', 'facility');
        await prefs.setString('facility_id', userFacilityId);
        await prefs.setString('facility_name', userData['name'] ?? '');
        await prefs.setString('facility_type', userData['type'] ?? '');

        if (mounted) {
          context.go('/facility_dashboard');
        }
        return;
      }

      // Check if user is staff in any facility
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .get();

      for (final facilityDoc in facilitiesSnapshot.docs) {
        final facilityData = facilityDoc.data();
        final facilityName = facilityData['name'] as String?;

        if (facilityName == null) continue;

        final collection =
            '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

        // Search for staff by email
        final staffQuery = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          // Found staff account - let auth redirect route to department dashboard
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_role', 'staff');
          if (mounted) {
            // Navigate to home - auth redirect will route to correct department dashboard
            context.go('/');
          }
          return;
        }
      }

      // If not found in either, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account not found. Please contact your administrator.',
            ),
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

  // Migrates existing staff who don't have Firebase Auth accounts yet
  Future<UserCredential?> _migrateExistingStaff(
    String email,
    String password,
  ) async {
    try {
      print('[Migration] Checking if staff exists: $email');

      // Search for staff in all facility collections
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .get();

      for (final facilityDoc in facilitiesSnapshot.docs) {
        final facilityData = facilityDoc.data();
        final facilityName = facilityData['name'] as String?;

        if (facilityName == null) continue;

        final collection =
            '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

        // Search for staff by email and password
        final staffQuery = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          final staffData = staffQuery.docs.first.data();
          final storedPassword = staffData['password'] as String?;
          final emailVerified = staffData['emailVerified'] ?? false;
          final status = staffData['status'] ?? 'pending';

          // Check if password matches and account is active
          if (storedPassword == password &&
              emailVerified &&
              status == 'active') {
            print(
              '[Migration] Found matching staff, attempting to create/sync Firebase Auth account...',
            );

            // Try to create or get existing Firebase Auth account
            try {
              final userCredential = await _auth.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );

              print(
                '[Migration] Firebase Auth account created: ${userCredential.user!.uid}',
              );

              // Create document in users collection for routing
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .set({
                    'email': email,
                    'name': staffData['fullName'] ?? '',
                    'fullName': staffData['fullName'] ?? '',
                    'profession': staffData['profession'] ?? '',
                    'department': staffData['department'] ?? '',
                    'facilityId': facilityDoc.id,
                    'facilityName': facilityName,
                    'staffId': staffData['staffId'] ?? '',
                    'phone': staffData['phone'] ?? '',
                    'role': 'staff',
                    'createdAt': FieldValue.serverTimestamp(),
                    'migratedAt': FieldValue.serverTimestamp(),
                  });

              print('[Migration] User document created successfully');
              return userCredential;
            } catch (authError) {
              // If email already in use, the Firebase Auth account exists - just sync the user document
              if (authError.toString().contains('email-already-in-use')) {
                print(
                  '[Migration] Firebase Auth account already exists, syncing user document...',
                );

                // Get the existing Firebase Auth user by signing in
                try {
                  final existingCredential = await _auth
                      .signInWithEmailAndPassword(
                        email: email,
                        password: password,
                      );

                  // Sync/update the user document
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(existingCredential.user!.uid)
                      .set({
                        'email': email,
                        'name': staffData['fullName'] ?? '',
                        'fullName': staffData['fullName'] ?? '',
                        'profession': staffData['profession'] ?? '',
                        'department': staffData['department'] ?? '',
                        'facilityId': facilityDoc.id,
                        'facilityName': facilityName,
                        'staffId': staffData['staffId'] ?? '',
                        'phone': staffData['phone'] ?? '',
                        'role': 'staff',
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                  print(
                    '[Migration] Successfully synced existing Firebase Auth account',
                  );
                  return existingCredential;
                } catch (signInError) {
                  print(
                    '[Migration] Error signing in with existing account: $signInError',
                  );
                  return null;
                }
              }

              print(
                '[Migration] Error creating Firebase Auth account: $authError',
              );
              return null;
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('[Migration] Error during migration: $e');
      return null;
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

  // Show forgot password dialog for staff
  Future<void> _showStaffForgotPasswordDialog() async {
    final staffIdInputController = TextEditingController();
    final emailInputController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Staff Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your Staff ID and registered email to receive a password reset link.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: staffIdInputController,
              decoration: const InputDecoration(
                labelText: 'Staff ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailInputController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final staffId = staffIdInputController.text.trim();
              final email = emailInputController.text.trim();

              if (staffId.isEmpty || email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid Staff ID and email'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, {'staffId': staffId, 'email': email});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _sendStaffPasswordResetLink(result['staffId']!, result['email']!);
    }
  }

  // Send password reset link for staff
  Future<void> _sendStaffPasswordResetLink(String staffId, String email) async {
    setState(() => loading = true);

    try {
      // Search all facilities for staff with matching staffId and email
      final facilitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'facility')
          .get();

      bool staffFound = false;

      for (final facilityDoc in facilitiesSnapshot.docs) {
        final facilityData = facilityDoc.data();
        final facilityName = facilityData['name'] as String?;

        if (facilityName == null) continue;

        final collection =
            '${facilityName.toLowerCase().replaceAll(' ', '_')}_users';

        // Search for staff by staffId and email
        final staffQuery = await FirebaseFirestore.instance
            .collection(collection)
            .where('staffId', isEqualTo: staffId)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (staffQuery.docs.isNotEmpty) {
          staffFound = true;
          final staffDoc = staffQuery.docs.first;
          final staffData = staffDoc.data();

          // Check if email is verified
          if (staffData['emailVerified'] != true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please verify your email first before resetting password.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          // For staff password reset, we need to create a custom flow since Firebase Auth
          // password reset won't work with the Firestore password system

          // Generate a secure reset token and store it temporarily
          final resetToken = _generatePasswordResetToken();

          // Store reset token in Firestore with expiration (valid for 1 hour)
          await staffDoc.reference.update({
            'passwordResetToken': resetToken,
            'passwordResetExpiry': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 1)),
            ),
            'passwordResetRequestedAt': FieldValue.serverTimestamp(),
          });

          // Create reset link - use the deployed web app URL
          final resetLink = Uri.https(
            'lifecare-connect.web.app',
            '/staff-setup',
            {'staffId': staffId, 'token': resetToken},
          ).toString();

          try {
            print('[ForgotPassword] Sending reset email to: $email');
            print('[ForgotPassword] Reset link: $resetLink');

            // Send email with reset link
            await _sendStaffSetupEmail(
              email: email,
              name: staffData['fullName'] ?? 'Staff Member',
              staffId: staffId,
              setupLink: resetLink,
            );

            print('[ForgotPassword] ✅ Email sent successfully');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Password reset link sent to your email! Check your inbox.',
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          } catch (e) {
            print('[ForgotPassword] ❌ Failed to send email: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send email: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
          break;
        }
      }

      if (!staffFound && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff ID and email do not match any records'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // Helper function to send staff setup email (for staff without Firebase Auth account)
  Future<void> _sendStaffSetupEmail({
    required String email,
    required String name,
    required String staffId,
    required String setupLink,
  }) async {
    const url =
        'https://us-central1-lifecare-connect.cloudfunctions.net/sendStaffPasswordResetSimple';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'name': name,
        'staffId': staffId,
        'setupLink': setupLink,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send setup email: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Facility Login"),
        backgroundColor: Colors.teal.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Login type selection
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ChoiceChip(
                    label: const Text('Admin'),
                    selected: isAdminLogin,
                    onSelected: (v) => setState(() => isAdminLogin = true),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ChoiceChip(
                    label: const Text('Staff'),
                    selected: !isAdminLogin,
                    onSelected: (v) {
                      setState(() => isAdminLogin = false);
                      if (facilities.isEmpty && !loadingFacilities) {
                        _loadFacilities(showFeedback: false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ChoiceChip(
                    label: const Text('Service Provider'),
                    selected: false,
                    onSelected: (v) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ServiceProviderLoginScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Compact info text
            Text(
              isAdminLogin
                  ? 'For Healthcare Facilities (Hospital, Clinic, etc.)'
                  : 'Staff login for healthcare facilities',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Show facility loading status or refresh button
            if (!isAdminLogin &&
                facilityLoadAttempted &&
                facilities.isEmpty &&
                !loadingFacilities)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No facilities loaded. '),
                    TextButton.icon(
                      onPressed: _loadFacilities,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (!isAdminLogin && loadingFacilities)
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading facilities...'),
                  ],
                ),
              ),
            if (isAdminLogin)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Admin login - no facility dropdown needed
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
                  // Staff login - no facility dropdown needed
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
                  TextButton(
                    onPressed: loading ? null : _showStaffForgotPasswordDialog,
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
