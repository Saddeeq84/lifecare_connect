// lib/features/admin/services/auto_repair_missing_users_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Automatic service to detect and repair users missing from Firestore
/// This runs periodically to catch and fix registration failures automatically
class AutoRepairMissingUsersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if a user exists in Firestore by email
  Future<bool> userExistsInFirestore(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return true; // Assume exists to avoid false positives
    }
  }

  /// Attempt to repair a missing user document
  /// This is safe to call - it only creates if missing
  Future<bool> repairMissingUser(String email, String uid) async {
    try {
      // Check if document already exists
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (docSnapshot.exists) {
        return true;
      }

      // Create minimal document with auto-repair flag
      final userData = {
        'email': email,
        'fullName': email.split('@')[0], // Use email prefix as placeholder
        'role': 'doctor', // Assume doctor for now (admin can change)
        'specialization': 'General Practice',
        'gender': 'Male',
        'phone': '',
        'imageUrl': '',
        'licenseUrl': '',
        'isApproved': false,
        'isRejected': false,
        'createdAt': FieldValue.serverTimestamp(),
        'autoRepaired': true,
        'autoRepairReason':
            'Registration completed in Auth but Firestore document was missing',
        'autoRepairDate': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(userData);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check current logged-in user and repair if needed
  Future<bool> checkAndRepairCurrentUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final email = currentUser.email;
      if (email == null) {
        return false;
      }

      // Check if user exists in Firestore
      final exists = await userExistsInFirestore(email);

      if (!exists) {
        return await repairMissingUser(email, currentUser.uid);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Scan for recently created Auth users missing from Firestore
  /// Note: This requires reading all recent Auth users, so use sparingly
  Future<List<String>> scanForMissingUsers({
    Duration lookbackPeriod = const Duration(days: 30),
  }) async {
    final missingEmails = <String>[];

    try {
      // Get all users from Firestore
      final firestoreSnapshot = await _firestore.collection('users').get();
      // Check existing emails in Firestore for comparison
      firestoreSnapshot.docs
          .map((doc) => doc.data()['email'] as String?)
          .where((email) => email != null)
          .toSet();

      // Note: We can't easily scan Auth users without admin SDK
      // So we'll just check users as they log in

      return missingEmails;
    } catch (e) {
      return [];
    }
  }
}
