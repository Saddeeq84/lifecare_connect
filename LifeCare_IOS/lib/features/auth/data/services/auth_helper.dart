// ignore_for_file: use_build_context_synchronously, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> loginAndRedirect({
  required BuildContext context,
  required String email,
  required String password,
}) async {
  try {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    // 🔐 Sign in the user with email and password
    UserCredential userCredential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) throw Exception("User not found.");

    // 🧾 Get user role from Firestore (if stored in a "users" collection)
    final userDoc = await firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      throw Exception("User profile not found in database.");
    }

    final data = userDoc.data();
    final role = data?['role'] ?? 'patient'; // Default to 'patient'

    // 🔁 Role-based redirection
    switch (role) {
      case 'CHW':
        Navigator.pushReplacementNamed(context, '/chw_dashboard');
        break;
      case 'supervisor':
        Navigator.pushReplacementNamed(context, '/supervisor_dashboard');
        break;
      case 'patient':
        Navigator.pushReplacementNamed(context, '/patient_dashboard');
        break;
      default:
        throw Exception('Unknown role: $role');
    }
  } on FirebaseAuthException catch (e) {
    String message = 'Login failed';
    if (e.code == 'user-not-found') message = 'User not found';
    if (e.code == 'wrong-password') message = 'Incorrect password';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
  }
}
