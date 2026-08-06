// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted || _hasRedirected) return;

      if (user == null) {
        debugPrint('[AuthGate] 🔒 No user found. Redirecting to /login');
        _safeGo('/login');
        return;
      }

      try {
        debugPrint('[AuthGate] 🔐 User signed in: ${user.email} (${user.uid})');

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!snapshot.exists) {
          debugPrint(
            '[AuthGate] ❌ No Firestore document found for user: ${user.uid}',
          );
          _safeGo('/login'); // or create fallback screen
          return;
        }

        final data = snapshot.data();
        final role = data?['role'];

        debugPrint('[AuthGate] 🧾 Firestore user role: $role');

        switch (role) {
          case 'doctor':
            _safeGo('/doctor_dashboard');
            break;
          case 'patient':
            _safeGo('/patient_dashboard');
            break;
          case 'admin':
            _safeGo('/admin_dashboard');
            break;
          case 'chw':
            _safeGo('/chw_dashboard');
            break;
          case 'facility':
            _safeGo('/facility_dashboard');
            break;
          default:
            debugPrint('[AuthGate] ❗ Unknown role: $role');
            _safeGo('/login'); // fallback if role is not recognized
        }
      } catch (e, stack) {
        debugPrint('[AuthGate] ⚠️ Error fetching Firestore user data: $e');
        debugPrint(stack.toString());
        _safeGo('/login');
      }
    });
  }

  void _safeGo(String route) {
    if (!_hasRedirected && mounted) {
      _hasRedirected = true;
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
