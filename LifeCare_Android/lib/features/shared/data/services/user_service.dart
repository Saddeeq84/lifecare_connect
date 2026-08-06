// ignore_for_file: avoid_print, use_build_context_synchronously, depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _cachedUserRole;

  /// Returns the cached user role or null if not fetched yet
  String? get cachedUserRole => _cachedUserRole;

  /// Fetches the current user's role from Firestore and caches it
  Future<String?> fetchUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      _cachedUserRole = null;
      notifyListeners(); // 🔁 Trigger router refresh
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _cachedUserRole = doc.data()?['role']?.toString().toLowerCase();
      } else {
        // Fallback: Check custom claims if Firestore doc doesn't exist
        final idTokenResult = await user.getIdTokenResult(true);
        _cachedUserRole = idTokenResult.claims?['role']
            ?.toString()
            .toLowerCase();
      }
    } catch (e) {
      _cachedUserRole = null;
    }

    notifyListeners(); // 🔁 Notify GoRouter
    return _cachedUserRole;
  }

  /// Saves the user's role to Firestore and updates the cache
  Future<void> saveUserRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    try {
      await _firestore.collection('users').doc(user.uid).update({'role': role});
      _cachedUserRole = role.toLowerCase();
      notifyListeners(); // Keep state in sync
    } catch (e) {
      rethrow;
    }
  }

  /// Ensures the user document exists in Firestore. Creates if missing.
  Future<void> ensureUserDocument({required String role}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'role': role,
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {}
  }

  /// Navigate user based on role and approval status
  Future<void> navigateBasedOnRole(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    String? role;
    bool isApproved = false;

    if (doc.exists) {
      final data = doc.data();
      role = data?['role']?.toString().toLowerCase();
      isApproved = data?['isApproved'] == true;
    } else {
      // Fallback for admin using custom claims
      final idTokenResult = await user.getIdTokenResult(true);
      role = idTokenResult.claims?['role']?.toString().toLowerCase();
    }

    if (role == null) {
      context.go('/login');
      return;
    }

    if (['chw', 'doctor', 'facility'].contains(role) && !isApproved) {
      // Show approval pending message and redirect to login
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Account Pending Approval'),
          content: const Text(
            'Your account is awaiting admin approval. Please check back later.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

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
        context.go('/patient_dashboard');
        break;
      default:
        context.go('/login');
        break;
    }
  }

  /// Fetch full user profile data from Firestore
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Approve a user (admin use)
  Future<void> approveUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isApproved': true,
      });
    } catch (e) {
      rethrow;
    }
  }
}
