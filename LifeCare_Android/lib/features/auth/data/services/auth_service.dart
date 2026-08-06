import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithEmail(
    String email,
    String password, {
    bool skipEmailVerification = false,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Skip email verification for CHWs or when explicitly requested
    if (!skipEmailVerification && !credential.user!.emailVerified) {
      await credential.user!.sendEmailVerification();
      throw Exception('Please verify your email before signing in.');
    }

    // Update user activity on successful login
    await _updateUserActivity(credential.user!);

    return credential.user;
  }

  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount googleUser = await GoogleSignIn.instance
        .authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    final user = (await _auth.signInWithCredential(credential)).user;

    // Update user activity on successful Google sign-in
    if (user != null) {
      await _updateUserActivity(user);
    }

    return user;
  }

  /// Update user activity tracking on login
  Future<void> _updateUserActivity(User user) async {
    try {
      final now = Timestamp.now();
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': now,
        'isOnline': true,
        'lastLoginAt': now,
      });
    } catch (e) {
      // Log error but don't throw - login should still succeed
      print('Failed to update user activity: $e');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
