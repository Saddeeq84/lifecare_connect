import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to track user activity across the app
class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Update user's last seen timestamp
  Future<void> updateLastSeen() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': Timestamp.now(),
        'isOnline': true,
      });
    } catch (e) {
      print('Failed to update last seen: $e');
    }
  }

  /// Set user as offline
  Future<void> setUserOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': Timestamp.now(),
      });
    } catch (e) {
      print('Failed to set user offline: $e');
    }
  }

  /// Track when user opens the app
  Future<void> trackAppOpen() async {
    await updateLastSeen();
  }

  /// Track when user becomes active (e.g., after app resume)
  Future<void> trackUserActivity() async {
    await updateLastSeen();
  }

  /// Initialize activity tracking for the current user
  Future<void> initializeActivityTracking() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        // Ensure user document has activity fields
        final data = userDoc.data() ?? {};
        if (!data.containsKey('lastSeen') || !data.containsKey('isOnline')) {
          await _firestore.collection('users').doc(user.uid).update({
            'lastSeen': Timestamp.now(),
            'isOnline': true,
          });
        } else {
          // Just update the activity
          await updateLastSeen();
        }
      }
    } catch (e) {
      print('Failed to initialize activity tracking: $e');
    }
  }
}
