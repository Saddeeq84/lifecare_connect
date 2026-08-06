// Offline-first Authentication Service
// Enables users to access the app even without internet connectivity

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'offline_database_service.dart';

class OfflineAuthService {
  static final OfflineAuthService _instance = OfflineAuthService._internal();
  factory OfflineAuthService() => _instance;
  OfflineAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineDatabaseService _db = OfflineDatabaseService();

  // Session management
  static const String _sessionKey = 'offline_session';
  static const String _lastLoginKey = 'last_login_time';
  static const Duration _sessionDuration = Duration(days: 30);

  /// Check if user is authenticated (online or offline)
  Future<bool> isAuthenticated() async {
    // Check online authentication first
    if (_auth.currentUser != null) {
      return true;
    }

    // Check offline session
    return await hasValidOfflineSession();
  }

  /// Check if offline session is valid
  Future<bool> hasValidOfflineSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString(_sessionKey);
    final lastLoginStr = prefs.getString(_lastLoginKey);

    if (sessionData == null || lastLoginStr == null) {
      return false;
    }

    final lastLogin = DateTime.parse(lastLoginStr);
    final sessionExpired =
        DateTime.now().difference(lastLogin) > _sessionDuration;

    return !sessionExpired;
  }

  /// Login with email and password (online/offline hybrid)
  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (isOnline) {
        return await _onlineLogin(email, password);
      } else {
        return await _offlineLogin(email, password);
      }
    } catch (e) {
      // If online login fails, try offline
      try {
        return await _offlineLogin(email, password);
      } catch (offlineError) {
        return {'success': false, 'error': 'Login failed: ${e.toString()}'};
      }
    }
  }

  /// Online login with Firebase
  Future<Map<String, dynamic>> _onlineLogin(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {'success': false, 'error': 'Login failed'};
      }

      // Fetch user data from Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        return {'success': false, 'error': 'User data not found'};
      }

      final userData = userDoc.data()!;
      userData['uid'] = user.uid;

      // Save to offline database
      await _db.saveUser(userData);

      // Create offline session
      await _createOfflineSession(user.uid, email, password, userData);

      return {'success': true, 'user': userData, 'mode': 'online'};
    } catch (e) {
      throw Exception('Online login failed: ${e.toString()}');
    }
  }

  /// Offline login using cached credentials
  Future<Map<String, dynamic>> _offlineLogin(
    String email,
    String password,
  ) async {
    // Get cached user data
    final userData = await _db.getUserByEmail(email);

    if (userData == null) {
      return {
        'success': false,
        'error':
            'No cached login found. Please connect to internet for first login.',
      };
    }

    // Verify password hash
    final prefs = await SharedPreferences.getInstance();
    final storedPasswordHash = prefs.getString('pwd_hash_$email');

    if (storedPasswordHash == null) {
      return {
        'success': false,
        'error': 'Unable to verify credentials offline',
      };
    }

    final passwordHash = _hashPassword(password);
    if (passwordHash != storedPasswordHash) {
      return {'success': false, 'error': 'Invalid credentials'};
    }

    // Create/update offline session
    await _createOfflineSession(userData['uid'], email, password, userData);

    return {'success': true, 'user': userData, 'mode': 'offline'};
  }

  /// Create offline session for future logins
  Future<void> _createOfflineSession(
    String uid,
    String email,
    String password,
    Map<String, dynamic> userData,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Store session data
    final sessionData = {
      'uid': uid,
      'email': email,
      'role': userData['role'],
      'name': userData['name'],
    };

    await prefs.setString(_sessionKey, jsonEncode(sessionData));
    await prefs.setString(_lastLoginKey, DateTime.now().toIso8601String());

    // Store password hash for offline verification
    final passwordHash = _hashPassword(password);
    await prefs.setString('pwd_hash_$email', passwordHash);
  }

  /// Get current session data
  Future<Map<String, dynamic>?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionData = prefs.getString(_sessionKey);

    if (sessionData == null) return null;

    final session = jsonDecode(sessionData) as Map<String, dynamic>;

    // Get full user data from offline DB
    final userData = await _db.getUser(session['uid']);

    return userData ?? session;
  }

  /// Get current user UID
  Future<String?> getCurrentUserId() async {
    // Try Firebase Auth first
    if (_auth.currentUser != null) {
      return _auth.currentUser!.uid;
    }

    // Fall back to offline session
    final session = await getCurrentSession();
    return session?['uid'];
  }

  /// Sign out (online and offline)
  Future<void> signOut() async {
    // Sign out from Firebase
    try {
      await _auth.signOut();
    } catch (e) {
      // Ignore if offline
    }

    // Clear offline session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_lastLoginKey);
  }

  /// Register new user (queue if offline)
  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    required String role,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (isOnline) {
        return await _onlineRegistration(email, password, userData, role);
      } else {
        return await _offlineRegistration(email, password, userData, role);
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Registration failed: ${e.toString()}',
      };
    }
  }

  /// Online registration with Firebase
  Future<Map<String, dynamic>> _onlineRegistration(
    String email,
    String password,
    Map<String, dynamic> userData,
    String role,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {'success': false, 'error': 'Registration failed'};
      }

      userData['uid'] = user.uid;
      userData['email'] = email;
      userData['role'] = role;
      userData['createdAt'] = FieldValue.serverTimestamp();

      // Save to Firestore
      await _firestore.collection('users').doc(user.uid).set(userData);

      // Save to offline database
      await _db.saveUser(userData);

      // Create offline session
      await _createOfflineSession(user.uid, email, password, userData);

      return {'success': true, 'user': userData, 'mode': 'online'};
    } catch (e) {
      return {
        'success': false,
        'error': 'Registration failed: ${e.toString()}',
      };
    }
  }

  /// Offline registration (queued for sync)
  Future<Map<String, dynamic>> _offlineRegistration(
    String email,
    String password,
    Map<String, dynamic> userData,
    String role,
  ) async {
    // Generate temporary UID
    final tempUid = 'offline_${DateTime.now().millisecondsSinceEpoch}';

    userData['uid'] = tempUid;
    userData['email'] = email;
    userData['role'] = role;
    userData['createdOffline'] = true;

    // Queue for sync when online
    await _db.queueOfflineRegistration(
      email: email,
      password: password,
      userData: userData,
      role: role,
    );

    // Save to local database
    await _db.saveUser(userData);

    // Create offline session
    await _createOfflineSession(tempUid, email, password, userData);

    return {
      'success': true,
      'user': userData,
      'mode': 'offline',
      'message':
          'Account created offline. Will sync when internet is available.',
    };
  }

  /// Sync pending registrations when online
  Future<void> syncPendingRegistrations() async {
    final pendingRegistrations = await _db.getPendingRegistrations();

    for (final registration in pendingRegistrations) {
      try {
        final result = await _onlineRegistration(
          registration['email'],
          registration['password'],
          registration['userData'],
          registration['role'],
        );

        if (result['success']) {
          await _db.markRegistrationComplete(registration['id']);
        }
      } catch (e) {
        // Will retry on next sync
        continue;
      }
    }
  }

  /// Hash password for offline storage
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Update user profile (online/offline)
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final uid = await getCurrentUserId();
    if (uid == null) return;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (isOnline && !uid.startsWith('offline_')) {
        // Update Firestore
        await _firestore.collection('users').doc(uid).update(updates);
      }

      // Always update local database
      final userData = await _db.getUser(uid);
      if (userData != null) {
        userData.addAll(updates);
        await _db.saveUser(userData);
      }

      // Queue for sync if offline
      if (!isOnline || uid.startsWith('offline_')) {
        await _db.addToSyncQueue(
          operationType: 'update',
          entityType: 'user',
          entityId: uid,
          operationData: updates,
          priority: 1,
        );
      }
    } catch (e) {
      throw Exception('Profile update failed: ${e.toString()}');
    }
  }

  /// Refresh session from server
  Future<void> refreshSession() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);

      if (!isOnline) return;

      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        userData['uid'] = uid;
        await _db.saveUser(userData);
      }
    } catch (e) {
      // Fail silently - offline session remains valid
    }
  }
}
